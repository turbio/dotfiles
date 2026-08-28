{
  config,
  lib,
  ...
}:
let
  guestUser = "nixremote";
  sshKeyPath = config.age.secrets."nix-builders-ssh-key".path;

  builders = [
    {
      alias = "joast";
      hostName = "aux.joast.int.turb.io";
      port = 22;
      # aarch64/armv7l/i686 are binfmt-emulated on joast (hosts/joast) —
      # slow per-core but it has 80 of them
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "armv7l-linux"
        "i686-linux"
      ];
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
      "gccarch-armv7-a"
    ];
    protocol = "ssh-ng";
  };
in
{
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
