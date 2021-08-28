{ config, pkgs, stdenv, lib, factorio-utils, ... }: {
  services.factorio = {
    enable = true;
    saveName = "nixtorio";
    game-name = "nixtorio";
    admins = [ "cbrewster" ];
    nonBlockingSaving = true;
    mods = [
      (pkgs.factorio-utils.modDrv
        {
          allRecommendedMods = false;
          allOptionalMods = false;
        }
        {
          name = "graftorio2";
          src = builtins.fetchurl {
            url = "https://github.com/remijouannet/graftorio2/releases/download/0.0.15/graftorio2_0.0.15.zip";
            sha256 = "sha256:1bf7yjp5is3ga0g4n85ni577g2n8k5kz48rbia8bbq8f2208awqd";
          };
        })
    ];
  };

  services.prometheus = {
    exporters = {
      node = {
        enabledCollectors = [ "textfile" ];
        user = "root";
        extraFlags = [
          "--collector.textfile.directory=/var/lib/factorio/script-output/graftorio2"
        ];
      };
    };
  };
}
