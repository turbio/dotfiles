{ pkgs, terranix }:
let
  inherit (pkgs) lib;
  system = pkgs.stdenv.hostPlatform.system;

  names = [
    "ccr2004"
    "crs326"
    "crs305"
  ];

  device = d: (import (./. + "/${d}.nix") { inherit lib; }).resource;

  combine =
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
    ) resources;

  config = terranix.lib.terranixConfiguration {
    inherit system;
    modules = [
      ./common.nix
      {
        resource = names |> map (d: combine d (device d)) |> lib.foldl' lib.recursiveUpdate { };
      }
    ];
  };

  rsc = d: pkgs.writeText "${d}.rsc" (import ./render-rsc.nix { inherit lib; } (device d));

  routeros = pkgs.terraform-providers.terraform-routeros_routeros.overrideAttrs (old: {
    postPatch = (old.postPatch or "") + ''
      for f in routeros/resource_ip_route.go routeros/resource_ipv6_route.go; do
        substituteInPlace "$f" --replace-fail \
          'MetaId:           PropId(Id),' \
          'MetaId:             PropId(Id),
           MetaSetUnsetFields: PropSetUnsetFields("blackhole"),'
      done
    '';
  });

  tofu = pkgs.opentofu.withPlugins (_: [ routeros ]);

  validate = pkgs.runCommand "appliances-validate" { nativeBuildInputs = [ tofu ]; } ''
    mkdir -p $TMPDIR/root
    cp ${config} $TMPDIR/root/config.tf.json
    (cd $TMPDIR/root && tofu init -backend=false -input=false >/dev/null && tofu validate)
    touch $out
  '';

  app = {
    type = "app";
    program = toString (
      pkgs.writeShellScript "appliance" ''
        set -euo pipefail
        dir="$(${pkgs.git}/bin/git rev-parse --show-toplevel)/appliances/root"
        mkdir -p "$dir"
        install -m 644 ${config} "$dir/config.tf.json"
        cd "$dir"
        exec ${tofu}/bin/tofu "$@"
      ''
    );
  };

  packages = {
    appliance-config = config;
  }
  // (
    names
    |> map (d: {
      name = "appliance-${d}-rsc";
      value = rsc d;
    })
    |> builtins.listToAttrs
  );
in
{
  inherit
    names
    config
    tofu
    validate
    rsc
    app
    packages
    ;
}
