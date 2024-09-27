{ config, pkgs, lib, repos, ... }: {
  services.photoprism.enable = true;
  services.photoprism.originalsPath = "/photos";
  services.photoprism.passwordFile = pkgs.writeText "photoprism_pass" "lmaomydude";
  systemd.services.photoprism.serviceConfig = {
    ReadWritePaths = ["/photos"];
  };
  services.photoprism.settings = {
    PHOTOPRISM_DETECT_NSFW = "false";
    PHOTOPRISM_READONLY = "false";
    PHOTOPRISM_UPLOAD_NSFW = "true";
    PHOTOPRISM_ORIGINALS_LIMIT = "-1";
    PHOTOPRISM_SITE_URL = "https://pics.turb.io/";
  };

  system.activationScripts = {
    photo-dir = ''
      mkdir -p /photos
      chmod a+rw /photos
      chown photoprism:photoprism /photos
    '';
  };

  services.nginx.virtualHosts."pics.turb.io" = {
    addSSL = true;
    enableACME = true;

    locations."/" = {
      proxyPass = "http://${config.services.photoprism.address}:${builtins.toString config.services.photoprism.port}";
      extraConfig = ''
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header Host $host;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
      '';
    };

    extraConfig = ''
      client_max_body_size 50000M;

      proxy_http_version 1.1;
      chunked_transfer_encoding off;
      proxy_buffering off;
      proxy_cache off;
    '';
  };
}
