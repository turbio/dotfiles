{
  name,
  host,
  dataDir ? "/srv/http/${name}",
  nginxVhost
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
      "pm.max_children" = 50;
      "pm.max_requests" = 500;
      "pm.start_servers" = 2;
      "pm.min_spare_servers" = 2;
      "pm.max_spare_servers" = 5;
      "php_admin_value[error_log]" = "stderr";
      "php_admin_flag[log_errors]" = true;
      "catch_workers_output" = true;
      "request_terminate_timeout" = "30s";
      "slowlog" = "${dataDir}/../php-fpm-slow.log";
      "request_slowlog_timeout" = "3s";


    };
    phpEnv."PATH" = lib.makeBinPath [ pkgs.php ];
  };
  services.nginx = {
    appendHttpConfig = ''
      limit_req_zone $binary_remote_addr zone=mylimit:10m rate=10r/s;
    '';

    enable = true;
    virtualHosts.${host} = {
      listenAddresses = [
        "10.100.1.2"
        "10.100.2.2"
        "10.100.3.2"
        "10.100.4.2"
      ];

      locations."/" = {
        root = dataDir;
        index = "index.php";
      };

      locations."~ \\.php$" = {
        root = dataDir;
        # 10 concurrent reqs
        # throttle 104/s after 10 in queue
        # reject over 20 reqs in queue
        extraConfig = ''
          #limit_req zone=mylimit burst=20 delay=10;
          fastcgi_index index.php;
          fastcgi_split_path_info ^(.+\.php)(/.+)$;
          fastcgi_pass unix:${config.services.phpfpm.pools.${name}.socket};
          include ${pkgs.nginx}/conf/fastcgi.conf;
        '';
      };
    } // nginxVhost;
  };
  users.users.${name} = {
    isSystemUser = true;
    createHome = true;
    group = name;
  };
  users.groups.${name} = { };
}
