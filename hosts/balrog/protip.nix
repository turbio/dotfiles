{ config, pkgs, lib, ... }:
let
  root = (pkgs.writeTextDir "index.txt" ''
    https://nohello.net/
    https://dontasktoask.com/
    https://xyproblem.info/
  '');
in
{
  services.nginx.virtualHosts."protip.turb.io" = {
    addSSL = true;
    enableACME = true;

    root = "${root}";

    locations."/" = {
      index = "index.txt";
    };

    extraConfig = ''
      charset utf-8;
    '';
  };
}
