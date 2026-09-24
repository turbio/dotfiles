{ ... }:
{
  networking.firewall.enable = false;

  # lan-resident server whose nfs mounts resolve ballos.int.turb.io — magicdns's ~.
  # claim would send that to public dns (NXDOMAIN) and break the mounts
  services.tailscale.extraSetFlags = [ "--accept-dns=false" ];

  boot.binfmt.emulatedSystems = [ "aarch64-linux" ];

  boot.supportedFilesystems = [ "nfs" ];

  fileSystems."/persist" = {
    device = "ballos.int.turb.io:/tank/enc/jellyfin";
    fsType = "nfs";
  };

  fileSystems."/media" = {
    device = "ballos.int.turb.io:/tank/enc/media";
    fsType = "nfs";
    options = [
      "rw"
      "noatime"
      "fsc"
      "lookupcache=all"
      "actimeo=60"
    ];
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

  services.prometheus.exporters.node = {
    enable = true;
    enabledCollectors = [ "systemd" ];
    listenAddress = "0.0.0.0";
    port = 9100;
  };
}
