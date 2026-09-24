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

  checkSel =
    s:
    if (s._class or null) == "policy-selector" then
      s
    else
      throw "vmhost: policy entry must be a normalized inventory selector, got a ${builtins.typeOf s}";

  allowsOf = vm: map checkSel (vm.allow or [ ]);
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
    { microvm.host.enable = lib.mkDefault false; }

    (lib.mkIf cfg.enable {
      microvm.host.enable = true;

      zfs.pools.${inv.storage.pool}.datasets = lib.mkIf (statefulVms != { } || mountDatasets != { }) (
        {
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
            perms = {
              owner = "microvm";
              group = "kvm";
              mode = "0755";
            };
            dirs = [ "var" ];
          }
        ) statefulVms
        // mountDatasets
      );
      age.secrets = lib.mkMerge (
        lib.mapAttrsToList (
          name: vm:
          lib.listToAttrs (
            map (
              s:
              lib.nameValuePair "vm-${name}-${s}" {
                file = ../secrets + "/${s}.age";
                path = "/run/vm-secrets/${name}/${s}";
                symlink = false;
                mode = "0444";
              }
            ) (vm.secrets or [ ])
          )
        ) myVms
      );

      users.users.microvm.uid = 994;
      microvm.vms = lib.mapAttrs (name: vmEntry: {
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
        "45-vm-catchall" = {
          matchConfig.Name = "vm-*";
          address = [
            "${inv.net.vm.gateway4}/32"
            "fe80::1/64"
          ];
          networkConfig = {
            IPv4Forwarding = true;
            IPv6Forwarding = true;
            ConfigureWithoutCarrier = true;
          };
          linkConfig.RequiredForOnline = "no";
        };
      };

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
