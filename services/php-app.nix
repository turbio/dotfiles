{
  name,
  host,
  dataDir ? "/srv/http/${host}",
}:
{
  config,
  pkgs,
  lib,
  ...
}:
{
  services.phpfpm.pools.${name} = {
    user = name;
    settings = {
      "listen.owner" = config.services.nginx.user;
      "pm" = "dynamic";
      "pm.max_children" = 32;
      "pm.max_requests" = 500;
      "pm.start_servers" = 2;
      "pm.min_spare_servers" = 2;
      "pm.max_spare_servers" = 5;
      "php_admin_value[error_log]" = "stderr";
      "php_admin_flag[log_errors]" = true;
      "catch_workers_output" = true;
    };
    phpEnv."PATH" = lib.makeBinPath [ pkgs.php ];
  };
  services.nginx = {
    enable = true;
    virtualHosts.${host} = {
      forceSSL = true;
      enableACME = true;

      locations."/" = {
        root = dataDir;
        index = "index.php";
      };

      locations."~ \\.php$" = {
        root = dataDir;
        extraConfig = ''
          fastcgi_index index.php;
          fastcgi_split_path_info ^(.+\.php)(/.+)$;
          fastcgi_pass unix:${config.services.phpfpm.pools.${name}.socket};
          include ${pkgs.nginx}/conf/fastcgi.conf;
        '';
      };
    };
  };
  users.users.${name} = {
    isSystemUser = true;
    createHome = true;
    group = name;
  };
  users.groups.${name} = { };
}
