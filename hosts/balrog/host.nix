{ pkgs, stdenv, lib, ... }: 

let
  turbio-index = (pkgs.writeTextDir "index.html" ''
      Hey!<br>
      ====<br>
      <br>
      I'm Turbio<br>
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
          add_header Content-Type 'text/html; charset=utf-8';
        '';
    };
  };
}
