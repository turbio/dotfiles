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
    default = true;

    root = "${html}";
    extraConfig = ''
      charset utf-8;
      types {
          text/plain  html;
      }
    '';
  };
}
