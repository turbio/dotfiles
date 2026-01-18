{
  userId,
  groupId,
  persistDataDir,
}:
{
  config,
  pkgs,
  lib,
  ...
}:
{
  users.groups.media.gid = groupId;

  users.users.jellyfin = {
    uid = userId;
    group = "media";
    isSystemUser = true;
  };

  services.jellyfin = {
    group = "media";
    user = "jellyfin";
    enable = true;

    openFirewall = true;

    dataDir = "${persistDataDir}/jellyfin/data";
    cacheDir = "${persistDataDir}/jellyfin/cache";
    configDir = "${persistDataDir}/jellyfin/config";
  };

  systemd.services.qbittorrent = {
    enable = true;
    wantedBy = [ "multi-user.target" ];
    path = [ pkgs.qbittorrent-nox ];
    environment = {
      HOME = "${persistDataDir}/qbittorrent";
    };
    serviceConfig = {
      Group = "media";
      User = "jellyfin";
      WorkingDirectory = "${persistDataDir}/qbittorrent";
      RuntimeDirectory = "qbittorrent";
      RuntimeDirectoryMode = "0750";
      ExecStart = "${pkgs.qbittorrent-nox}/bin/qbittorrent-nox --webui-port=9472 --confirm-legal-notice";
    };
  };

  systemd.tmpfiles.rules = [
    "d '${persistDataDir}/qbittorrent' 0750 jellyfin media -"
    "d '${persistDataDir}/jellyseerr' 2770 jellyfin media - -"
  ];

  # services.nginx.virtualHosts."jelly.turb.io" = {
  #   forceSSL = true;
  #   useACMEHost = "turb.io";
  #   http2 = true;

  #   locations."/" = {
  #     proxyPass = "http://localhost:8096";
  #     extraConfig = ''
  #       proxy_set_header   Host $host;
  #       proxy_set_header   X-Real-IP $remote_addr;
  #       proxy_set_header   X-Forwarded-For $proxy_add_x_forwarded_for;
  #       proxy_set_header   X-Forwarded-Proto $scheme;
  #       proxy_buffering    off;
  #     '';
  #   };

  #   locations."/socket" = {
  #     proxyPass = "http://localhost:8096";
  #     extraConfig = ''
  #       proxy_http_version 1.1;
  #       proxy_set_header   Upgrade $http_upgrade;
  #       proxy_set_header   Connection "upgrade";
  #       proxy_set_header   Host $host;
  #       proxy_set_header   X-Real-IP $remote_addr;
  #       proxy_set_header   X-Forwarded-For $proxy_add_x_forwarded_for;
  #       proxy_set_header   X-Forwarded-Proto $scheme;
  #     '';
  #   };
  # };
  # };

  services.prowlarr.enable = true;
  systemd.services.prowlarr.serviceConfig = {
    ExecStart = lib.mkForce "${lib.getExe config.services.prowlarr.package} -nobrowser -data=${persistDataDir}/prowlarr";
    SupplementaryGroups = [ "media" ];
    User = "jellyfin";
    UMask = "0007";
    ReadWritePaths = [
      "${persistDataDir}/prowlarr"
    ];
  };

  # services.prowlarr.dataDir = "${persistDataDir}/prowlarr"; // todo: in unstable

  services.jellyseerr.enable = true;
  services.jellyseerr.configDir = "${persistDataDir}/jellyseerr";
  systemd.services.jellyseerr.serviceConfig = {
    SupplementaryGroups = [ "media" ];
    User = "jellyfin";
    UMask = "0007";
    ReadWritePaths = [
      "${persistDataDir}/jellyseerr"
    ];
  };

  services.sonarr.enable = true;
  services.sonarr.group = "media";
  services.sonarr.user = "jellyfin";
  services.sonarr.dataDir = "${persistDataDir}/sonarr";

  services.radarr.enable = true;
  services.radarr.group = "media";
  services.radarr.user = "jellyfin";
  services.radarr.dataDir = "${persistDataDir}/radarr";
}
