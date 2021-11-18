{ config, pkgs, lib, repos, ... }:
let
  stdenv = pkgs.stdenv;

  schemeclub = rec {
    src = repos.schemeclub;

    gems = (pkgs.bundlerEnv {
      name = "schemeclub-env";
      gemdir = src;
      inherit (pkgs.ruby_2_6);
    });

    start = stdenv.mkDerivation rec {
      name = "schemeclub";

      buildInputs = [
        gems
        pkgs.ruby_2_6
      ];

      inherit src;

      installPhase = ''
        ls *
      '';

    };
  };
in
{
  services.nginx.virtualHosts.  "schemeclub.com" = {
    addSSL = true;
    enableACME = true;
  };

  #systemd.services.schemeclub = {
  #  description = "webserver for schemeclub";
  #  wantedBy = [ "multi-user.target" ];

  #  serviceConfig = {
  #    ExecStart = schemeclub.start;
  #  };
  #};
}
