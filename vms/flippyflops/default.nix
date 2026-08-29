{
  pkgs,
  repos,
  ...
}:
let
  port = 3001;
  tz = "America/Chicago";
  bin = "${(import (repos.flippyflops + "/dots.turb.io")) { inherit pkgs; }}/bin/flippyflops";
  wrapped = pkgs.writeShellScript "wrapped-flippys" "PORT=${toString port} HOST=0.0.0.0 TZ=${tz} ${bin}";
in
{
  systemd.services.flippyflops = {
    description = "flipdots as a service";
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      ExecStart = wrapped;
      MemoryLimit = "512M";
      Restart = "always";
      RestartSec = "5s";
    };
  };
}
