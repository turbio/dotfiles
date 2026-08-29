# syncthing — the home instance, off joast metal (PLAN.md M7 "mid" wave).
#
# identity is carried across, not regenerated: the device id peers dial
# (6SH2YN7-…, which is why they all labelled it "ballos" — the cert moved
# with the tank pool when joast took over) comes from the host-delivered
# cert/key secrets, so nothing re-pairs. the gui password is the other half
# of the auth material: having it as a secret is what lets the panel be a
# plain tailnet-reachable name instead of an ip-allowlisted nginx vhost.
#
# the folders are virtiofs shares mounted at their host paths (inventory
# `mounts`), so the paths carry over verbatim. only the database moves:
# syncthing 2.x keeps a per-folder sqlite index (1.4G today), exactly the
# fsync-bound shape the storage policy puts on virtio-blk.
#
# cutover notes (turbio's ledger):
#   - peers had been dialling tcp://<ballos tailscale ip>:22000, dead since
#     the pool moved to joast — nothing had synced since. services/
#     syncthing.nix now points them at this vm's address, reachable from
#     the tailnet over joast's advertised 10.42.0.0/16. gero and the iphone
#     aren't in this repo: change the address in their own guis
#   - to skip a full rescan, seed the index from the old config dir (which
#     the guest can see, it's inside the enc/misc share):
#       systemctl stop syncthing
#       cp -a /tank/enc/misc/config/index-v2 /var/lib/syncthing/db/
#       chown -R turbio:users /var/lib/syncthing/db
#   - deletable once happy: /tank/enc/misc/config (the old config dir —
#     cert/key are secrets/syncthing-{cert,key}.age now, the index lives on
#     the blk volume)
{
  inventory,
  vm,
  ...
}:
let
  stateDir = "/var/lib/syncthing";
in
{
  imports = [ ../../services/syncthing.nix ];

  # the shares pass uids straight through and the pool's copies are
  # turbio:users (1000:100), which is what services/syncthing.nix runs as
  users.users.turbio = {
    isNormalUser = true;
    uid = 1000;
    group = "users";
    home = stateDir;
    createHome = false;
  };

  services.syncthing = {
    enable = true;

    guiAddress = "0.0.0.0:80";

    settings.gui.user = "turbio";
    # bcrypted into config.xml by syncthing-init on every switch
    guiPasswordFile = "/run/host-secrets/syncthing-gui-password";

    # the device identity. without these a fresh configDir would mint a new
    # device id and every peer would need to re-add this one
    cert = "/run/host-secrets/syncthing-cert";
    key = "/run/host-secrets/syncthing-key";

    # config.xml + the api key on the persistVar dataset (snapshotted by
    # sanoid with every other vm's /var); the sqlite index on its own
    # virtio-blk volume below
    configDir = "${stateDir}/config";
    databaseDir = "${stateDir}/db";

    settings.folders = {
      "photos" = {
        enable = true;
        path = "/tank/enc/photos";
      };
      "code" = {
        enable = true;
        path = "/tank/enc/code";
      };
      "notes" = {
        enable = true;
        path = "/tank/enc/misc/notes";
      };
      "clips" = {
        enable = true;
        path = "/tank/enc/misc/clips";
      };
      "webcamlog" = {
        enable = true;
        path = "/tank/enc/webcamlog";
      };
    };
  };

  boot.kernel.sysctl."net.ipv4.ip_unprivileged_port_start" = 80;

  # index-v2 is 1.4G of sqlite on the pool today and grows with file count;
  # 20G sparse leaves plenty of room
  microvm.volumes = [
    {
      image = "${inventory.storage.vmsPath}/${vm.name}/index.img";
      mountPoint = "${stateDir}/db";
      size = 20480;
    }
  ];

  # the blk volume mounts root-owned; syncthing runs as turbio
  systemd.tmpfiles.rules = [
    "d ${stateDir} 0700 turbio users -"
    "d ${stateDir}/db 0700 turbio users -"
  ];
}
