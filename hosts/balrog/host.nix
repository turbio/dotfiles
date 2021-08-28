{ config, pkgs, lib, ... }: {
  imports = [
    ./flippyflops.nix
    ./grafana.nix
    ./index.nix
    ./schemeclub.nix
    ./evaldb.nix
    #./factorio.nix
  ];

  security.acme.email = "letsencrypt@turb.io";
  security.acme.acceptTerms = true;

  services.nginx.enable = true;
  services.nginx.virtualHosts = {
    "masonclayton.com" = {
      addSSL = true;
      enableACME = true;

      locations."/" = {
        extraConfig = ''
          return 301 https://turb.io$request_uri;
        '';
      };
    };
  };
}
