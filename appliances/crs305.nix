# CRS305-1G-4S+ — wan-side media converter between the CCR and the AT&T
# BGW320. Translation of crs305_latest.rsc (2026-07-25, RouterOS 7.15.3).
# The sfp1/sfp2 flow control is the fix for the 5GBASE-T rate-adaptation
# packet loss — load-bearing, do not drop.
{ lib, ... }:
let
  ref = path: "\${${path}}";
in
{
  resource.routeros_interface_bridge.bridge = {
    name = "bridge";
    admin_mac = "D4:01:C3:74:08:DC";
    auto_mac = false;
    comment = "defconf";
  };

  resource.routeros_interface_ethernet = {
    ether1 = {
      factory_name = "ether1";
      name = "ether1";
      disabled = true;
    };
    sfp_sfpplus1 = {
      factory_name = "sfp-sfpplus1";
      name = "sfp-sfpplus1";
      rx_flow_control = "on";
      tx_flow_control = "on";
    };
    sfp_sfpplus2 = {
      factory_name = "sfp-sfpplus2";
      name = "sfp-sfpplus2";
      rx_flow_control = "on";
      tx_flow_control = "on";
    };
    sfp_sfpplus3 = {
      factory_name = "sfp-sfpplus3";
      name = "sfp-sfpplus3";
      disabled = true;
    };
    sfp_sfpplus4 = {
      factory_name = "sfp-sfpplus4";
      name = "sfp-sfpplus4";
      disabled = true;
    };
  };

  resource.routeros_interface_list = {
    wan.name = "WAN";
    lan.name = "LAN";
  };

  resource.routeros_interface_bridge_port = lib.listToAttrs (
    map
      (ifc: {
        name = "bp_${lib.replaceStrings [ "-" ] [ "_" ] ifc}";
        value = {
          bridge = ref "routeros_interface_bridge.bridge.name";
          interface = ifc;
          comment = "defconf";
        };
      })
      [
        "ether1"
        "sfp-sfpplus1"
        "sfp-sfpplus2"
        "sfp-sfpplus3"
        "sfp-sfpplus4"
      ]
  );

  resource.routeros_interface_list_member = {
    wan_ether1 = {
      interface = "ether1";
      list = ref "routeros_interface_list.wan.name";
    };
  }
  // lib.listToAttrs (
    map (i: {
      name = "lan_sfp_sfpplus${toString i}";
      value = {
        interface = "sfp-sfpplus${toString i}";
        list = ref "routeros_interface_list.lan.name";
      };
    }) (lib.range 1 4)
  );

  # /interface ethernet switch set 0 l3-hw-offloading=yes
  # (the companion `l3hw-settings ipv6-hw=yes` is NOT expressible — see README)
  resource.routeros_interface_ethernet_switch.settings = {
    name = "switch1";
    l3_hw_offloading = true;
  };

  resource.routeros_ip_dhcp_client.mgmt = {
    interface = ref "routeros_interface_bridge.bridge.name";
  };

  resource.routeros_system_clock.settings.time_zone_name = "America/Chicago";
}
