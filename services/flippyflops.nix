{
  config,
  pkgs,
  lib,
  repos,
  ...
}:
let
  flippyflops = rec {
    port = 3001;
    host = "127.0.0.1";
    tz = "America/Chicago";
    bin = "${(import (repos.flippyflops + "/dots.turb.io")) { inherit pkgs; }}/bin/flippyflops";
    wrapped = pkgs.writeShellScript "wrapped-flippys" "PORT=${toString port} HOST=${host} TZ=${tz} ${bin}";
  };
in
{
  services.nginx.virtualHosts."dots.turb.io" = {
    forceSSL = true;
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
