# Turns a physical host into a vm hypervisor: routed per-vm taps, the
# nftables policy engine, routes to vms living on other hosts, and the
# tailscale subnet advertisement. All generated from inventory (PLAN.md §2/§5).
#
# Every vm gets its own tap (no shared L2). The tap carries the anycast
# gateway 10.42.0.1/32 + fe80::1, the host holds /32 + /128 routes to the
# guest, and everything crossing a "vm-*" interface goes through the vmpolicy
# table: default deny both directions, trusted tiers in, declared
# expose/allow/egress out.
{
  config,
  lib,
  inventory,
  assignments,
  repos,
  hostname,
  microvm,
  ...
}:
let
  cfg = config.vmhost;
  inv = inventory;

  myVms = lib.filterAttrs (n: v: v.host == hostname) inv.vms;
  statefulVms = lib.filterAttrs (n: v: v.persistVar or false) myVms;

  # datasets referenced by vm mounts; they need virtiofs-required properties
  mountDatasets = lib.foldl' lib.recursiveUpdate { } (
    lib.mapAttrsToList (
      _: vm:
      lib.mapAttrs' (
        _: m:
        lib.nameValuePair m.dataset {
          properties = {
            acltype = "posixacl";
            xattr = "sa";
          };
        }
      ) (vm.mounts or { })
    ) myVms
  );
  tapOf = name: "vm-${name}";

  # policy entries are structured selector objects from inventory's dsl
  # (inventory.lib.{network,vm,machine,cidr}); anything else — including
  # the old string forms — is rejected at eval
  checkSel =
    s:
    if (s._class or null) == "policy-selector" then
      s
    else
      throw "vmhost: policy entry must be a selector built with inventory.lib.{network,vm,machine,cidr}, got a ${builtins.typeOf s}";

  allowsOf = vm: map checkSel (vm.allow or [ ]);
  # machine selectors resolve relative to where the vm lives: grants
  # targeting *this* host are input-path (below), everything else rides the
  # forward path
  machineAllows = vm: lib.filter (s: s.kind == "machine") (allowsOf vm);
  plainAllows = vm: lib.filter (s: s.kind != "machine") (allowsOf vm);

  cidr4Of =
    sRaw:
    let
      s = checkSel sRaw;
    in
    if s.kind == "network" then
      [ (if s.name == "tailscale" then inv.net.tailscale else inv.net.${s.name}.cidr4) ]
    else if s.kind == "vm" then
      [ "${inv.vms.${s.name}.addr.ip4}/32" ]
    else if s.kind == "machine" then
      [ "${inv.machines.${s.name}.lan.ip4}/32" ]
    else if s.kind == "cidr" then
      [ s.range ]
    else
      throw "vmhost: unknown selector kind '${s.kind}'";

  # v6 twin of cidr4Of; may resolve to nothing (machine lan addrs and cidr
  # literals are v4-only today), callers emit no ip6 rule then
  cidr6Of =
    sRaw:
    let
      s = checkSel sRaw;
    in
    if s.kind == "network" then
      [
        (if s.name == "tailscale" then inv.net.tailscale6 else inv.net.${s.name}.ula)
      ]
    else if s.kind == "vm" then
      [ "${inv.vms.${s.name}.addr.ip6}/128" ]
    else
      [ ];

  portClause =
    ports:
    lib.optionalString (ports != [ ]) "tcp dport { ${lib.concatMapStringsSep ", " toString ports} } ";

  cidrSet = selectors: "{ ${lib.concatStringsSep ", " (lib.concatMap cidr4Of selectors)} }";
  cidr6List = selectors: lib.concatMap cidr6Of selectors;
  cidr6Set = selectors: "{ ${lib.concatStringsSep ", " (cidr6List selectors)} }";

  # everything that isn't ours; "internet" egress means not-these
  internalRanges4 = "{ 10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16, 100.64.0.0/10 }";

  ingressRules = lib.concatStrings (
    lib.mapAttrsToList (
      name: vm:
      lib.concatMapStrings (
        e:
        let
          proto = e.proto or "tcp";
          to =
            e.to or [
              (inv.lib.network "lan")
              (inv.lib.network "tailscale")
            ];
        in
        "    oifname \"${tapOf name}\" ip saddr ${cidrSet to} ${proto} dport ${toString e.port} accept\n"
        +
          lib.optionalString (cidr6List to != [ ])
            "    oifname \"${tapOf name}\" ip6 saddr ${cidr6Set to} ${proto} dport ${toString e.port} accept\n"
      ) (vm.expose or [ ])
    ) myVms
  );

  egressRules = lib.concatStrings (
    lib.mapAttrsToList (
      name: vm:
      let
        tap = tapOf name;
        antispoof = ''
          iifname "${tap}" ip saddr != ${vm.addr.ip4} drop
          iifname "${tap}" ip6 saddr != { ${vm.addr.ip6}, fe80::/10 } drop
        '';
        allows =
          lib.concatMapStrings (
            s:
            "    iifname \"${tap}\" ip daddr ${cidrSet [ s ]} accept\n"
            + lib.optionalString (
              cidr6List [ s ] != [ ]
            ) "    iifname \"${tap}\" ip6 daddr ${cidr6Set [ s ]} accept\n"
          ) (plainAllows vm)
          # machine grants on the forward path (vm hosted elsewhere than the
          # target machine; harmless no-op when local, where traffic takes
          # the input path instead)
          + lib.concatMapStrings (
            s: "    iifname \"${tap}\" ip daddr ${inv.machines.${s.name}.lan.ip4} ${portClause s.ports}accept\n"
          ) (machineAllows vm);
        internet = lib.optionalString (vm.egress or false) ''
          iifname "${tap}" ip daddr != ${internalRanges4} accept
          iifname "${tap}" ip6 daddr != { fc00::/7, fe80::/10 } accept
        '';
      in
      antispoof + allows + internet
    ) myVms
  );

  perVmNetworks = lib.mapAttrs' (
    name: vm:
    lib.nameValuePair "40-${tapOf name}" {
      matchConfig.Name = tapOf name;
      address = [
        "${inv.net.vm.gateway4}/32"
        "fe80::1/64"
      ];
      routes = [
        { Destination = "${vm.addr.ip4}/32"; }
        { Destination = "${vm.addr.ip6}/128"; }
      ];
      networkConfig = {
        IPv4Forwarding = true;
        IPv6Forwarding = true;
        # taps have no carrier until the vm process attaches
        ConfigureWithoutCarrier = true;
      };
      linkConfig.RequiredForOnline = "no";
    }
  ) myVms;
