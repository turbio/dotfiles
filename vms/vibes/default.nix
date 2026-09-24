{ pkgs, ... }:
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

  mediaRoot = "/media";
  port = "3010";
in
{
  users.groups.media = { };
  users.users.vibes = {
    group = "media";
    isSystemUser = true;
  };

  systemd.tmpfiles.rules = [
    "d ${mediaRoot}/media 0775 vibes media -"
    "d ${mediaRoot}/cat/bop 0775 vibes media -"
    "d ${mediaRoot}/cat/flop 0775 vibes media -"
    "d ${mediaRoot}/cat/lewd 0775 vibes media -"
  ];

  systemd.services.vibes = {
    description = "just vibin";
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Group = "media";
      User = "vibes";
      ExecStart = "${vibesbin}/bin/vibes --addr 0.0.0.0:${port} --root ${mediaRoot}";
      Restart = "always";
      RestartSec = "5s";
    };
  };
}
