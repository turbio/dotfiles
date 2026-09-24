let
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

  # policy selector dsl: expose.to / allow entries are structured objects
  # built by these constructors, never parsed strings. the _class tag lets
  # the policy engine (modules/vm-host.nix) reject anything else with a
  # clear error.
  #   network "lan"              a whole trust tier (lan / mgmt / tailscale)
  #   vm "loki"                  another vm, by name
  #   machine "ballos" [ 9090 ]  a physical machine's ports ([ ] = all).
  #                              resolved relative to where the vm lives:
  #                              input rules when hosted on that machine,
  #                              forward rules when not — so moving a vm
  #                              never breaks its grants
  #   cidr "192.168.50.0/24"     a raw range
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

  # where vm artifacts live: <pool>/<vmsDataset>/<vm-name>/{var,...}.
  # datasetPath resolves a pool-relative dataset to its mountpoint on the
  # pool-owning host (default zfs layout); this is the single seam where
  # network transparency plugs in later — a remote hypervisor resolves the
  # same dataset to its nfs mountpoint instead (PLAN.md §7/M6)
  storage = rec {
    pool = "tank";
    datasetPath = ds: "/${pool}/${ds}";
    vmsDataset = "enc/vms";
    vmsPath = datasetPath vmsDataset;
  };

  net = {
    ula = "fd53:d7e:fb6d::/48";

    lan = {
      cidr4 = "192.168.88.0/24";
      ula = "fd53:d7e:fb6d:88::/64";
      ulaPrefix = "fd53:d7e:fb6d:88::";
      gateway4 = "192.168.88.1";
    };

    mgmt = {
      cidr4 = "192.168.89.0/24";
      ula = "fd53:d7e:fb6d:89::/64";
      ulaPrefix = "fd53:d7e:fb6d:89::";
    };

    vm = {
      cidr4 = "10.42.0.0/16";
      ula = "fd53:d7e:fb6d:42::/64";
      ulaPrefix = "fd53:d7e:fb6d:42::";
      # on-link anycast gateway, identical on every hypervisor
      gateway4 = "10.42.0.1";
    };

    tailscale = "100.64.0.0/10";
    # tailscale's fleet-wide v6 ULA prefix (every tailnet uses this range)
    tailscale6 = "fd7a:115c:a1e0::/48";
  };

  machines = {
    ballos = {
      lan.ip4 = "192.168.88.242";
      lan.mac = "02:a8:22:41:26:a8"; # bond0
      # eno1 backup nic
      lan.extra.aux = {
        ip4 = "192.168.88.142";
        mac = "18:66:da:9d:a3:c9";
      };
      # idrac (dhcp; pinned at the address it already held)
      lan.extra.mgmt = {
        ip4 = "192.168.88.248";
        mac = "18:66:da:9d:a3:cd";
      };
      tailscale.ip4 = "100.100.57.46";
      tailscale.ip6 = "fd7a:115c:a1e0::2233:392e";
      hypervisor = true;
      # public-name services on this machine that internal clients should
      # reach directly instead of detouring via the cloud edges — int-dns
      # emits <alias>.int.turb.io -> this machine's lan address (the
      # *.int.turb.io cert SAN covers the vhost alias)
      dnsAliases = [ "nixcache" ];
    };
    joast = {
      # live-verified: bond0 = .227, eno1 = .230 (the .235/.240 arp entries
      # were stale pxe-phase leases). bond mac is pinned to eno5np0's
      # hardware mac in hosts/joast so pxe and os share one dhcp identity;
      # takes effect on joast's next netboot
      lan.ip4 = "192.168.88.227";
      lan.mac = "b8:83:03:8a:10:ac"; # bond (pinned)
      lan.extra.aux = {
        ip4 = "192.168.88.230";
        mac = "54:80:28:54:ac:f8"; # eno1
      };
    };
    # .64-.199 static block (PLAN.md §1); addresses assigned here, hosts pick
    # them up on next dhcp renew/netboot. every simultaneously-active nic
    # gets its own address and dns name: primary -> <host>.lan, extras ->
    # <label>.<host>.lan (aux = backup nic at primary+100, mgmt = bmc).
    # TODO: zote/j2/joast bmc macs unknown — discover via `ipmitool lan
    # print` when each host is up and add lan.extra.mgmt entries
    j2 = {
      lan.ip4 = "192.168.88.82";
      lan.mac = "b8:83:03:7f:01:54"; # bond
      lan.extra.mgmt = {
        ip4 = "192.168.88.182";
        mac = "94:40:c9:f2:36:74";
      };
    };
    zote = {
      lan.ip4 = "192.168.88.81";
      lan.mac = "70:10:6f:aa:cd:d0";
    };
    mote = {
      lan.ip4 = "192.168.88.80";
      lan.mac = "30:9c:23:9d:83:ec";
      lan.extra.aux = {
        ip4 = "192.168.88.180";
        mac = "98:b7:85:23:b6:4d";
      };
    };
    star = { };
    curly = { };
    gero = { };
    itoh = { };
    tivni = { };

    # cloud edges
    aackle = {
      public.ip4 = "35.209.100.97";
      public.ip6 = "2600:1900:4000:e9d7::";
      tailscale.ip4 = "100.64.177.49";
    };
    backle = {
      public.ip4 = "146.235.204.90";
      public.ip6 = "2603:c024:c018:6b00:0:8870:dbc4:5495";
      tailscale.ip4 = "100.64.52.73";
    };
    cackle = {
      public.ip4 = "163.192.60.165";
      public.ip6 = "2603:c024:c018:6b00:0:54b7:d0b:9783";
      tailscale.ip4 = "100.64.144.3";
    };
    jenka = { };
    spooky = { };
    balrog = { };
  };

  appliances = {
    ccr2004 = {
      lan.ip4 = "192.168.88.1";
    };
    crs326 = {
      lan.ip4 = "192.168.88.245";
    };
    crs305 = {
      # lives on the wan side of the ccr
      wan.ip4 = "192.168.1.69";
    };
    raritan-pdu-112.lan.ip4 = "192.168.88.246";
    raritan-pdu-113.lan.ip4 = "192.168.88.247";
  };

  # vms are added here as services get vmized (PLAN.md M2 onwards):
  #   <name> = { host = "<machine>"; };
  # optional: addressSalt (collision escape hatch), vcpu/mem, persistVar
  # (the vm's /var lives on a tank dataset), mounts."<guestPath>".dataset
  # (pool-relative dataset shared into the guest — referenced, not owned:
  # it outlives the vm); secrets (age secret names the hypervisor decrypts
  # and delivers read-only at /run/host-secrets/<name> — guests hold no
  # keys); policy: expose (ports in, with a `to` selector list defaulting
  # to lan+tailscale), allow (selector list out), egress (internet bool) —
  # selectors built with the dsl above
  vms = {
    flippyflops = {
      host = "ballos";
      expose = [
        {
          port = 3001;
          to = [
            (network "lan")
            (network "tailscale")
            (vm "prometheus")
          ];
        }
      ];
    };
    evaldb = {
      host = "ballos";
      persistVar = true;
      expose = [ { port = 3005; } ];
    };
    vibes = {
      host = "ballos";
      expose = [ { port = 3010; } ];
      mounts."/media".dataset = "enc/vibes";
    };
    pushgateway = {
      host = "ballos";
      expose = [
        {
          port = 9091;
          to = [
            (network "lan")
            (network "tailscale")
            (vm "prometheus")
          ];
        }
      ];
    };
    pingexp = {
      host = "ballos";
      expose = [
        {
          port = 9427;
          to = [
            (network "lan")
            (network "tailscale")
            (vm "prometheus")
          ];
        }
      ];
      egress = true;
      # the wan-probe aliases (192.168.100-102.x, dst-natted at the ccr) are
      # rfc1918 so plain egress doesn't cover them
      allow = [ (cidr "192.168.100.0/22") ];
    };
    loki = {
      host = "ballos";
      persistVar = true;
      expose = [
        {
          port = 3100;
          to = [
            (network "lan")
            (network "tailscale")
            (vm "grafana")
          ];
        }
      ];
      # log volume is modest; virtiofs measured ~2 orders of magnitude
      # above loki's needs (bench 2026-07-28) — no blk volume required
      mem = 1024;
    };
    snmpexp = {
      host = "ballos";
      expose = [
        {
          port = 9116;
          to = [
            (network "lan")
            (network "tailscale")
            (vm "prometheus")
          ];
        }
      ];
      # snmp targets: ccr/switches on the lan, the pepwave-side gear on
      # 192.168.50.x
      allow = [
        (network "lan")
        (cidr "192.168.50.0/24")
      ];
    };
    prometheus = {
      host = "ballos";
      persistVar = true;
      expose = [
        {
          port = 9090;
          to = [
            (network "lan")
            (network "tailscale")
            (vm "grafana")
          ];
        }
      ];
      # the scrape graph: machines on the lan, edges over tailscale, sibling
      # vms, and the ballos exporters that must stay on metal for hardware
      # access (ports are the exporters' nixpkgs defaults, node is pinned
      # to 9092 in hosts/ballos)
      allow = [
        (network "lan")
        (network "tailscale")
        (vm "flippyflops")
        (vm "pushgateway")
        (vm "pingexp")
        (vm "snmpexp")
        (machine "ballos" [
          9092 # node
          9113 # nginx
          9117 # nginxlog
          9134 # zfs
          9199 # nut
          9256 # process
          9427 # ping
          9586 # wireguard
          9633 # smartctl
        ])
      ];
      mem = 3072;
    };
    forgejo = {
      host = "ballos";
      persistVar = true;
      expose = [
        { port = 3300; } # http, behind the forge.turb.io vhost on ballos
        { port = 2222; } # built-in ssh; edges dnat public :22 here
      ];
      # webhook deliveries (ci.turb.io resolves to the public edges), repo
      # mirrors, avatars — the host instance always had open egress
      egress = true;
      # git repack of big mirrors (nixpkgs) peaked the host instance at 6G
      mem = 8192;
    };
    buildbot = {
      host = "ballos";
      persistVar = true;
      expose = [
        { port = 80; } # module-managed nginx; ballos's ci.turb.io proxies here
        { port = 9989; } # worker protocol (ballos-metal worker dials in)
      ];
      # reaches forgejo at its public name (via the edges) for oauth/api,
      # and fetches sources/substitutes for in-vm builds
      egress = true;
      # nixcache.int.turb.io — the local binary cache at ballos's lan
      # address (input path)
      allow = [ (machine "ballos" [ 443 ]) ];
      secrets = [
        "forgejo-oauth-secret"
        "forgejo-webhook-secret"
        # buildbot's forgejo api token — created via `agenix -e
        # forgejo-api-token.age` (eval asserts it exists)
        "forgejo-api-token"
      ];
      # master + worker + in-vm nix builds. eval of this very repo is the
      # heavy part: ballos's toplevel embeds every vm's nixos system (and
      # the flake evals every host again as a netboot variant) — 32G still
      # oomed. generous ceiling is cheap: the vm balloons freed pages back
      # to the host (vms/buildbot sets microvm.balloon). ballos has 28c/56t;
      # vcpus aren't reserved, so the ci vm gets a big slice
      vcpu = 32;
      mem = 131072;
    };
    akvorado = {
      host = "ballos";
      persistVar = true;
      expose = [
        # flow ingest from the ccr (dual-exported during stage-1)
        {
          port = 2055;
          proto = "udp";
        }
        {
          port = 4739;
          proto = "udp";
        }
        {
          port = 6343;
          proto = "udp";
        }
        # console; ballos's flowtest vhost injects the auth headers
        { port = 8080; }
      ];
      # snmp metadata queries to the ccr/switches
      allow = [ (network "lan") ];
      # container image pulls (quay/docker.io) + ipinfo geoip downloads
      egress = true;
      secrets = [ "ipinfo-token" ];
      # clickhouse is the hungry one
      vcpu = 8;
      mem = 8192;
    };
    immich = {
      host = "ballos";
      persistVar = true;
      expose = [ { port = 80; } ];
      # ml model downloads (huggingface), reverse-geocoding data, version
      # checks
      egress = true;
      # server peaked 835M + ml 171M on the host; models and transcodes
      # want headroom
      vcpu = 8;
      mem = 6144;
    };
    cgit = {
      host = "ballos";
      # stateless: reads the git dataset, serves http; no persistVar
      expose = [ { port = 80; } ];
      mounts."/git" = {
        dataset = "enc/git";
        readOnly = true;
      };
    };
    grafana = {
      host = "ballos";
      persistVar = true;
      expose = [ { port = 3000; } ];
      # loki lives in a vm; the default prometheus datasource is (for now)
      # the host service on ballos, with the prometheus vm as a
      # side-by-side test datasource until its cutover
      allow = [
        (vm "loki")
        (vm "prometheus")
        (machine "ballos" [ 9090 ])
      ];
      mem = 1024;
    };
  };

  withAddrs = builtins.mapAttrs (name: cfg: cfg // { addr = vmAddrs (hashKey name cfg); }) vms;

  checks =
    let
      entries = builtins.attrValues (
        builtins.mapAttrs (name: cfg: {
          inherit name;
          h = (withAddrs.${name}).addr.hash;
        }) vms
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
    in
    reserved ++ collisions;
in
{
  inherit
    net
    machines
    appliances
    storage
    ;

  vms = builtins.deepSeq checks withAddrs;

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
