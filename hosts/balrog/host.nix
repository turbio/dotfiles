{ pkgs, stdenv, lib, ... }:

let
  turbio-index = (pkgs.writeTextDir "index.html" ''
    Hey!
    ====
    
    I'm Turbio
    🐧
  '');
in
{
  security.acme.email = "letsencrypt@turb.io";
  security.acme.acceptTerms = true;

  services.nginx.enable = true;
  services.nginx.virtualHosts = {
    "turb.io" = {
      addSSL = true;
      enableACME = true;
      root = "${turbio-index}";
      extraConfig = ''
        add_header Content-Type 'text/plain; charset=utf-8';
      '';
    };
  };
  services.nginx.gitweb = {
    enable = true;
    virtualHost = "git";
    location = "/";
  };
}
