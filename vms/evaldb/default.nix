{
  pkgs,
  repos,
  ...
}:
let
  src = repos.evaldb;

  evalers = pkgs.stdenv.mkDerivation rec {
    name = "evaldb";
    inherit src;

    buildInputs = with pkgs; [
      cppcheck
      pkg-config
      go
      jansson
      readline
    ];

    buildPhase = ''
      make luaval duktape memtest memgraph testcounter
    '';

    installPhase = ''
      mkdir -p $out
      cp luaval $out/
      cp duktape $out/
    '';
  };

  gatewayResources = pkgs.runCommand "gateway-resources" { } ''
    mkdir -p $out
    cp -r ${src}/client $out/
    cp ${evalers}/luaval $out/
    cp ${evalers}/duktape $out/
  '';

  gateway = pkgs.buildGoModule {
    pname = "gateway";
    version = "0.0.1";

    src = pkgs.stdenv.mkDerivation {
      name = "tidy-evaldb-files";
      inherit src;
      buildPhase = ''
        rm -rf vendor
      '';
      installPhase = ''
        mkdir -p $out
        cp -r * $out/
      '';
    };

    vendorHash = "sha256-pivZRC1x1GXLIDvZQfcGEvrLa8EP22wMiBLhpdOf4Dg=";
    doCheck = false;
    proxyVendor = true;
  };

  port = 3005;
in
{
  users.users.evaldb = {
    isSystemUser = true;
    group = "evaldb";
  };
  users.groups.evaldb = { };

  systemd.services.evaldb = {
    enable = true;
    description = "evaldb";
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      ExecStart = "${gateway}/bin/gateway --path $STATE_DIRECTORY --port ${toString port}";
      WorkingDirectory = "${gatewayResources}";
      StateDirectory = "evaldb";
      User = "evaldb";
      Group = "evaldb";
      ProtectSystem = "strict";
      PrivateDevices = true;
      PrivateTmp = true;
      ProtectHome = true;
      Restart = "always";
      RestartSec = "5s";
    };
  };
}
