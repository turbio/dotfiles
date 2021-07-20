{ config, pkgs, lib, ... }:
let
  stdenv = pkgs.stdenv;
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
      (import (pkgs.fetchFromGitHub {
        owner = "turbio";
        repo = "flippyflops";
        rev = "master";
        sha256 = "1rjk5sf6qswnpawxz429qkpnrzd2iyilqdjf7k51zs0g56w3g86q";
      })) { inherit port host; }
    }/bin/flippyflops";
  };
  schemeclub = rec {
    src = pkgs.fetchFromGitHub {
      owner = "turbio";
      repo = "schemeclub";
      rev = "nix";
      sha256 = "1id3m0pmgv5jj98b16i8jqkakz3hv5x0ikzrlnfsidfww959n3gg";
    };

    gems = (pkgs.bundlerEnv {
      name = "schemeclub-env";
      gemdir = src;
      inherit (pkgs.ruby_2_6);
    });

    start = stdenv.mkDerivation rec {
      name = "schemeclub";

      buildInputs = [
        gems
        pkgs.ruby_2_6
      ];

      inherit src;

      installPhase = ''
        ls *
      '';

    };
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

    "schemeclub.com" = {
      addSSL = true;
      enableACME = true;
    };

    "masonclayton.com" = {
      addSSL = true;
      enableACME = true;

      locations."/" = {
        extraConfig = ''
          return 301 https://turb.io$request_uri;
        '';
      };
    };
  };

  systemd.services.flippyflops = {
    description = "flipdots as a service";
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      ExecStart = flippyflops.bin;
    };
  };

  #systemd.services.schemeclub = {
  #  description = "webserver for schemeclub";
  #  wantedBy = [ "multi-user.target" ];

  #  serviceConfig = {
  #    ExecStart = schemeclub.start;
  #  };
  #};
}
