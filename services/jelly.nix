{ pkgs, ... }:
{
  services.jellyfin = {
    group = "media";
    enable = true;
  };

  users.groups.media = { };
  users.users.qbittorrent = {
    group = "media";
    home = "/var/lib/qbittorrent";
    description = "qbittorrent Daemon user";
    isSystemUser = true;
  };
  systemd.services.qbittorrent = {
    enable = true;
    wantedBy = [ "multi-user.target" ];
    path = [ pkgs.qbittorrent-nox ];
    serviceConfig = {
      SupplementaryGroups = [ "users" ];
      Group = "media";
      User = "qbittorrent";
      WorkingDirectory = "/var/lib/qbittorrent";
      RuntimeDirectory = "qbittorrent";
      RuntimeDirectoryMode = "0750";
      ExecStart = "${pkgs.qbittorrent-nox}/bin/qbittorrent-nox --webui-port=9472 --confirm-legal-notice";
    };
  };

  systemd.tmpfiles.rules = [
    "d '/var/lib/qbittorrent' 0750 qbittorrent qbittorrent -"
  ];

  services.nginx.virtualHosts."bt.int.turb.io" = {
    extraConfig = ''
      allow 10.100.0.0/25;
      deny all;
    '';
    locations."/" = {
      extraConfig = ''
        proxy_set_header Host $host;
      '';
      proxyPass = "http://localhost:9472";
    };
  };

  services.nginx.virtualHosts."jelly.int.turb.io" = {
    extraConfig = ''
      allow 10.100.0.0/25;
      deny all;
    '';
    locations."/" = {
      proxyPass = "http://localhost:8096";
    };
  };

  services.nginx.virtualHosts."jelly.ballos.lan" = {
    extraConfig = ''
      allow 192.168.0.0/16;
      deny all;
    '';
    locations."/" = {
      proxyPass = "http://localhost:8096";
    };
  };
}
