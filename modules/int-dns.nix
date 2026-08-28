# the internal resolver (PLAN.md §4 / M3): unbound serving int.turb.io and
# the reverse zones, all generated from inventory — machines, their extra
# nics (<label>.<host>.int.turb.io), and vms — plus full recursion for the
# trusted tiers and vms. this is the unified hierarchy that eventually
# retires .lan; the resolver itself later moves into its own vm (vms/ns)
# with a fallback kept on the host.
#
# consumers: the ccr forwards int.turb.io + reverse zones here (FWD records
# in appliances/ccr2004.nix), tailscale clients via split dns (console
# step), vms directly at the anycast gateway address.
{
  config,
  lib,
  inventory,
  hostname,
  ...
}:
let
  cfg = config.intDns;
  inv = inventory;
  me = inv.machines.${hostname};
  zone = "int.turb.io";

  q = s: ''"${s}"'';

  lanMachines = lib.filterAttrs (_: m: m ? lan && m.lan ? ip4) inv.machines;

  # machines with no lan presence (cloud edges) are internally reachable via
  # tailscale, so that's what their internal name means
  tsMachines = lib.filterAttrs (
    _: m: !(m ? lan && m.lan ? ip4) && m ? tailscale && m.tailscale ? ip4
  ) inv.machines;

  machineRecords =
    lib.concatLists (
      lib.mapAttrsToList (
        host: m:
        [
          {
            name = "${host}.${zone}";
            ip = m.lan.ip4;
          }
        ]
        ++ lib.mapAttrsToList (label: nic: {
          name = "${label}.${host}.${zone}";
          ip = nic.ip4;
        }) (m.lan.extra or { })
        # explicit service aliases (inventory dnsAliases): the internal
        # name for a public-name service hosted here, so internal clients
        # skip the cloud-edge detour (e.g. nixcache.int.turb.io)
        ++ map (a: {
          name = "${a}.${zone}";
          ip = m.lan.ip4;
        }) (m.dnsAliases or [ ])
      ) lanMachines
    )
    ++ lib.mapAttrsToList (host: m: {
      name = "${host}.${zone}";
      ip = m.tailscale.ip4;
    }) tsMachines;

  vmRecords = lib.mapAttrsToList (name: vm: {
    name = "${name}.${zone}";
    ip = vm.addr.ip4;
    ip6 = vm.addr.ip6;
  }) inv.vms;

  # reverse nibble zone for the ula /48 (fd53:0d7e:fb6d::/48)
  ulaRev = "d.6.b.f.e.7.d.0.3.5.d.f.ip6.arpa";
in
{
  options.intDns = {
    enable = lib.mkEnableOption "internal dns resolver";
  };

  config = lib.mkIf cfg.enable {
    services.unbound = {
      enable = true;
      settings.server = {
        # no wildcard: resolved's stub (127.0.0.53/.54) and akvorado's
        # aardvark-dns (10.89.0.1) hold specific :53 binds that a wildcard
        # collides with. freebind covers boot races (dhcp lan addr, tap
        # gateway addr that only exists once a vm tap is up)
        interface = [
          "127.0.0.1"
          me.lan.ip4
          inv.net.vm.gateway4
        ]
        ++ lib.optional (me ? tailscale && me.tailscale ? ip4) me.tailscale.ip4;
        ip-freebind = "yes";
        access-control = [
          "127.0.0.0/8 allow"
          "${inv.net.lan.cidr4} allow"
          "${inv.net.mgmt.cidr4} allow"
          "${inv.net.vm.cidr4} allow"
          "${inv.net.tailscale} allow"
          "${inv.net.ula} allow"
        ];
        local-zone = [
          "${q "${zone}."} static"
          "${q "42.10.in-addr.arpa."} static"
          "${q "88.168.192.in-addr.arpa."} static"
          "${q "89.168.192.in-addr.arpa."} static"
          "${q "${ulaRev}."} static"
        ];
        local-data =
          map (r: q "${r.name}. A ${r.ip}") (machineRecords ++ vmRecords)
          ++ map (r: q "${r.name}. AAAA ${r.ip6}") vmRecords;
        local-data-ptr =
          map (r: q "${r.ip} ${r.name}") (machineRecords ++ vmRecords)
          ++ map (r: q "${r.ip6} ${r.name}") vmRecords;
      };
    };

    # reachable by lan (the ccr's FWDs), mgmt, tailscale, and the vm taps;
    # unbound's access-control refuses anything else that slips through
    networking.firewall.allowedUDPPorts = [ 53 ];
    networking.firewall.allowedTCPPorts = [ 53 ];
  };
}
