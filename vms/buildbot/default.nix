{
  pkgs,
  lib,
  repos,
  inventory,
  vm,
  ...
}:
{
  imports = [
    repos.buildbot-nix.nixosModules.buildbot-master
    repos.buildbot-nix.nixosModules.buildbot-worker
  ];

  microvm.balloon = true;

  microvm.writableStoreOverlay = "/nix/.rw-store";
  microvm.volumes = [
    {
      image = "${inventory.storage.vmsPath}/${vm.name}/nix-store-overlay.img";
      mountPoint = "/nix/.rw-store";
      size = 307200;
    }
  ];

  nix.gc = {
    automatic = true;
    dates = "daily";
    options = "--delete-older-than 3d";
  };

  services.fstrim.enable = true;

  nix.enable = lib.mkForce true;
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
    "pipe-operators"
  ];

  nix.settings.substituters = [
    "https://nixcache.int.turb.io"
    "https://nix-community.cachix.org"
    "https://cache.nixos.org/"
  ];
  nix.settings.trusted-public-keys = [
    "nixcache.turb.io:FFCylJ0fphGs8IdYdpZBczLpUM9QRDzlN1oIUf2VxHI="
    "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
  ];

  services.buildbot-nix.master = {
    enable = true;
    domain = "ci.turb.io";
    workersFile = pkgs.writeText "buildbot-workers.json" (
      builtins.toJSON [
        {
          name = "buildbot";
          pass = "password";
          cores = vm.vcpu;
        }
      ]
    );
    useHTTPS = true;
    authBackend = "gitea";
    admins = [ "turbio" ];
    gitea = {
      enable = true;
      instanceUrl = "https://forge.turb.io";
      oauthId = "buildbot";
      oauthSecretFile = "/run/host-secrets/forgejo-oauth-secret";
      tokenFile = "/run/host-secrets/forgejo-api-token";
      webhookSecretFile = "/run/host-secrets/forgejo-webhook-secret";
    };
    buildSystems = [
      "x86_64-linux"
    ];
    branches.all.matchGlob = "*";
    buildMaxSilentTime = 7200;
    evalWorkerCount = 2;
  };

  services.buildbot-nix.worker = {
    enable = true;
    workerPasswordFile = pkgs.writeText "buildbot-worker-password" "password";
  };

  systemd.services.buildbot-master.serviceConfig.ExecStartPre = [
    "${pkgs.coreutils}/bin/rm -f /var/lib/buildbot/gitea-project-cache.json"
  ];
}
