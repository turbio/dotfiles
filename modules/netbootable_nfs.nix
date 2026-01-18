{
  config,
  lib,
  pkgs,
  modulesPath,
  ...
}:
let
  scratchPath = "/scratch";
  scratchInitrdPath = "/sysroot${scratchPath}";
  squashfsInitrdPath = "${scratchInitrdPath}/nix-store.squashfs";
  rwStoreInitrdPath = "${scratchInitrdPath}/rw-store";
  rwStorePath = "${scratchPath}/rw-store";
in
{
  # Show journal on tty1 instead of login prompt for debugging
  services.journald.console = "/dev/tty1";

  boot.loader.grub.enable = false;

  imports = [ (modulesPath + "/profiles/all-hardware.nix") ];

  boot.initrd.availableKernelModules = [
    "e1000e"
    "ext4"
    "loop"
    "af_packet"
    "autofs4"
    "autofs"
    "nfs"
    "nfsv4"
    "overlay"
    "bnx2x"
    "igb"
    "mlx4_en"
    "mlx4_core"
    "mlx5_core"
    "qla4xxx"
    "ixgbe"
    "i40e"
    "be2net"
    "cxgb4"
  ];

  hardware.enableRedistributableFirmware = true;

  boot.initrd.kernelModules = [
    "autofs4"
  ];

  boot.initrd.systemd.enable = true;

  boot.initrd.systemd.initrdBin = [
    pkgs.iproute2
    pkgs.unixtools.ping
    pkgs.curl
    config.boot.initrd.systemd.package.util-linux
    pkgs.coreutils
    pkgs.e2fsprogs
  ];

  boot.initrd.network = {
    enable = true;
    flushBeforeStage2 = false;
  };

  boot.initrd.supportedFilesystems = [ "nfs" ];

  networking.useDHCP = true;

  boot.resumeDevice = lib.mkImageMediaOverride "";
  swapDevices = lib.mkImageMediaOverride [ ];

  services.rpcbind.enable = true;

  fileSystems = {
    "/" = {
      device = "tmpfs";
      fsType = "tmpfs";
      options = [ "mode=0755" ];
      neededForBoot = true;
    };
    #"/nix/.rw-store" = {
    #  fsType = "tmpfs";
    #  neededForBoot = true;
    #};
    #"/nix/.ro-store" = {
    #  neededForBoot = true;
    #  fsType = "nfs";
    #  options = [
    #    "ro"
    #    "noatime"
    #    "addr=192.168.86.114"
    #    "nfsvers=4"
    #    "local_lock=all"
    #  ];
    #  device = "192.168.86.114:/nix/store";
    #};
    #"/nix/store" = {
    #  neededForBoot = true;
    #  fsType = "overlay";
    #  depends = [
    #    "/nix/.ro-store"
    #    "/nix/.rw-store/store"
    #    "/nix/.rw-store/work"
    #  ];
    #  overlay = {
    #    lowerdir = [ "/nix/.ro-store" ];
    #    upperdir = "/nix/.rw-store/store";
    #    workdir = "/nix/.rw-store/work";
    #  };
    #  device = "overlay";
    #};

    "/nix/.ro-store" = {
      device = squashfsInitrdPath;
      fsType = "squashfs";
      options = [
        "loop"
        "ro"
        "x-systemd.requires=fetch-store-squashfs.service"
      ];
      neededForBoot = true;
    };

    "/nix/.rw-store" = {
      device = rwStorePath;
      fsType = "none";
      options = [
        "bind"
        "x-systemd.requires=setup-scratch.service"
      ];
      neededForBoot = true;
    };

    "/nix/store" = {
      device = "overlay";
      fsType = "overlay";
      neededForBoot = true;
      overlay = {
        upperdir = "/nix/.rw-store/store";
        workdir = "/nix/.rw-store/work";
        lowerdir = [ "/nix/.ro-store" ];
      };
    };

  };

  /*
    boot.initrd.systemd.mounts = [
      {
        where = scratch.path;
        what = "/dev/disk/by-label/scratch";
        type = "auto";
        options = "x-mount.mkdir";
        wantedBy = [ "initrd-switch-root.target" ];
        before = [ "initrd-switch-root.target" ];
        after = [ "sysroot.mount" ];
        wants = [ "sysroot.mount" ];
        unitConfig = {
          ConditionPathExists = "/dev/disk/by-label/scratch";
          DefaultDependencies = false;
        };
      }
      {
        where = scratch.path;
        what = "tmpfs";
        type = "tmpfs";
        options = "mode=0755,x-mount.mkdir";
        wantedBy = [ "initrd-switch-root.target" ];
        before = [ "initrd-switch-root.target" ];
        after = [ "sysroot.mount" ];
        wants = [ "sysroot.mount" ];
        unitConfig = {
          ConditionPathExists = "!/dev/disk/by-label/scratch";
          DefaultDependencies = false;
        };
      }
    ];
  */

  # Set up /scratch - either from partition labeled "scratch" or tmpfs fallback.
  boot.initrd.systemd.services.setup-scratch = {
    description = "Set up scratch space";
    wantedBy = [ "initrd-switch-root.target" ];
    before = [ "initrd-switch-root.target" ];
    after = [ "sysroot.mount" ];
    wants = [ "sysroot.mount" ];

    unitConfig.DefaultDependencies = false;
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    path = [
      config.boot.initrd.systemd.package.util-linux
      pkgs.coreutils
      pkgs.e2fsprogs
    ];

    script = ''
      set -euo pipefail

      mkdir -p ${scratchInitrdPath}
      scratch_dev=$(blkid -L scratch 2>/dev/null || true)

      if [ -n "$scratch_dev" ]; then
        mkfs.ext4 -F -L scratch "$scratch_dev"
        mount "$scratch_dev" ${scratchInitrdPath}
      else
        echo "WARNING: No scratch partition - using tmpfs"
        mount -t tmpfs -o mode=0755 tmpfs ${scratchInitrdPath}
      fi

      mkdir -p ${rwStoreInitrdPath}/store
      mkdir -p ${rwStoreInitrdPath}/work
    '';
  };

  boot.initrd.systemd.services.fetch-store-squashfs = {
    description = "Fetch nix-store.squashfs";
    wantedBy = [ "initrd-switch-root.target" ];
    before = [ "initrd-switch-root.target" ];
    after = [
      "sysroot.mount"
      "network-online.target"
      "setup-scratch.service"
    ];
    wants = [
      "sysroot.mount"
      "network-online.target"
      "setup-scratch.service"
    ];

    unitConfig.DefaultDependencies = false;
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    path = [
      pkgs.curl
      pkgs.coreutils
    ];

    script = ''
      set -euo pipefail
      url=""
      for param in $(cat /proc/cmdline); do
        case "$param" in
          store_url=*) url="''${param#store_url=}" ;;
        esac
      done
      test -n "$url"

      # Parse Content-Length header using bash (no awk/grep in initrd)
      download_size=""
      while IFS=': ' read -r header value; do
        case "$header" in
          [Cc]ontent-[Ll]ength) download_size=$(echo "$value" | tr -d '\r') ;;
        esac
      done < <(curl -sfI "$url")
      available=$(df -B1 --output=avail ${scratchInitrdPath} | tail -1 | tr -d ' ')

      if [ -n "$download_size" ] && [ -n "$available" ]; then
        download_mb=$((download_size / 1024 / 1024))
        available_mb=$((available / 1024 / 1024))
        echo "Downloading $download_mb MB ($available_mb MB available)"
        if [ "$download_size" -gt "$available" ]; then
          echo "WARNING: Download ($download_mb MB) exceeds available space ($available_mb MB)"
        fi
      fi

      curl -fL "$url" -o ${squashfsInitrdPath}
    '';
  };

  boot.initrd.systemd = {
    emergencyAccess = true;
  };

  system.build.netbootKernel = config.system.build.kernel;
  system.build.netbootRamdisk = config.system.build.initialRamdisk;
  system.build.netbootCmdline = toString (
    [ "init=${config.system.build.toplevel}/init" ] ++ config.boot.kernelParams
  );
  system.build.squashfsStore = pkgs.callPackage "${modulesPath}/../lib/make-squashfs.nix" {
    storeContents = [ config.system.build.toplevel ];
    comp = "zstd -Xcompression-level 22";
  };

  boot.postBootCommands = ''
    ${config.nix.package}/bin/nix-store --load-db < /nix/store/nix-path-registration
    touch /etc/NIXOS
    ${config.nix.package}/bin/nix-env -p /nix/var/nix/profiles/system --set /run/current-system
  '';
}
