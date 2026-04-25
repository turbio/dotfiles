{
  config,
  lib,
  repos,
  ...
}:
let
  guestUser = "nixremote";
  sshKeyPath = config.age.secrets."nix-builders-ssh-key".path;

  builders = [
    {
      alias = "aarch-builder";
      hostName = "127.0.0.1";
      port = 22022;
      systems = [ "aarch64-linux" ];
      maxJobs = 4;
      speedFactor = 1;
      verifyHostKey = false;
    }
    {
      alias = "j1";
      hostName = "j1";
      port = 22;
      systems = [ "x86_64-linux" ];
      maxJobs = 8;
      speedFactor = 2;
      verifyHostKey = true;
    }
    {
      alias = "j2";
      hostName = "j2";
      port = 22;
      systems = [ "x86_64-linux" ];
      maxJobs = 8;
      speedFactor = 2;
      verifyHostKey = true;
    }
  ];

  sshConfigForBuilder = b: ''
    Host ${b.alias}
      HostName ${b.hostName}
      Port ${toString b.port}
      User ${guestUser}
      IdentityFile ${sshKeyPath}
      ${
        if b.verifyHostKey then
          ''
            StrictHostKeyChecking accept-new
            UserKnownHostsFile /var/lib/nix-builders/known_hosts
          ''
        else
          ''
            StrictHostKeyChecking no
            UserKnownHostsFile /dev/null
          ''
      }
  '';

  buildMachineForBuilder = b: {
    hostName = b.alias;
    inherit (b) systems maxJobs speedFactor;
    sshUser = guestUser;
    sshKey = sshKeyPath;
    supportedFeatures = [
      "big-parallel"
      "benchmark"
      "nixos-test"
      "kvm"
    ];
    protocol = "ssh-ng";
  };
in
{
  imports = [
    repos.microvm.nixosModules.host
  ];

  zfs.pools.tank.datasets."enc/microvms" = {
    perms.owner = "microvm";
    perms.group = "kvm";
    perms.mode = "750";
  };

  microvm.host.enable = true;
  microvm.stateDir = config.zfs.pools.tank.datasets."enc/microvms".mountpoint;
  microvm.autostart = [ "aarch-builder" ];

  microvm.vms.aarch-builder = {
    autostart = true;
    pkgs = null;
    extraModules = [
      ../modules/nix-remote-builder.nix
    ];
    config = {
      nixpkgs.crossSystem.config = "aarch64-unknown-linux-gnu";

      networking.hostName = "aarch-builder";

      microvm = {
        hypervisor = "qemu";
        cpu = "neoverse-n1";
        vcpu = 4;
        mem = 16384;
        balloon = true;
        writableStoreOverlay = "/nix/.rw-store";
        volumes = [
          {
            image = "nix-store-overlay.img";
            mountPoint = "/nix/.rw-store";
            size = 16384;
          }
        ];

        # qemu user-mode SLiRP networking with a host-port forward to
        # the guest's sshd. No TAP, no bridge, no host networkd — the
        # SLiRP stack is qemu's userspace NAT.
        interfaces = [
          {
            type = "user";
            id = "eth0";
            mac = "02:00:00:AA:AA:01";
          }
        ];
        forwardPorts = [
          {
            from = "host";
            host.address = "127.0.0.1";
            host.port = 22022;
            guest.port = 22;
          }
        ];
      };

      services.openssh.enable = true;

      services.getty.autologinUser = "root";
      system.stateVersion = "25.11";
    };
  };

  age.secrets."nix-builders-ssh-key".owner = "root";
  age.secrets."nix-builders-ssh-key".mode = "0400";

  programs.ssh.extraConfig = lib.concatStrings (map sshConfigForBuilder builders);

  systemd.tmpfiles.rules = [
    "d /var/lib/nix-builders 0700 root root -"
  ];

  nix.distributedBuilds = true;
  nix.buildMachines = map buildMachineForBuilder builders;
  nix.extraOptions = ''
    builders-use-substitutes = true
  '';
}
