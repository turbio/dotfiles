{ config, pkgs, lib, ... }:
let
  stdenv = pkgs.stdenv;

  schemeclub = rec {
    src = pkgs.fetchFromGitHub {
      owner = "turbio";
      repo = "schemeclub";
      rev = "nix";
      sha256 = "1id3m0pmgv5jj98b16i8jqkakz3hv5x0ikzrlnfsidfww959n3gg";
    };

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
