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
in
{
  services.nginx.virtualHosts."turb.io" = {
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

  services.nginx.virtualHosts."404.turb.io" = {
    addSSL = true;
    enableACME = true;

    root = "${vhost404}";
    locations."/" = {
      root = "${vhost404}";
      index = "404.txt";
    };

    extraConfig = ''
      error_page 404 /;
      charset utf-8;
    '';
  };
}
