{ mediaRoot, domain }: { config, pkgs, lib, ... }:
let
  vibesbin = pkgs.buildGoModule {
    name = "vibes";
    version = "0.0.1";
    src = ./vibes;
    vendorHash = null;
    postPatch = ''
      go mod init vibes
    '';
  };

  port = "3010";
in
{
  system.activationScripts = {
    vibes = ''
      mkdir -p -m 775 ${mediaRoot}/media
      mkdir -p -m 775 ${mediaRoot}/cat/bop
      mkdir -p -m 775 ${mediaRoot}/cat/flop
      mkdir -p -m 775 ${mediaRoot}/cat/lewd
    '';
  };

  services.nginx.virtualHosts."${domain}" = {
    forceSSL = true;
    useACMEHost = "turb.io";

    locations."/" = {
      root = ./vibes/webroot;
      index = "index.html";
    };

    locations."/c/" = {
      proxyPass = "http://127.0.0.1:${builtins.toString port}";
    };

    locations."/media/" = {
      root = "${mediaRoot}";
    };

    extraConfig = ''
      charset utf-8;
    '';
  };

  users.groups.media = { };
  users.users.vibes = {
    group = "media";
    isSystemUser = true;
  };
  systemd.services.vibes = {
    description = "just vibin";
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Group = "media";
      User = "vibes";
      ExecStart = "${vibesbin}/bin/vibes --addr 127.0.0.1:${builtins.toString port} --root ${mediaRoot}";
      RestartSec = "5s";
    };
  };
}
