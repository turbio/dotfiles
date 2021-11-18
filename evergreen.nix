{ pkgs, ... }:
let script = pkgs.writeShellScript "evergreenerr" ''
  export PATH=${pkgs.bash}/bin:$PATH
  export PATH=${pkgs.glib}/bin:$PATH
  export PATH=${pkgs.sudo}/bin:$PATH
  export PATH=${pkgs.git}/bin:$PATH
  export PATH=${pkgs.util-linux}/bin:$PATH
  export PATH=${pkgs.libnotify}/bin:$PATH
  export PATH=${pkgs.nixos-rebuild}/bin:$PATH

  ${./bin/evergreen}
'';
in
{
  systemd.services.evergreen = {
    description = "Keep those nixes up to date!";
    script = "exec ${script}";
    startAt = "hourly";
  };

  systemd.timers.evergreen = {
    timerConfig = {
      Persistent = true;
    };
  };
}
