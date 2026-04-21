{
  config,
  pkgs,
  ...
}:
let
  zfsService = "zfs-ensure-tank-enc-forgejo.service";
in
{
  zfs.pools.tank.datasets."enc/forgejo" = {
    perms.owner = "forgejo";
    perms.group = "forgejo";
    perms.mode = "750";
  };

  services.forgejo = {
    enable = true;
    stateDir = config.zfs.pools.tank.datasets."enc/forgejo".mountpoint;

    database = {
      type = "sqlite3";
      path = "${config.zfs.pools.tank.datasets."enc/forgejo".mountpoint}/forgejo.db";
    };

    settings = {
      DEFAULT.APP_NAME = "forge";

      server = {
        DOMAIN = "forge.turb.io";
        ROOT_URL = "https://forge.turb.io/";
        HTTP_ADDR = "127.0.0.1";
        HTTP_PORT = 3300;
        SSH_PORT = 2222;
        START_SSH_SERVER = true;
      };

      service = {
        DISABLE_REGISTRATION = true;
      };

      session = {
        COOKIE_SECURE = true;
      };
    };
  };

  services.nginx.virtualHosts."forge.turb.io" = {
    forceSSL = true;
    useACMEHost = "turb.io";
    http2 = true;

    locations."/" = {
      proxyPass = "http://127.0.0.1:3300";
      extraConfig = ''
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        client_max_body_size 512M;
      '';
    };
  };

  systemd.services.forgejo-secrets.after = [ zfsService ];
  systemd.services.forgejo-secrets.requires = [ zfsService ];

  networking.firewall.allowedTCPPorts = [ 2222 ];
}
