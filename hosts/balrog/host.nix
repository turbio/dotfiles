{ config, pkgs, stdenv, lib, ... }:

let
  turbio-index = (pkgs.writeTextDir "index.html" ''
    Hey!
    ====


    I'm Turbio
    🐧
  '');
  pushgateway_addr = "127.0.0.1:9091";
in
{
  security.acme.email = "letsencrypt@turb.io";
  security.acme.acceptTerms = true;

  services.nginx.enable = true;
  services.nginx.virtualHosts = {
    "turb.io" = {
      addSSL = true;
      enableACME = true;
      root = "${turbio-index}";
      extraConfig = ''
        add_header Content-Type 'text/plain; charset=utf-8';
      '';
    };

    "dash.turb.io" = {
      addSSL = true;
      enableACME = true;

      locations."/" = {
        proxyPass = "http://unix:/${config.services.grafana.socket}";
      };
    };

    "push.turb.io" = {
      addSSL = true;
      enableACME = true;

      locations."/" = {
        proxyPass = "http://${pushgateway_addr}";
      };
    };
  };

  users.groups.grafana.members = [ "nginx" ];
  services.grafana = {
    enable = true;
    socket = "/run/grafana/grafana.sock";
    domain = "dash.turb.io";
    protocol = "socket";
    rootUrl = "https://dash.turb.io/";
  };

  services.prometheus = {
    enable = true;
    port = 9090;
    listenAddress = "127.0.0.1";

    scrapeConfigs = [
      {
        job_name = "exporter";
        static_configs = [{
          targets = [ pushgateway_addr ];
        }];
      }
    ];

  };

  services.prometheus.pushgateway = {
    enable = true;
    web.listen-address = pushgateway_addr;
  };
}
