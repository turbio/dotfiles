{
  mediaRoot,
  domain,
  pageTitle ? "vibes",
  useACMEHost ? domain,
  extraHead ? "",
}:
{
  pkgs,
  ...
}:
let
  vibesbin = pkgs.buildGoModule {
    name = "vibes";
    version = "0.0.1";
    src = ./.;
    vendorHash = null;
    postPatch = ''
      go mod init vibes
    '';
  };

  webroot = pkgs.linkFarm "vibes-webroot" [
    {
      name = "index.html";
      path = pkgs.replaceVars ./webroot/index.html {
        inherit pageTitle extraHead;
      };
    }
  ];

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
    inherit useACMEHost;
    forceSSL = useACMEHost != null;

    locations."/" = {
      root = webroot;
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
