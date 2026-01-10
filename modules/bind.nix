{ lib, ... }:
let
  zones =
    lib.fileset.toList (lib.fileset.fileFilter (file: file.hasExt "zone") ../zones)
    |> lib.map (p: {
      name = lib.removeSuffix ".zone" (baseNameOf p);
      value = {
        master = true;
        file = p;
      };
    })
    |> lib.listToAttrs;
in
{
  networking.firewall.allowedUDPPorts = [ 53 ];
  services.bind = {
    enable = true;

    inherit zones;
  };
}
