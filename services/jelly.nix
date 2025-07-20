{ config, pkgs, ... }:
let
  internalIp = (import ../assignments.nix).vpn.internal;
in
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
    "d '/var/lib/qbittorrent' 0750 qbittorrent media -"
  ];

  services.nginx.virtualHosts."bt.int.turb.io" = {
    extraConfig = ''
      allow ${internalIp};
      deny all;
    '';
    locations."/" = {
      extraConfig = ''
        proxy_set_header Host $host;
      '';
      proxyPass = "http://localhost:9472";
    };
  };

  services.nginx.virtualHosts."jelly.turb.io" = {
    forceSSL = true;
    enableACME = true;
    http2 = true;

    locations."/" = {
      proxyPass = "http://localhost:8096";
      extraConfig = ''
        proxy_set_header   Host $host;
        proxy_set_header   X-Real-IP $remote_addr;
        proxy_set_header   X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header   X-Forwarded-Proto $scheme;
        proxy_buffering    off;
      '';
    };

    locations."/socket" = {
      proxyPass = "http://localhost:8096";
      extraConfig = ''
        proxy_http_version 1.1;
        proxy_set_header   Upgrade $http_upgrade;
        proxy_set_header   Connection "upgrade";
        proxy_set_header   Host $host;
        proxy_set_header   X-Real-IP $remote_addr;
        proxy_set_header   X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header   X-Forwarded-Proto $scheme;
      '';
    };
  };

  services.nginx.virtualHosts."jelly.int.turb.io" = {
    extraConfig = ''
      allow ${internalIp};
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

  services.nginx.virtualHosts."prow.int.turb.io" = {
    extraConfig = ''
      allow ${internalIp};
      deny all;
    '';
    locations."/" = {
      proxyPass = "http://localhost:9696";
    };
  };

  services.prowlarr.enable = true;
  services.prowlarr.settings = {
    server = {
      urlbase = "localhost";
      port = 9696;
      bindaddress = "*";
    };
  };

  services.jellyseerr.enable = true;
  services.nginx.virtualHosts."see.int.turb.io" = {
    extraConfig = ''
      allow ${internalIp};
      deny all;
    '';
    locations."/" = {
      proxyPass = "http://localhost:${toString config.services.jellyseerr.port}";
    };
  };

  services.sonarr.enable = true;
  services.sonarr.group = "media";
  services.nginx.virtualHosts."son.int.turb.io" = {
    extraConfig = ''
      allow ${internalIp};
      deny all;
    '';
    locations."/" = {
      proxyPass = "http://localhost:${toString config.services.sonarr.settings.server.port}";
    };
  };

  services.radarr.enable = true;
  services.radarr.group = "media";
  services.nginx.virtualHosts."rad.int.turb.io" = {
    extraConfig = ''
      allow ${internalIp};
      deny all;
    '';
    locations."/" = {
      proxyPass = "http://localhost:${toString config.services.radarr.settings.server.port}";
    };
  };
}
