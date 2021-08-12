{ config, pkgs, lib, ... }:
let
  html = (pkgs.writeTextDir "index.html" ''
    Hey!
    ====


    I'm Turbio
    🐧
  '');
in
{
  services.nginx.virtualHosts."turb.io" = {
    addSSL = true;
    enableACME = true;

    root = "${html}";
    extraConfig = ''
      add_header Content-Type 'text/plain; charset=utf-8';
    '';
  };
}
