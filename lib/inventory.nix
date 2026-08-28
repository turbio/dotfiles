# Everything derived from inventory.nix. The inventory itself is data only —
# no functions, no function application — so all the machinery lives here:
# vm address hashing, the uniqueness/reserved-range checks, storage path
# helpers, and normalization of the policy selectors written as plain
# attrsets in the data.
#
# `import ./lib/inventory.nix` returns the finished inventory: the raw data
# plus `vms.<name>.addr`, `storage.datasetPath`/`vmsPath`, and normalized
# `expose`/`allow` selectors. Consumers should always go through here, never
# import inventory.nix directly.
let
  data = import ../inventory.nix;

  inherit (data) net machines appliances;

  hexVal = {
    "0" = 0;
    "1" = 1;
    "2" = 2;
    "3" = 3;
    "4" = 4;
    "5" = 5;
    "6" = 6;
    "7" = 7;
    "8" = 8;
    "9" = 9;
    "a" = 10;
    "b" = 11;
    "c" = 12;
    "d" = 13;
    "e" = 14;
    "f" = 15;
  };

  chars = s: builtins.genList (i: builtins.substring i 1 s) (builtins.stringLength s);
  hexToInt = s: builtins.foldl' (a: c: a * 16 + hexVal.${c}) 0 (chars s);

  hashHex = name: builtins.substring 0 4 (builtins.hashString "sha256" name);
  hash16 = name: hexToInt (hashHex name);

  # what actually gets hashed: the name, or name~salt when a collision forced
  # a salt
  hashKey =
    name: cfg: if (cfg.addressSalt or 0) == 0 then name else "${name}~${toString cfg.addressSalt}";

  vmAddrs =
    key:
    let
      h = hash16 key;
      hex = hashHex key;
      full = builtins.hashString "sha256" key;
      b = i: builtins.substring i 2 full;
    in
    {
      hash = h;
      ip4 = "10.42.${toString (h / 256)}.${toString (h - (h / 256) * 256)}";
      ip6 = "${net.vm.ulaPrefix}${hex}";
      mac = "02:42:${b 0}:${b 2}:${b 4}:${b 6}";
    };

  storage = data.storage // {
    datasetPath = ds: "/${data.storage.pool}/${ds}";
    vmsPath = "/${data.storage.pool}/${data.storage.vmsDataset}";
  };

  # policy selector dsl. inventory.nix writes selectors as single-key
  # attrsets ({ network = "lan"; }, { machine = "joast"; ports = [ 443 ]; });
  # this turns them into the tagged objects the policy engine
  # (modules/vm-host.nix) consumes, and rejects anything malformed with a
  # clear error. the constructors are exported too, for module code that
  # needs to build a selector (e.g. vm-host's default `to`).
  selector =
    kind: attrs:
    {
      _class = "policy-selector";
      inherit kind;
    }
    // attrs;
  network = name: selector "network" { inherit name; };
  vm = name: selector "vm" { inherit name; };
  machine = name: ports: selector "machine" { inherit name ports; };
  cidr = range: selector "cidr" { inherit range; };

  selectorKinds = [
    "network"
    "vm"
    "machine"
    "cidr"
  ];

  toSelector =
    ctx: s:
    let
      keys = builtins.attrNames s;
      tags = builtins.filter (k: builtins.elem k selectorKinds) keys;
      extra = builtins.filter (k: !(builtins.elem k (selectorKinds ++ [ "ports" ]))) keys;
      kind = builtins.head tags;
      shape = "one of ${builtins.concatStringsSep ", " (map (k: "{ ${k} = \"…\"; }") selectorKinds)}";
    in
    if !(builtins.isAttrs s) then
      throw "inventory: ${ctx}: policy entry must be an attrset (${shape}), got a ${builtins.typeOf s}"
    else if builtins.length tags != 1 then
      throw "inventory: ${ctx}: policy entry must name exactly ${shape}, got { ${builtins.concatStringsSep " " keys} }"
    else if extra != [ ] then
      throw "inventory: ${ctx}: unknown key(s) in policy entry: ${builtins.concatStringsSep ", " extra}"
    else if kind == "cidr" then
      cidr s.cidr
    else if kind == "machine" then
      machine s.machine (s.ports or [ ])
    else
      selector kind { name = s.${kind}; };

  # data → derived: hashed addresses plus normalized policy selectors
  normalizeVm =
    name: cfg:
    cfg
    // {
      addr = vmAddrs (hashKey name cfg);
    }
    // (
      if cfg ? expose then
        {
          expose = map (
            e:
            if e ? to then
              e // { to = map (toSelector "vm '${name}' expose ${toString e.port} to") e.to; }
            else
              e
          ) cfg.expose;
        }
      else
        { }
    )
    // (if cfg ? allow then { allow = map (toSelector "vm '${name}' allow") cfg.allow; } else { });

  normalized = builtins.mapAttrs normalizeVm data.vms;

  checks =
    let
      entries = builtins.attrValues (
        builtins.mapAttrs (name: cfg: {
          inherit name;
          h = (normalized.${name}).addr.hash;
        }) data.vms
      );
      reserved = map (
        e:
        if e.h < 256 || e.h == 65535 then
          throw "inventory: vm '${e.name}' hashes into a reserved range (${toString e.h}), set addressSalt"
        else
          null
      ) entries;
      grouped = builtins.groupBy (e: toString e.h) entries;
      dups = builtins.attrValues grouped |> builtins.filter (g: builtins.length g > 1);
      collisions = map (
        g:
        throw "inventory: vm address hash collision between: ${
          builtins.concatStringsSep ", " (map (e: e.name) g)
        }; set addressSalt on one"
      ) dups;
      # selectors written as raw data can't fail at construction the way the
      # old constructor calls did, so force every one of them up front
      selectors = builtins.concatMap (
        v: (builtins.concatMap (e: e.to or [ ]) (v.expose or [ ])) ++ (v.allow or [ ])
      ) (builtins.attrValues normalized);
    in
    reserved ++ collisions ++ selectors;
in
{
  inherit
    net
    machines
    appliances
    storage
    ;

  vms = builtins.deepSeq checks normalized;

  lib = {
    inherit
      hash16
      vmAddrs
      network
      vm
      machine
      cidr
      ;
  };
}
