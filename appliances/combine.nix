# merges per-device resource sets into one terraform root: prefixes every
# resource name with the device (avoiding cross-device collisions), rewrites
# internal "${type.name.attr}" references to match, and pins each resource to
# its device's provider alias. the per-device modules stay device-oblivious.
{ lib }:
dev: resources:
let
  rewrite =
    v:
    if builtins.isString v then
      let
        m = builtins.match "[$][{]([a-z0-9_]+)[.]([A-Za-z0-9_]+)[.]([a-z_.]+)[}]" v;
      in
      if m == null then
        v
      else
        "\${${builtins.elemAt m 0}.${dev}_${builtins.elemAt m 1}.${builtins.elemAt m 2}}"
    else if builtins.isList v then
      map rewrite v
    else
      v;
in
lib.mapAttrs (
  type: entries:
  lib.mapAttrs' (
    n: entry:
    lib.nameValuePair "${dev}_${n}" (
      (lib.mapAttrs (_: rewrite) entry) // { provider = "routeros.${dev}"; }
    )
  ) entries
) resources
