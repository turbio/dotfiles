{ config, pkgs, lib, repos, ... }:
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

  gateway = pkgs.buildGoModule {
    pname = "gateway";
    version = "0.0.1";

    src = pkgs.stdenv.mkDerivation {
      name = "tidy-evaldb-files";
      inherit src;
      buildPhase = ''
        substitute cmd/gateway/main.go cmd/gateway/main.go \
          --replace '":"' '"127.0.0.1:"'
        rm -rf vendor
      '';
      installPhase = ''
        mkdir -p $out
        cp -r * $out/
      '';
    };

    vendorSha256 = "sha256-/jwrbJfDqo95JPrf7OzVIOavN0yOOJkWqAAGyMDyLvU=";
    runVend = true;
    doCheck = false;
  };
  dbroot = "/evaldb";
  dbstore = "${dbroot}/store";
  port = 3005;
in
{
  system.activationScripts = {
    evaldb = ''
      mkdir -p ${dbstore}/dbs
      rm -rf ${dbroot}/client
      cp -r ${src}/client ${dbroot}
      ln -sf ${evalers}/luaval ${dbroot}
      ln -sf ${evalers}/duktape ${dbroot}
    '';
  };

  services.nginx.virtualHosts."evaldb.turb.io" = {
    addSSL = true;
    enableACME = true;
    default = true;

    locations."/" = {
      proxyPass = "http://127.0.0.1:${builtins.toString port}";
      extraConfig = ''
        proxy_set_header Host $host;
      '';
    };

    extraConfig = ''
      proxy_http_version 1.1;
      chunked_transfer_encoding off;
      proxy_buffering off;
      proxy_cache off;
    '';
  };

  systemd.services.evaldb = {
    description = "evaldb";
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      ExecStart = "${gateway}/bin/gateway --path ${dbstore} --port ${toString port}";
      WorkingDirectory = dbroot;
    };
  };
}
