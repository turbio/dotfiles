{ config, pkgs, stdenv, lib, ... }:

let
  turbio-index = (pkgs.writeTextDir "index.html" ''
    Hey!
    ====


    I'm Turbio
    🐧
  '');
  flippyflops = rec {
    port = 3001;
    host = "127.0.0.1";
    bin = "${
      (import (builtins.fetchTarball {
        url = https://github.com/turbio/flippyflops/archive/master.tar.gz;
      })) { inherit port host; }
    }/bin/flippyflops";
  };
in
{
  imports = [
    ./grafana.nix
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
        proxyPass = "http://${config.services.prometheus.pushgateway.web.listen-address}";
      };
    };

    "dots.turb.io" = {
      addSSL = true;
      enableACME = true;

      locations."/" = {
        proxyPass = "http://${flippyflops.host}:${builtins.toString flippyflops.port}";
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
      ExecStart = flippyflops.bin;
    };
  };
}
