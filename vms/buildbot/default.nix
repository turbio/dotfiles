# buildbot — master AND worker in one vm (cut over 2026-07-30). the module
# brings its own postgres and a plain-http nginx vhost; ballos's ci.turb.io
# vhost terminates tls and proxies in. secrets arrive host-delivered at
# /run/host-secrets (inventory `secrets`).
#
# builds run *inside* the vm — deliberate: ci executes code from pushed
# commits, and the vm is the containment. that makes this the one guest
# with nix enabled: the host store stays a read-only share, new paths land
# in a writable overlay backed by a disk image in the vm's dataset (tmpfs
# would eat guest ram; overlay-upper-on-virtiofs isn't supported).
#
# ledger (turbio's):
#   - ballos postgres still carries the old unused `buildbot` db
#   - builds have no /dev/kvm (no nested virt): nixos vm tests would need it
#   - tabled 2026-07-30: feed nixcache.turb.io from ci — postBuildSteps
#     running `nix copy --to file:///cache?secret-key=...` with the cache
#     dataset (enc/nixcache) as an inventory mount and the signing key
#     host-delivered; makes fleet deploys download ci-built paths
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

  # virtio-balloon with free-page-reporting: eval spikes are huge and
  # transient, this hands the freed pages back to the host instead of
  # ratcheting qemu's rss to the peak forever. no host-driven inflation,
  # just the automatic give-back.
  microvm.balloon = true;

  microvm.writableStoreOverlay = "/nix/.rw-store";
  microvm.volumes = [
    {
      image = "${inventory.storage.vmsPath}/${vm.name}/nix-store-overlay.img";
      mountPoint = "/nix/.rw-store";
      # 100G filled after a day of builds (2026-07-31); sparse and
      # zfs-compressed so the ceiling is cheap. NOTE: size applies on
      # image creation — rm the image (vm stopped) to grow.
      size = 307200;
    }
  ];

  # standard scheduled gc; ci artifacts age fast. (caveat, untested: gc on
  # the overlay store may also try to delete lower/host store paths it
  # considers invalid, writing whiteouts into the upper layer — if the
  # write layer fills *faster* after gc runs, that's what happened.)
  nix.gc = {
    automatic = true;
    dates = "daily";
    options = "--delete-older-than 3d";
  };
  # the volume attaches with discard=unmap: trimming after gc punches the
  # freed blocks back out of the sparse image so host-side actual size
  # tracks live usage instead of ratcheting to the high-water mark
  services.fstrim.enable = true;

  # vm-guest disables nix fleet-wide; the ci vm is the exception
  nix.enable = lib.mkForce true;
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
    # the dotfiles flake uses |> (ballos has this via trusted-settings;
    # the ci vm needs it in nix.conf for nix-eval-jobs)
    "pipe-operators"
  ];
  # guests don't get the fleet configuration.nix, so the ci vm needs its
  # own substituter list — local cache first at the internal name (direct
  # to ballos via the machine grant, not the cloud-edge detour)
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
    # mote's cudaSupport makes opencv a from-source build whose cuda link
    # steps go >20min without output; the 1200s default killed it at 97%
    buildMaxSilentTime = 7200;
    # each eval worker can hit ~15G on this repo (ballos embeds all the vm
    # systems); two keeps peak inside the vm's 32G with room for builds
    evalWorkerCount = 2;
  };

  # the worker lives beside the master: default masterUrl is localhost, and
  # its name defaults to the hostname, matching the workersFile entry
  services.buildbot-nix.worker = {
    enable = true;
    workerPasswordFile = pkgs.writeText "buildbot-worker-password" "password";
  };

  # refetch ssh_url etc. from the live forgejo API on every start instead of
  # trusting a stale project cache (mirrors the old host instance's fix)
  systemd.services.buildbot-master.serviceConfig.ExecStartPre = [
    "${pkgs.coreutils}/bin/rm -f /var/lib/buildbot/gitea-project-cache.json"
  ];
}
