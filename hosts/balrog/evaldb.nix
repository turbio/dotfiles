{ config, pkgs, lib, ... }:
let
  src = pkgs.fetchFromGitHub {
    owner = "turbio";
    repo = "evaldb";
    rev = "master";
    sha256 = "1pn6daazwxfcs3l9xlxhazdpl19rrxf1za60ab72absl9wqdzns1";
  };

  evaldb = pkgs.stdenv.mkDerivation rec {
    name = "evaldb";
    inherit src;

    buildInputs = with pkgs; [
      go
      jansson
      readline
    ];

    buildPhase = ''
      pwd
      ls
      make
    '';

    installPhase = ''
      mkdir -p $out/bin
      cp a $out/bin
    '';
  };
in
{

  /*
    systemd.services.evaldb = {
    description = "evaldb";
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
    ExecStart = "${evaldb}/bin/gateway";
    };
    };
  */
}