in
{
  imports = [
    microvm.nixosModules.host
    ./zfs-datasets.nix
  ];

  options.vmhost = {
    enable = lib.mkEnableOption "vm hypervisor fabric";
  };

  config = lib.mkMerge [
    # the microvm host module defaults itself on; only hypervisors get it
    { microvm.host.enable = lib.mkDefault false; }

    (lib.mkIf cfg.enable {
      microvm.host.enable = true;

      # persistVar vms get a dataset (inventory.storage says where); its var/
      # subdir is shared into the guest as /var (see vm-guest.nix), leaving
      # room for sibling artifacts like disk images. M4 scope: assumes this
      # host has the pool — remote hypervisors get the NFS-backed variant
      # at M6
      zfs.pools.${inv.storage.pool}.datasets = lib.mkIf (statefulVms != { } || mountDatasets != { }) (
        {
          # virtiofsd runs with --posix-acl: without acltype=posixacl on the
          # backing fs, every file CREATE through the share dies with
          # EOPNOTSUPP (mkdir/chown work — maximally confusing). xattr=sa is
          # the standard pairing. children inherit both.
          ${inv.storage.vmsDataset} = {
            properties = {
              acltype = "posixacl";
              xattr = "sa";
            };
          };
        }
        // lib.mapAttrs' (
          name: _:
          lib.nameValuePair "${inv.storage.vmsDataset}/${name}" {
            # microvm-run (user microvm) creates volume images in the dataset
            # root; the chown is non-recursive so var/ stays root's, which is
            # what virtiofsd (root) wants
            perms = {
              owner = "microvm";
              group = "kvm";
              mode = "0755";
            };
            # guest /var mounts this subdir (vm-guest.nix); the ensure unit
            # guarantees it exists long before any vm starts
            dirs = [ "var" ];
          }
        ) statefulVms
        # datasets referenced by vm mounts: only the virtiofs-required
        # properties are asserted here — the rest of their config belongs
        # to whoever declares/owns them
        // mountDatasets
      );
      # host-delivered guest secrets: every name in a vm's `secrets` list is
      # an age secret this host decrypts to tmpfs and shares into that guest
      # at /run/host-secrets/<name> (vm-guest.nix). 0444 inside a
      # single-service vm is the whole point of single-service vms.
      age.secrets = lib.mkMerge (
        lib.mapAttrsToList (
          name: vm:
          lib.listToAttrs (
            map (
              s:
              lib.nameValuePair "vm-${name}-${s}" {
                file = ../secrets + "/${s}.age";
                path = "/run/vm-secrets/${name}/${s}";
                # real file, not agenix's default symlink into /run/agenix —
                # symlinks don't survive the virtiofs boundary (the guest
                # sees them dangling and systemd's LoadCredential dies with
                # EPROTO trying to stat them)
                symlink = false;
                mode = "0444";
              }
            ) (vm.secrets or [ ])
          )
        ) myVms
      );

      users.users.microvm.uid = 994;

      # each vm placed on this host by inventory becomes a microvm; its full
      # config is vms/<name> plus the vm-guest base profile
      microvm.vms = lib.mapAttrs (name: vmEntry: {
        # restart on closure change: microvm.nix defaults to opt-in restarts
        # (a switch updates the runner but keeps the old vm running — took a
        # debugging session to notice). our guests are cheap to bounce and
        # deploys should be atomic.
        restartIfChanged = true;
        config = {
          imports = [
            ./vm-guest.nix
            (../vms + "/${name}")
          ];
          networking.hostName = name;
        };
        specialArgs = {
          inherit inventory assignments repos;
          vm = vmEntry // {
            inherit name;
          };
        };
      }) myVms;
      assertions =
        lib.mapAttrsToList (name: vm: {
          assertion = builtins.stringLength (tapOf name) <= 15;
          message = "vmhost: tap name '${tapOf name}' exceeds IFNAMSIZ, shorten the vm name";
        }) myVms
        ++ lib.mapAttrsToList (name: vm: {
          assertion = inv.machines ? ${vm.host};
          message = "vmhost: vm '${name}' placed on unknown host '${vm.host}'";
        }) inv.vms
        ++ lib.concatLists (
          lib.mapAttrsToList (
            name: vm:
            map (s: {
              assertion = builtins.pathExists (../secrets + "/${s}.age");
              message = "vmhost: vm '${name}' wants secret '${s}' but secrets/${s}.age does not exist (create it with agenix -e and declare it in secrets/secrets.nix)";
            }) (vm.secrets or [ ])
          ) myVms
        );

      boot.kernel.sysctl = {
        "net.ipv4.conf.all.forwarding" = lib.mkDefault true;
        "net.ipv6.conf.all.forwarding" = lib.mkDefault true;
      };

      # vms holding a machine grant on *this* host arrive on the input path
      # (local vms via their tap, remote vms routed in) — matched by source
      # address, which every hosting tap anti-spoofs. scanned fleet-wide so
      # a vm's grants survive moving it to another hypervisor.
      networking.firewall.extraInputRules = lib.concatStrings (
        lib.mapAttrsToList (
          name: vm:
          lib.concatMapStrings (s: "ip saddr ${vm.addr.ip4} ${portClause s.ports}accept\n") (
            lib.filter (s: s.name == hostname) (machineAllows vm)
          )
        ) inv.vms
      );

      services.tailscale.extraSetFlags = [
        "--advertise-routes=${inv.net.vm.cidr4},${inv.net.vm.ula}"
      ];

      systemd.network.networks = perVmNetworks // {
        # catchall so a hand-made scratch tap (ip tuntap add vm-scratch mode
        # tap) still gets the gateway address for fabric testing
        "45-vm-catchall" = {
          matchConfig.Name = "vm-*";
          address = [
            "${inv.net.vm.gateway4}/32"
            "fe80::1/64"
          ];
          networkConfig = {
            IPv4Forwarding = true;
            IPv6Forwarding = true;
            # taps have no carrier until the vm process attaches
            ConfigureWithoutCarrier = true;
          };
          linkConfig.RequiredForOnline = "no";
        };
      };

      # routes to vms on other hypervisors come from modules/vm-routes.nix,
      # which every lan machine (hypervisor or not) carries

      networking.nftables.tables.vmpolicy = {
        family = "inet";
        content = ''
          chain forward {
            type filter hook forward priority filter; policy accept;
            iifname "vm-*" jump vm-egress
            oifname "vm-*" jump vm-ingress
          }

          # traffic into vms: trusted tiers always (both families), then
          # declared exposes
          chain vm-ingress {
            ct state established,related accept
            ip saddr ${inv.net.lan.cidr4} accept
            ip saddr ${inv.net.mgmt.cidr4} accept
            ip saddr ${inv.net.tailscale} accept
            ip6 saddr ${inv.net.lan.ula} accept
            ip6 saddr ${inv.net.mgmt.ula} accept
            ip6 saddr ${inv.net.tailscale6} accept
          ${ingressRules}    counter drop
          }

          # traffic out of vms: anti-spoof, then declared allows
          chain vm-egress {
          ${egressRules}    ct state established,related accept
            counter drop
          }
        '';
      };
    })
  ];
}
