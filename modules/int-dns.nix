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

    networking.firewall.allowedUDPPorts = [ 53 ];
    networking.firewall.allowedTCPPorts = [ 53 ];
  };
}
