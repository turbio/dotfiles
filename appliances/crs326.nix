{ lib, ... }:
let
  ref = path: "\${${path}}";
  sanitize = lib.replaceStrings [ "-" ] [ "_" ];

  sfp = i: "sfp-sfpplus${toString i}";

  # sfp9/10 and 19/20 are bonded
  bridgePorts =
    map
      (p: {
        key = sanitize p;
        iface = p;
      })
      (
        map sfp (lib.range 1 8)
        ++ map sfp (lib.range 11 18)
        ++ map sfp (lib.range 21 24)
        ++ [
          "qsfpplus1-1"
          "qsfpplus2-1"
        ]
      )
    ++
      map
        (b: {
          key = b;
          iface = ref "routeros_interface_bonding.${b}.name";
        })
        [
          "bond0"
          "bond1"
        ];

  lanMembers =
    map sfp (lib.range 1 24)
    ++ map (i: "qsfpplus1-${toString i}") (lib.range 1 4)
    ++ map (i: "qsfpplus2-${toString i}") (lib.range 1 4);
in
{
  resource.routeros_interface_bridge.bridge = {
    name = "bridge";
    admin_mac = "04:F4:1C:DE:B7:F3";
    auto_mac = false;
    comment = "defconf";
  };

  resource.routeros_interface_bonding = {
    bond0 = {
      name = "bond0";
      slaves = [
        (sfp 9)
        (sfp 10)
      ];
      mode = "802.3ad";
      lacp_rate = "1sec";
      transmit_hash_policy = "layer-3-and-4";
    };
    bond1 = {
      name = "bond1";
      slaves = [
        (sfp 19)
        (sfp 20)
      ];
      mode = "802.3ad";
      lacp_rate = "1sec";
      transmit_hash_policy = "layer-3-and-4";
    };
  };

  resource.routeros_interface_list = {
    wan.name = "WAN";
    lan.name = "LAN";
  };

  resource.routeros_interface_bridge_port = lib.listToAttrs (
    map (p: {
      name = "bp_${p.key}";
      value = {
        bridge = ref "routeros_interface_bridge.bridge.name";
        interface = p.iface;
      };
    }) bridgePorts
  );

  resource.routeros_interface_list_member = {
    wan_ether1 = {
      interface = "ether1";
      list = ref "routeros_interface_list.wan.name";
    };
  }
  // lib.listToAttrs (
    map (ifc: {
      name = "lan_${sanitize ifc}";
      value = {
        interface = ifc;
        list = ref "routeros_interface_list.lan.name";
      };
    }) lanMembers
  );

  resource.routeros_ip_dhcp_client.mgmt = {
    interface = "ether1";
    default_route_tables = [ "main" ];
  };

  resource.routeros_snmp.settings.enabled = true;

  resource.routeros_system_clock.settings.time_zone_name = "America/Chicago";
}
