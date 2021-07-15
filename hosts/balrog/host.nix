{ config, pkgs, stdenv, lib, ... }:

let
  turbio-index = (pkgs.writeTextDir "index.html" ''
    Hey!
    ====


    I'm Turbio
    🐧
  '');
  prom = config.services.prometheus;
in
{
  nixpkgs.overlays = [
    (a: b: {
      flippyflops =
        (import (builtins.fetchTarball {
          url = https://github.com/turbio/flippyflops/archive/master.tar.gz;
        }));
    })
  ];

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
        proxyPass = "http://${prom.pushgateway.web.listen-address}";
      };
    };

    "dots.turb.io" = {
      addSSL = true;
      enableACME = true;

      locations."/" = {
        proxyPass = "http://127.0.0.1:3001";
      };

      extraConfig = ''
        proxy_http_version 1.1;
        chunked_transfer_encoding off;
        proxy_buffering off;
        proxy_cache off;
      '';
    };
  };

  systemd.services.flippyflops = {
    description = "flipdots as a service";
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      ExecStart = "${pkgs.flippyflops { port = 3001;
      host = "127.0.0.1";
    }}/bin/flippyflops";
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
        job_name = "pushgateway";
        scrape_interval = "5s";
        static_configs = [{
          targets = [ prom.pushgateway.web.listen-address ];
        }];
      }
      {
        job_name = "nodexporter";
        static_configs = [{
          targets = [ "127.0.0.1:${toString prom.exporters.node.port}" ];
        }];
      }
    ];

    exporters = {
      node = {
        enable = true;
        enabledCollectors = [ "systemd" ];
        listenAddress = "127.0.0.1";
        port = 9092;
      };
    };
  };

  services.prometheus.pushgateway = {
    enable = true;
    web.listen-address = "127.0.0.1:9091";
  };
}
