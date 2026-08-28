# flipdots as a service — the vm-ization canary: stateless, one port.
# moved from services/flippyflops.nix (which keeps only the nginx vhost).
{
  pkgs,
  repos,
  ...
}:
let
  port = 3001;
  tz = "America/Chicago";
  bin = "${(import (repos.flippyflops + "/dots.turb.io")) { inherit pkgs; }}/bin/flippyflops";
  # bind everything: who may actually reach the port is the guest firewall's
  # + host vmpolicy's job, and binding the vm ip races address assignment
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
