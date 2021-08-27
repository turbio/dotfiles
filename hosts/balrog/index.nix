{ config, pkgs, lib, ... }:
let
  root = (pkgs.writeTextDir "index.txt" ''
    Hey!
    ====

    I'm Turbio 🐧
    I'm very offline
    This is really the extent of my web presence

    If ya wanna say hi:
      - Email me: anything @ this domain
      - Hmu on discord: turbio eight three six three
      - Or better yet: dots.turb.io

    ヾ(*ФωФ)βyё βyё☆彡
  '');

  vhost404 = (pkgs.writeTextDir "index.txt" ''
    404!
    ====

    lol
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
    default = true;

    locations."/" = { return = "404"; };

    root = "${vhost404}";
    extraConfig = ''
      error_page 404 /index.txt;
      charset utf-8;
    '';
  };
}
