{ config, pkgs, lib, ... }: {
  imports = [
    ./flippyflops.nix
    ./grafana.nix
    ./index.nix
    ./schemeclub.nix
    ./evaldb.nix
    ./protip.nix
    #./factorio.nix
  ];

  systemd.services.evergreen.startAt = "minutely";

  security.acme.email = "letsencrypt@turb.io";
  security.acme.acceptTerms = true;

  services.nginx.appendHttpConfig = ''
    error_log stderr;
    access_log syslog:server=unix:/dev/log combined;
  '';

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
