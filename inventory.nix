{
  storage = {
    pool = "tank";
    vmsDataset = "enc/vms";
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
      gateway4 = "10.42.0.1";
    };

    tailscale = "100.64.0.0/10";
    tailscale6 = "fd7a:115c:a1e0::/48";

    # per-wan probe nets: the ccr dst-nats these fake addresses out one
    # specific wan (appliances/ccr2004.nix), so pinging them from inside
    # measures that wan's health. cf lands on 1.1.1.1, goog on 8.8.8.8. the
    # ping exporters (vms/pingexp, hosts) probe every one.
    wanProbes = {
      wan1 = {
        probeNet = "192.168.100.0/24";
        probes = {
          cf = "192.168.100.1";
          goog = "192.168.100.2";
        };
      };
      wan2 = {
        probeNet = "192.168.101.0/24";
        probes = {
          cf = "192.168.101.1";
          goog = "192.168.101.2";
        };
      };
      wan3 = {
        probeNet = "192.168.102.0/24";
        probes = {
          cf = "192.168.102.1";
          goog = "192.168.102.2";
        };
      };
    };
  };

  machines = {
    ballos = {
      arch = "x86_64-linux";
      secrets = [
        "userpassword"
        "rfc2136-acme"
        "nix-builders-ssh-key"
      ];
      lan.ip4 = "192.168.88.242";
      lan.mac = "02:a8:22:41:26:a8"; # bond0
      lan.extra.aux = {
        ip4 = "192.168.88.142";
        mac = "18:66:da:9d:a3:c9";
      };
      lan.extra.mgmt = {
        ip4 = "192.168.88.248"; # idrac
        mac = "18:66:da:9d:a3:cd";
      };
      tailscale.ip4 = "100.100.57.47";
      tailscale.ip6 = "fd7a:115c:a1e0::2233:392e";
      hypervisor = true;
    };

    joast = {
      arch = "x86_64-linux";

      secrets = [
        "userpassword"
        "rfc2136-acme"
        "forgejo-oauth-secret"
        "forgejo-webhook-secret"
        "forgejo-admin-password"
        "nix-builders-ssh-key"
        "nixcache-key"
      ];

      lan.ip4 = "192.168.88.227";
      lan.mac = "b8:83:03:8a:10:ac";
      lan.extra.aux = {
        ip4 = "192.168.88.230";
        mac = "54:80:28:54:ac:f8";
      };
      lan.extra.mgmt = {
        ip4 = "192.168.88.244";
        mac = "54:80:28:54:AC:F6";
      };
      tailscale.ip4 = "100.100.57.46";
      tailscale.ip6 = "fd7a:115c:a1e0::37:621b";
      dnsAliases = [ "nixcache" ];
      hypervisor = true;
    };

    j2 = {
      arch = "x86_64-linux";
      lan.ip4 = "192.168.88.82";
      lan.mac = "b8:83:03:7f:01:54"; # bond
      lan.extra.mgmt = {
        ip4 = "192.168.88.182";
        mac = "94:40:c9:f2:36:74";
      };
    };
    zote = {
      arch = "x86_64-linux";
      lan.ip4 = "192.168.88.81";
      lan.mac = "70:10:6f:aa:cd:d0";
    };
    star = {
      arch = "x86_64-linux";
      secrets = [ "userpassword" ];
    };
    curly = {
      arch = "x86_64-linux";

      modules = [
        ./vim.nix
        ./modules/gixypatch.nix
      ];

      secrets = [ "userpassword" ];

      tailscale.ip4 = "100.100.109.112";
    };
    itoh = {
      arch = "x86_64-linux";
      secrets = [ "userpassword" ];
    };
    tivni = {
      arch = "x86_64-linux";
      secrets = [ "userpassword" ];
    };

    # cloud edges
    aackle = {
      arch = "x86_64-linux";
      secrets = [
        "userpassword"
        "rfc2136-acme"
        "rfc2136-xfer"
      ];

      public.ip4 = "35.209.100.97";
      public.ip6 = "2600:1900:4000:e9d7::";
      tailscale.ip4 = "100.64.177.49";

    };
    backle = {
      arch = "aarch64-linux";
      secrets = [
        "userpassword"
        "rfc2136-acme"
        "rfc2136-xfer"
      ];
      public.ip4 = "146.235.204.90";
      public.ip6 = "2603:c024:c018:6b00:0:8870:dbc4:5495";
      tailscale.ip4 = "100.64.52.73";
    };
    cackle = {
      arch = "aarch64-linux";
      secrets = [ "userpassword" ];
      public.ip4 = "163.192.60.165";
      public.ip6 = "2603:c024:c018:6b00:0:54b7:d0b:9783";
      tailscale.ip4 = "100.64.144.3";
    };
    jenka = {
      arch = "aarch64-linux";
      secrets = [ "userpassword" ];
    };
    spooky = {
      arch = "x86_64-linux";
      secrets = [ "userpassword" ];
    };
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

  vms = {
    flippyflops = {
      host = "joast";
      expose = [
        {
          port = 3001;
          to = [
            { network = "lan"; }
            { network = "tailscale"; }
            { vm = "prometheus"; }
          ];
        }
      ];
    };
    evaldb = {
      host = "joast";
      persistVar = true;
      expose = [ { port = 3005; } ];
    };
    vibes = {
      host = "joast";
      expose = [ { port = 80; } ];
      mounts."/media".dataset = "enc/vibes";
    };
    pushgateway = {
      host = "joast";
      expose = [
        {
          port = 9091;
          to = [
            { network = "lan"; }
            { network = "tailscale"; }
            { vm = "prometheus"; }
          ];
        }
      ];
    };
    pingexp = {
      host = "joast";
      expose = [
        {
          port = 9427;
          to = [
            { network = "lan"; }
            { network = "tailscale"; }
            { vm = "prometheus"; }
          ];
        }
      ];
      egress = true;
      # the wan-probe aliases (192.168.100-102.x, dst-natted at the ccr) are
      # rfc1918 so plain egress doesn't cover them
      allow = [ { cidr = "192.168.100.0/22"; } ];
    };
    loki = {
      host = "joast";
      persistVar = true;
      expose = [
        {
          port = 3100;
          to = [
            { network = "lan"; }
            { network = "tailscale"; }
            { vm = "grafana"; }
          ];
        }
      ];
      # log volume is modest; virtiofs measured ~2 orders of magnitude
      # above loki's needs (bench 2026-07-28) — no blk volume required
      mem = 1024;
    };
    snmpexp = {
      host = "joast";
      expose = [
        {
          port = 9116;
          to = [
            { network = "lan"; }
            { network = "tailscale"; }
            { vm = "prometheus"; }
          ];
        }
      ];
      # snmp targets: ccr/switches on the lan, the pepwave-side gear on
      # 192.168.50.x
      allow = [
        { network = "lan"; }
        { cidr = "192.168.50.0/24"; }
        { cidr = "192.168.1.0/24"; }
      ];
    };
    prometheus = {
      host = "joast";
      persistVar = true;
      expose = [
        {
          port = 9090;
          to = [
            { network = "lan"; }
            { network = "tailscale"; }
            { vm = "grafana"; }
          ];
        }
      ];
      allow = [
        { network = "lan"; }
        { network = "tailscale"; }
        { vm = "flippyflops"; }
        { vm = "pushgateway"; }
        { vm = "pingexp"; }
        { vm = "snmpexp"; }
        {
          machine = "joast";
          ports = [
            9100 # node
            9092 # also node????
            9113 # nginx
            9117 # nginxlog
            9134 # zfs
            9199 # nut
            9256 # process
            9427 # ping
            9586 # wireguard
            9633 # smartctl
            9290 # ipmi
          ];
        }
      ];
      mem = 3072;
    };
    forgejo = {
      host = "joast";
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
      host = "joast";
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
      allow = [
        {
          machine = "joast";
          ports = [ 443 ];
        }
      ];
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
      host = "joast";
      persistVar = true;
      expose = [
        {
          port = 2055;
          proto = "udp";
          # the crs305 (wan side) exports flows from 192.168.1.69; the ccr
          # dst-nats them here with the original source intact
          to = [
            { network = "lan"; }
            { network = "tailscale"; }
            { cidr = "192.168.1.0/24"; }
          ];
        }
        {
          port = 4739;
          proto = "udp";
        }
        {
          port = 6343;
          proto = "udp";
        }
        { port = 8080; }
      ];
      # 192.168.1.0/24: snmp metadata polls of the wan-side crs305 exporter
      # (rfc1918, so plain egress doesn't cover it)
      allow = [
        { network = "lan"; }
        { cidr = "192.168.1.0/24"; }
      ];
      egress = true;
      secrets = [ "ipinfo-token" ];
      vcpu = 8;
      mem = 8192;
    };
    immich = {
      host = "joast";
      persistVar = true;
      expose = [ { port = 80; } ];
      egress = true;
      vcpu = 8;
      mem = 6144;
    };
    cgit = {
      host = "joast";
      # stateless: reads the git dataset, serves http; no persistVar
      expose = [ { port = 80; } ];
      mounts."/git" = {
        dataset = "enc/git";
        readOnly = true;
      };
    };
    radicle = {
      host = "joast";
      persistVar = true;
      expose = [
        { port = 8776; } # p2p; edges dnat public :8776 here
        { port = 80; } # explorer + httpd api, behind the radicle.turb.io vhost
      ];
      # gossip/fetch with the public radicle seeds
      egress = true;
      secrets = [ "radicle-key" ];
      vcpu = 2;
      # not 2048: qemu hangs at exactly 2G (microvm.nix#171)
      mem = 1536;
    };
    grafana = {
      host = "joast";
      persistVar = true;
      expose = [ { port = 3000; } ];
      # loki lives in a vm; the default prometheus datasource is (for now)
      # the host service on ballos, with the prometheus vm as a
      # side-by-side test datasource until its cutover
      allow = [
        { vm = "loki"; }
        { vm = "prometheus"; }
        {
          machine = "joast";
          ports = [ 9090 ];
        }
      ];
      mem = 1024;
    };
    syncthing = {
      host = "joast";
      persistVar = true;
      expose = [
        { port = 22000; }
        {
          port = 22000;
          proto = "udp";
        }
        { port = 80; }
      ];
      allow = [ { network = "tailscale"; } ];
      mounts = {
        "/tank/enc/misc".dataset = "enc/misc";
        "/tank/enc/photos".dataset = "enc/photos";
        "/tank/enc/code".dataset = "enc/code";
        "/tank/enc/webcamlog".dataset = "enc/webcamlog";
      };
      secrets = [
        "syncthing-cert"
        "syncthing-key"
        "syncthing-gui-password"
      ];
      vcpu = 4;
      mem = 3072;
    };
  };
}
