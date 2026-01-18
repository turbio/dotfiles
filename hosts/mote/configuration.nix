{ ... }:
{
  networking.firewall.enable = false;

  boot.binfmt.emulatedSystems = [ "aarch64-linux" ];

  boot.supportedFilesystems = [ "nfs" ];

  services.cachefilesd = {
    enable = true;
    cacheDir = "/scratch/cachefilesd";
  };

  fileSystems."/persist" = {
    device = "ballos.lan:/tank/enc/jellyfin";
    fsType = "nfs";
  };

  fileSystems."/media" = {
    device = "ballos.lan:/tank/enc/media";
    fsType = "nfs";
    options = [
      "rw"
      "noatime"
      "fsc"
      "lookupcache=all"
      "actimeo=60"
    ];
  };

  systemd.tmpfiles.rules = [
    "d /scratch/jellycache 0755 jellyfin media -"
  ];
  fileSystems."/persist/jellyfin/cache" = {
    device = "/scratch/jellycache";
    options = [ "bind" ];
  };

  users.users.jellyfin = {
    isSystemUser = true;
    group = "media";
    uid = 996;
  };
  users.groups.media = {
    gid = 994;
  };

  imports = [
    (import ../../services/jelly.nix {
      userId = 996;
      groupId = 994;
      persistDataDir = "/persist";
    })
  ];

  networking.firewall = {
    allowedTCPPorts = [
      8096 # jellyfin
      9472 # qbittorrent
      9696 # prowlarr
      5055 # seerr
      7878 # radarr
      8989 # sonarr
    ];
  };
}
