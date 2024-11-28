{ config, pkgs, lib, ... }:
let
  hume = {
    yume = "aaa";
  };

  root = (pkgs.writeTextDir "index.txt" ''
    hey!
    ====

    i'm mason / turbio

    🐧
  '');

  vhost404 = (pkgs.writeTextDir "404.txt" ''
    404!
    ====

    uh oh
  '');

  turbio404 = (pkgs.writeTextDir "404.txt" ''
    404!
    ====

    but like what were you expecting?
  '');
in
{
  networking.firewall.allowedTCPPorts = [ 80 443 ];

  services.nginx.virtualHosts."turb.io" = {
    forceSSL = true;
    enableACME = true;

    root = "${root}";

    locations."/" = {
      index = "index.txt";
    };

    locations."=/404.txt" = {
      root = "${turbio404}";
      index = "404.txt";
    };

    extraConfig = ''
      error_page 404 /404.txt;
      charset utf-8;
    '';
  };

  services.nginx.virtualHosts."404.turb.io" = {
    addSSL = true;
    enableACME = true;

    root = "${vhost404}";

    locations."/" = {
      return = "404";
    };

    locations."=/404.txt" = {
      extraConfig = ''
        internal;
      '';
    };

    extraConfig = ''
      error_page 404 /404.txt;
      charset utf-8;
    '';
  };
}
