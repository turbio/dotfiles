{ config, pkgs, lib, ... }:
let
  flippyflops = rec {
    port = 3001;
    host = "127.0.0.1";
    bin = "${
      (import (pkgs.fetchFromGitHub {
        owner = "turbio";
        repo = "flippyflops";
        rev = "f0f6acf315581aaabf0aeae207cd4cc04ca3c368";
        sha256 = "sha256-rf8uI+JPG7gCw1BUhoksG+kje041DT/JjrKQm9Bt1mw=";
      } + "/dots.turb.io")) { inherit pkgs; }
    }/bin/flippyflops";
    wrapped = pkgs.writeShellScript "wrapped-flippys" "PORT=${toString port} HOST=${host} ${bin}";
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
      ExecStart = flippyflops.wrapped;
      MemoryLimit = "512M";
      RestartSec = "5s";
    };
  };
}
