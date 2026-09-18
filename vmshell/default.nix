{ nixpkgs, microvm }:
let
  inherit (nixpkgs) lib;

  supportedHosts = [
    "x86_64-linux"
    "aarch64-linux"
    "aarch64-darwin"
  ];

  supportedGuests = [
    "x86_64-linux"
    "aarch64-linux"
  ];

  # port sshd listens on inside the guest, on AF_VSOCK. the host connects
  # through systemd-ssh-proxy (the same helper behind `ssh vsock/<cid>`), so
  # no networking is involved at all.
  sshVsockPort = 22;

  # TODO(turbio): this is probably wrong. can even support cross?
  innerDevshell =
    pkgs: shellAttrs:
    let
      # listen. it's slop. but it's upstream's slop
      # https://github.com/NixOS/nix/blob/58b68044416080dfb18a1f75552de4f9492b43f8/src/nix/develop.cc#L315
      ignoreVars = [
        "BASHOPTS"
        "HOME"
        "NIX_BUILD_TOP"
        "NIX_ENFORCE_PURITY"
        "NIX_LOG_FD"
        "NIX_REMOTE"
        "PPID"
        "SHELLOPTS"
        "SSL_CERT_FILE"
        "TEMP"
        "TEMPDIR"
        "TERM"
        "TMP"
        "TMPDIR"
        "TZ"
        "UID"

        # we're source into an existing shell
        "PWD"
        "OLDPWD"

        # constructed at runtime, try not to have cross bins in our path
        "PATH"
      ];

      # Also filter PATH — in cross-compilation, PATH contains build-platform
      # tools (e.g. x86_64 coreutils) that can't run inside the guest.
      ignoreVarsPattern = builtins.concatStringsSep "|" ignoreVars;

      devShellEnv = (pkgs.mkShell shellAttrs).overrideAttrs {
        name = "vmshell-env";
        buildPhase = ''
          export -p | grep -v -E '^declare -x (${ignoreVarsPattern})=' > $out
        '';
      };

      shellPkgs = (shellAttrs.buildInputs or [ ]) ++ (shellAttrs.nativeBuildInputs or [ ]);

    in

    # basically
    # https://github.com/NixOS/nix/blob/58b68044416080dfb18a1f75552de4f9492b43f8/src/nix/develop.cc#L348
    pkgs.writeShellScript "vmshell-devshell-setup" ''
      eval "$(cat ${devShellEnv})"

      # PATH is special because in cross it'll have the build platform's tools
      export PATH="${lib.makeBinPath shellPkgs}''${PATH:+:$PATH}"

      if [ -n "''${shellHook:-}" ]; then
        eval "$shellHook"
      fi
    '';

  guestConfig =
    vm: shellAttrs:
    {
      config,
      pkgs,
      lib,
      ...
    }:
    let
      inherit (vm) guestPlatform user;
      serialConsole = if guestPlatform == "aarch64-linux" then "ttyAMA0" else "ttyS0";
      activateShell = innerDevshell pkgs shellAttrs;

      userCfg = config.users.users.${user};
      # not userCfg.home: an attr *name* in fileSystems can't depend on config
      # (users -> rpcbind -> fileSystems is a cycle)
      projectRoot = "/home/${user}/project-root";
      sshPackage = config.services.openssh.package;
    in
    {
      users.users.root.password = lib.mkDefault "";
      microvm = {
        volumes = [
          {
            mountPoint = "/var";
            image = "var.img";
            size = 256;
          }
        ];
        shares = [
          {
            proto = "9p";
            tag = "ro-store";
            # host /nix/store will be used (no squashfs/erofs will be built)
            source = "/nix/store";
            mountPoint = "/nix/.ro-store";
            readOnly = true;
          }

          /*
             mount home?
            {
              proto = "9p";
              tag = "ro-host-home";
              source = "/home";
              mountPoint = "/shares/host-home";
              readOnly = true;
            }
          */

          {
            proto = "9p";
            tag = "rw-project-root";
            source = "./project";
            mountPoint = "/shares/project-root";
            readOnly = false;
          }
        ];

        writableStoreOverlay = "/nix/.rw-store";

        # "qemu" has 9p built-in!
        hypervisor = "qemu";
        socket = "control.socket";

        interfaces = [
          {
            type = "user";
            id = "qemu";
            mac = "02:00:00:01:01:01";
          }
        ];

        # the interactive session comes in over ssh (see below), so the
        # serial console only carries the boot log. it goes to a file in the
        # runtime dir that the host wrapper tails until sshd is up, instead
        # of stdio where it'd keep clobbering the shell.
        qemu.serialConsole = false;
        qemu.extraArgs = [
          "-serial"
          "file:./console.log"
          "-monitor"
          "none"

          # the client's public key, generated per run by the host wrapper.
          # read back from /sys/firmware/qemu_fw_cfg in the guest.
          "-fw_cfg"
          "name=opt/vmshell/authorized_keys,file=./ssh/id.pub"
        ];

        # the vsock cid is chosen at runtime by the wrapper so several vms
        # can run on one host. -pci rather than -device: the 9p shares
        # already force microvm.nix onto the pci bus.
        extraArgsScript = ''echo "-device vhost-vsock-pci,guest-cid=''${VMSHELL_CID:?}"'';
      };

      boot.kernelParams = [ "console=${serialConsole},115200" ];
      # vsock must be usable before sockets.target, fw_cfg before the key
      # import; don't rely on udev getting there first
      boot.kernelModules = [
        "vmw_vsock_virtio_transport"
        "qemu_fw_cfg"
      ];

      fileSystems.${projectRoot} = lib.mkDefault {
        device = "/shares/project-root";
        fsType = "fuse.bindfs";
        options = [
          "force-user=${user}"
          "force-group=${userCfg.group}"
        ];
      };

      # whole-attr mkDefault: a module that defines the user itself replaces
      # this entirely rather than merging with it
      users.users.${user} = lib.mkDefault {
        isNormalUser = true;
        password = "";
        extraGroups = [
          "wheel"
          "network"
        ];
      };

      security.sudo.wheelNeedsPassword = lib.mkDefault false;

      # ssh over vsock. sshd is socket activated on AF_VSOCK only; the
      # regular sshd.socket on tcp is harmless behind user-mode networking.
      services.openssh = {
        enable = true;
        startWhenNeeded = true;
        openFirewall = lib.mkDefault false;
        settings.PasswordAuthentication = lib.mkDefault false;
        hostKeys = lib.mkDefault [
          {
            path = "/etc/ssh/ssh_host_ed25519_key";
            type = "ed25519";
          }
        ];
        authorizedKeysFiles = [ "/run/vmshell/authorized_keys.d/%u" ];
      };

      # runs in sysinit so the socket (sockets.target, after sysinit) can
      # order after it without dragging basic.target into a cycle
      systemd.services.vmshell-authorized-keys = {
        description = "install the vmshell client key from fw_cfg";
        wantedBy = [ "sysinit.target" ];
        before = [ "sysinit.target" ];
        after = [ "systemd-modules-load.service" ];
        unitConfig.DefaultDependencies = false;
        serviceConfig.Type = "oneshot";
        script = ''
          install -D -m 0644 \
            /sys/firmware/qemu_fw_cfg/by_name/opt/vmshell/authorized_keys/raw \
            /run/vmshell/authorized_keys.d/${user}
        '';
      };

      # systemd-ssh-generator would create sshd-vsock.socket on the same
      # port if it noticed vsock at generator time; keep it out of the way
      systemd.units."sshd-vsock.socket".enable = false;

      systemd.sockets.vmshell-ssh = {
        description = "vmshell SSH socket on AF_VSOCK";
        wantedBy = [ "sockets.target" ];
        requires = [ "vmshell-authorized-keys.service" ];
        after = [ "vmshell-authorized-keys.service" ];
        listenStreams = [ "vsock::${toString sshVsockPort}" ];
        socketConfig = {
          Accept = true;
          TriggerLimitIntervalSec = 0;
        };
      };

      # mirrors nixos's sshd@ (which only serves sshd.socket)
      systemd.services."vmshell-ssh@" = {
        description = "SSH per-connection daemon (vsock)";
        after = [ "sshd-keygen.service" ];
        wants = [ "sshd-keygen.service" ];
        stopIfChanged = false;
        path = [ sshPackage ];
        environment.LD_LIBRARY_PATH = config.system.nssModules.path;
        serviceConfig = {
          ExecStart = "-${lib.getExe' sshPackage "sshd"} -i -D -f /etc/ssh/sshd_config";
          KillMode = "process";
          StandardInput = "socket";
          StandardError = "journal";
        };
      };

      # shell agnostic (/etc/profile and /etc/zprofile both source this)
      environment.loginShellInit = ''
        if [ "$USER" = "${user}" ] && [ -d ${projectRoot} ]; then
          cd ${projectRoot}
          . ${activateShell}
        fi
      '';

      # ssh forwards the host's TERM verbatim; make sure the guest can
      # actually resolve it (kitty, foot, tmux-256color, ...)
      environment.enableAllTerminfo = true;

      nix.settings.experimental-features = [
        "nix-command"
        "flakes"
      ];

      system.stateVersion = lib.mkDefault "26.11";
    };

  mkGuestSystem =
    vm: shellAttrs:
    let
      inherit (vm) guestPlatform hostPkgs;
      hostSystem = hostPkgs.stdenv.hostPlatform.system;
      isNative = guestPlatform == hostSystem;
    in
    assert lib.assertMsg (builtins.elem hostSystem supportedHosts)
      "vmshell: unsupported host system '${hostSystem}', must be one of: ${lib.concatStringsSep ", " supportedHosts}";

    assert lib.assertMsg (builtins.elem guestPlatform supportedGuests)
      "vmshell: unsupported guest system '${guestPlatform}', must be one of: ${lib.concatStringsSep ", " supportedGuests}";

    nixpkgs.lib.nixosSystem {
      modules = [
        {
          nixpkgs.hostPlatform.system = guestPlatform;
          nixpkgs.buildPlatform.system = hostSystem;

          microvm.cpu = lib.mkIf (!isNative) "max";
        }

        microvm.nixosModules.microvm
        (guestConfig vm shellAttrs)
      ]
      ++ vm.modules;
    };

  vmExecForEnv =
    attrs:
    assert nixpkgs.lib.assertMsg (attrs ? vm) "missing `vm` attr";
    assert nixpkgs.lib.assertMsg (
      attrs.vm ? hostPlatform || attrs.vm ? pkgs
    ) "the vm must have at least `hostPlatform` or `pkgs` set";
    let
      inherit (attrs) vm;

      hostPlatform = vm.hostPlatform or hostPkgs.stdenv.buildPlatform.system;
      guestPlatform = vm.guestPlatform or hostPlatform;
      user = vm.user or "nixos";

      hostPkgs =
        vm.pkgs or (import nixpkgs {
          system = hostPlatform;
        });

      shellAttrs = builtins.removeAttrs attrs [ "vm" ];
      guest = mkGuestSystem {
        inherit
          hostPlatform
          guestPlatform
          hostPkgs
          user
          ;
        modules = vm.modules or [ ];
      } shellAttrs;
      vmexec = guest.config.microvm.declaredRunner;
    in
    {
      inherit
        vmexec
        hostPkgs
        user
        ;
    };

  # boots the vm with $1 mounted as the project root, shows the boot log
  # until sshd answers on vsock, then hands the terminal to ssh. any further
  # args become the remote command. the vm is shut down when ssh returns.
  mkRunScript =
    {
      vmexec,
      hostPkgs,
      user,
    }:
    let
      # linux hosts only, which vsock already implied
      sshProxy = "${hostPkgs.systemd}/lib/systemd/systemd-ssh-proxy";
      timeout = lib.getExe' hostPkgs.coreutils "timeout";
      ssh = lib.getExe' hostPkgs.openssh "ssh";
      sshKeygen = lib.getExe' hostPkgs.openssh "ssh-keygen";
    in
    hostPkgs.writeShellScript "vmshell-run" ''
      set -euo pipefail

      PROJECT_DIR=$1
      shift

      VM_RUNTIME_DIR=$(mktemp -d "''${TMPDIR:-/tmp}/vmshell.XXXXXX")
      QEMU_PID=
      TAIL_PID=

      cleanup() {
        if [ -n "$TAIL_PID" ]; then
          kill "$TAIL_PID" 2>/dev/null || true
        fi
        if [ -n "$QEMU_PID" ] && kill -0 "$QEMU_PID" 2>/dev/null; then
          # its `cat` would otherwise sit on our stdin forever
          ${timeout} 15 \
            ${vmexec}/bin/microvm-shutdown </dev/null >/dev/null 2>&1 || true
          for _ in $(seq 50); do
            kill -0 "$QEMU_PID" 2>/dev/null || break
            sleep 0.2
          done
          kill "$QEMU_PID" 2>/dev/null || true
        fi
        rm -rf "$VM_RUNTIME_DIR"
      }
      trap cleanup EXIT

      ln -s "$PROJECT_DIR" "$VM_RUNTIME_DIR/project"
      cd "$VM_RUNTIME_DIR"

      # one client key per run, handed to the guest through fw_cfg
      mkdir -p ssh
      ${sshKeygen} -q -t ed25519 -N "" -C vmshell -f ssh/id

      # 0-2 are reserved; anything else is fine as long as no other running
      # vm on this host picked the same one
      export VMSHELL_CID=$(( (RANDOM << 15 | RANDOM) + 3 ))

      : > console.log
      ${lib.getExe vmexec} </dev/null >qemu.log 2>&1 &
      QEMU_PID=$!

      tail -n +1 -f console.log &
      TAIL_PID=$!

      # systemd-ssh-proxy doesn't relay stdio: it connects and hands the
      # socket to ssh over stdout, hence ProxyUseFdpass
      ssh_opts=(
        -o ProxyCommand="${sshProxy} %h %p"
        -o ProxyUseFdpass=yes
        -o UserKnownHostsFile=/dev/null
        -o StrictHostKeyChecking=no
        -o IdentitiesOnly=yes
        -i ssh/id
        -p ${toString sshVsockPort}
      )
      target=${user}@vsock/$VMSHELL_CID

      # a full (quiet) login is the readiness probe: a failed vsock connect
      # returns in milliseconds, and success means the key is in place too
      # -n: don't let the probe swallow stdin meant for the real session
      until ${ssh} -n "''${ssh_opts[@]}" -o BatchMode=yes -o ConnectTimeout=2 -o LogLevel=QUIET "$target" true 2>/dev/null; do
        if ! kill -0 "$QEMU_PID" 2>/dev/null; then
          kill "$TAIL_PID" 2>/dev/null || true
          TAIL_PID=
          echo "vmshell: vm exited before sshd came up" >&2
          cat qemu.log >&2
          exit 1
        fi
        sleep 0.2
      done

      kill "$TAIL_PID" 2>/dev/null || true
      wait "$TAIL_PID" 2>/dev/null || true
      TAIL_PID=

      set +e
      ${ssh} "''${ssh_opts[@]}" -o LogLevel=ERROR "$target" "$@"
      rc=$?
      set -e

      exit $rc
    '';

  mkVMShell =
    attrs:
    let
      env = vmExecForEnv attrs;
      inherit (env) hostPkgs;
      run = mkRunScript env;
    in
    hostPkgs.mkShell {
      name = "vmshell";

      shellHook = ''
        # okay yea it's nasty... but how else are we gonna find some kind of
        # project root at runtime?
        PROJECT_DIR="$PWD"
        while [ "$PROJECT_DIR" != "/" ] && [ ! -f "$PROJECT_DIR/flake.nix" ]; do
          PROJECT_DIR=$(dirname "$PROJECT_DIR")
        done
        if [ ! -f "$PROJECT_DIR/flake.nix" ]; then
          PROJECT_DIR="$PWD"
        fi

        echo "Starting VM..."
        exec ${run} "$PROJECT_DIR"
      '';
    };

  mkVMPackage =
    attrs:
    let
      env = vmExecForEnv attrs;
      inherit (env) hostPkgs;
      run = mkRunScript env;
    in
    hostPkgs.writeShellScriptBin "vmpackage-setup" ''
      echo "Starting VM in working directory..."
      exec ${run} "$PWD" "$@"
    '';
in
{
  inherit mkVMShell mkVMPackage;
}
