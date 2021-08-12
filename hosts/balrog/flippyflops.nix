{ config, pkgs, lib, ... }:
let
  flippyflops = rec {
    port = 3001;
    host = "127.0.0.1";
    bin = "${
      (import (pkgs.fetchFromGitHub {
        owner = "turbio";
        repo = "flippyflops";
        rev = "master";
        sha256 = "1d92zrc5gz8b14zjyy9380jajyn8ldz31q6y70yj3d6lhw40j4lr";
      })) { inherit port host; }
    }/bin/flippyflops";
  };
in
{
  services.nginx.virtualHosts."dots.turb.io" = {
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

  systemd.services.flippyflops = {
    description = "flipdots as a service";
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      ExecStart = flippyflops.bin;
    };
  };
}
