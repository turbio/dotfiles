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
    guiPasswordFile = "/run/host-secrets/syncthing-gui-password";

    cert = "/run/host-secrets/syncthing-cert";
    key = "/run/host-secrets/syncthing-key";

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

  microvm.volumes = [
    {
      image = "${inventory.storage.vmsPath}/${vm.name}/index.img";
      mountPoint = "${stateDir}/db";
      size = 20480;
    }
  ];

  systemd.tmpfiles.rules = [
    "d ${stateDir} 0700 turbio users -"
    "d ${stateDir}/db 0700 turbio users -"
  ];
}
