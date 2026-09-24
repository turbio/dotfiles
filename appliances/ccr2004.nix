{ lib, ... }:
let
  inventory = import ../lib/inventory.nix;

  lanMachines = lib.filterAttrs (_: m: m ? lan && m.lan ? ip4 && m.lan ? mac) inventory.machines;

  # lmao
  ref = path: "\${${path}}";

  bridgePorts = map (i: "ether${toString i}") (lib.range 3 16) ++ [ "sfp-sfpplus2" ];
  sanitize = lib.replaceStrings [ "-" ] [ "_" ];

  wanScript = n: ''
    :if ($bound = 1) do={
    /ip route set [find comment=MAIN_WAN${n}] gateway=($"gateway-address" . "%" . $interface)
    /ip route set [find comment=VIA_WAN${n}] gateway=($"gateway-address" . "%" . $interface)
    /ip firewall connection remove [find where connection-mark="conn_wan${n}"]
    }'';

  wanCheck = n: ''
    :local u${n} 0
    :foreach n in=[/tool netwatch find where comment=WAN${n}] do={
        :if ([/tool netwatch get $n status] = "up") do={
            :set u${n} ($u${n} + 1)
        }
    }
  '';

  wanPick = n: up: down: ''
    :if ($u${n} > 0) do={
        /ip route set [find comment=MAIN_WAN${n}] distance=${up}
    } else={
        /ip route set [find comment=MAIN_WAN${n}] distance=${down}
    }
  '';

  recomputeWan = ''
    :global wanPref
    :if ([:typeof $wanPref] = "nothing") do={ :set wanPref "" }
  ''
  + wanCheck "1"
  + wanCheck "2"
  + wanCheck "3"
  + ''
    :local newPref "wan2"
    :if ($u1 > 0) do={ :set newPref "wan1" }
    :if ($u3 > 0) do={ :set newPref "wan3" }
  ''
  + wanPick "1" "2" "5"
  + wanPick "2" "3" "6"
  + wanPick "3" "1" "4"
  + ''
    :if ($wanPref != $newPref) do={
        :foreach w in={"wan1";"wan2";"wan3"} do={
            :if ($w != $newPref) do={
                /ip firewall connection remove [find where connection-mark=("conn_" . $w)]
            }
        }
        :set wanPref $newPref
    }
  '';

  wans = lib.mapAttrs (name: w: w // inventory.net.wanProbes.${name}) {
    wan1 = {
      n = "1";
      iface = "ether1";
    };
    wan2 = {
      n = "2";
      iface = "ether2";
    };
    wan3 = {
      n = "3";
      iface = "sfp-sfpplus1";
    };
  };
  probeTarget = p: if p == "cf" then "1.1.1.1" else "8.8.8.8";

  netwatchScript = "/system script run recompute_wan";

  filterOrder = [
    "input_established"
    "input_invalid"
    "input_icmp"
    "input_lan"
    "input_drop"
    "fwd_fasttrack"
    "fwd_established"
    "fwd_invalid"
    "fwd_lan_out"
    "fwd_drop"
  ];
  mangleOrder = [
    "probe_out_wan1"
    "probe_out_wan2"
    "probe_out_wan3"
    "probe_pre_wan1"
    "probe_pre_wan2"
    "probe_pre_wan3"
    "conn_mark_wan1"
    "conn_mark_wan2"
    "conn_mark_wan3"
  ];
  natOrder = [
    "masq_wan1"
    "masq_wan2"
    "masq_wan3"
    "probe_out_wan1_cf"
    "probe_dst_wan1_cf"
    "probe_out_wan1_goog"
    "probe_dst_wan1_goog"
    "probe_out_wan2_cf"
    "probe_dst_wan2_cf"
    "probe_out_wan2_goog"
    "probe_dst_wan2_goog"
    "probe_out_wan3_cf"
    "probe_dst_wan3_cf"
    "probe_out_wan3_goog"
    "probe_dst_wan3_goog"
  ];
  filter6Order = [
    "input_established"
    "input_invalid"
    "input_icmpv6"
    "input_traceroute"
    "input_lan"
    "input_dhcpv6"
    "input_drop"
    "fwd_fasttrack"
    "fwd_established"
    "fwd_invalid"
    "fwd_bad_src"
    "fwd_bad_dst"
    "fwd_hoplimit1"
    "fwd_icmpv6"
    "fwd_lan"
    "fwd_drop"
  ];

  moveSeq = res: names: map (r: ref "${res}.${r}.id") names;

  badV6 = {
    unspecified = {
      address = "::/128";
      comment = "defconf: unspecified";
    };
    lo = {
      address = "::1/128";
      comment = "defconf: lo";
    };
    site_local = {
      address = "fec0::/10";
      comment = "defconf: site-local";
    };
    v4_mapped = {
      address = "::ffff:0.0.0.0/96";
      comment = "defconf: ipv4-mapped";
    };
    v4_compat = {
      address = "::/96";
      comment = "defconf: ipv4 compat";
    };
    discard = {
      address = "100::/64";
      comment = "defconf: discard only";
    };
    documentation = {
      address = "2001:db8::/32";
      comment = "defconf: documentation";
    };
    orchid = {
      address = "2001:10::/28";
      comment = "defconf: ORCHID";
    };
    sixbone = {
      address = "3ffe::/16";
      comment = "defconf: 6bone";
    };
  };
in
{
  resource.routeros_interface_bridge.bridge1 = {
    name = "bridge1";
  };

  resource.routeros_interface_ethernet.sfp_sfpplus1 = {
    factory_name = "sfp-sfpplus1";
    name = "sfp-sfpplus1";
  };

  resource.routeros_interface_list = {
    wan1.name = "WAN1";
    wan2.name = "WAN2";
    wan3.name = "WAN3";
    lan.name = "LAN";
  };

  resource.routeros_interface_list_member = {
    wan1_ether1 = {
      interface = "ether1";
      list = ref "routeros_interface_list.wan1.name";
    };
    wan2_ether2 = {
      interface = "ether2";
      list = ref "routeros_interface_list.wan2.name";
    };
    wan3_sfp1 = {
      interface = "sfp-sfpplus1";
      list = ref "routeros_interface_list.wan3.name";
    };
    lan_bridge1 = {
      interface = ref "routeros_interface_bridge.bridge1.name";
      list = ref "routeros_interface_list.lan.name";
    };
  };

  resource.routeros_interface_bridge_port = lib.listToAttrs (
    map (ifc: {
      name = "bp_${sanitize ifc}";
      value = {
        bridge = ref "routeros_interface_bridge.bridge1.name";
        interface = ifc;
      };
    }) bridgePorts
  );

  resource.routeros_routing_table = {
    via_wan1 = {
      name = "via_wan1";
      fib = true;
    };
    via_wan2 = {
      name = "via_wan2";
      fib = true;
    };
    via_wan3 = {
      name = "via_wan3";
      fib = true;
    };
  };

  resource.routeros_ip_pool.dhcp = {
    name = "dhcp";
    ranges = [ "192.168.88.2-192.168.88.254" ];
  };

  resource.routeros_ip_dhcp_server.dhcp1 = {
    name = "dhcp1";
    interface = ref "routeros_interface_bridge.bridge1.name";
    address_pool = ref "routeros_ip_pool.dhcp.name";
    lease_time = "2d";
  };

  resource.routeros_ip_dhcp_server_lease = lib.concatMapAttrs (
    host: m:
    {
      ${host} = {
        address = m.lan.ip4;
        mac_address = lib.toUpper m.lan.mac;
        server = ref "routeros_ip_dhcp_server.dhcp1.name";
        comment = host;
      };
    }
    // lib.mapAttrs' (
      label: nic:
      lib.nameValuePair "${host}_${label}" {
        address = nic.ip4;
        mac_address = lib.toUpper nic.mac;
        server = ref "routeros_ip_dhcp_server.dhcp1.name";
        comment = "${host} ${label}";
      }
    ) (m.lan.extra or { })
  ) lanMachines;

  resource.routeros_ip_dns_record =
    lib.concatMapAttrs (
      host: m:
      {
        "lan_${host}" = {
          name = "${host}.lan";
          address = m.lan.ip4;
          type = "A";
        };
      }
      // lib.mapAttrs' (
        label: nic:
        lib.nameValuePair "lan_${host}_${label}" {
          name = "${label}.${host}.lan";
          address = nic.ip4;
          type = "A";
        }
      ) (m.lan.extra or { })
    ) lanMachines
    // (
      let
        fwd = name: {
          inherit name;
          type = "FWD";
          forward_to = inventory.machines.joast.lan.ip4;
          match_subdomain = true;
        };
      in
      {
        fwd_int = fwd "int.turb.io";
        fwd_rev_vm = fwd "42.10.in-addr.arpa";
        fwd_rev_lan = fwd "88.168.192.in-addr.arpa";
        fwd_rev_mgmt = fwd "89.168.192.in-addr.arpa";
        fwd_rev_ula = fwd "d.6.b.f.e.7.d.0.3.5.d.f.ip6.arpa";
      }
    );

  resource.routeros_ip_dhcp_server_network.lan = {
    address = "192.168.88.0/24";
    dns_server = [ "192.168.88.1" ];
    gateway = "192.168.88.1";
    netmask = "24";
  };

  resource.routeros_ip_address = {
    lan = {
      address = "192.168.88.1/24";
      interface = ref "routeros_interface_bridge.bridge1.name";
      network = "192.168.88.0";
      comment = "defconf";
    };
    wan2 = {
      address = "192.168.50.10/24";
      interface = "ether2";
      network = "192.168.50.0";
    };
  };

  resource.routeros_ip_dhcp_client = {
    wan1 = {
      interface = "ether1";
      add_default_route = "no";
      comment = "WAN1";
      script = wanScript "1";
    };
    wan2 = {
      interface = "ether2";
      add_default_route = "no";
      default_route_tables = [ "main" ];
      comment = "WAN2";
      script = wanScript "2";
    };
    wan3 = {
      interface = "sfp-sfpplus1";
      add_default_route = "no";
      comment = "WAN3";
      script = wanScript "3";
    };
  };

  resource.routeros_ip_dns.dns = {
    allow_remote_requests = true;
    mdns_repeat_ifaces = [ "bridge1" ];
  };

  resource.routeros_ip_firewall_filter = {
    input_established = {
      chain = "input";
      action = "accept";
      connection_state = "established,related,untracked";
      comment = "established";
    };
    input_invalid = {
      chain = "input";
      action = "drop";
      connection_state = "invalid";
      comment = "invalid";
    };
    input_icmp = {
      chain = "input";
      action = "accept";
      protocol = "icmp";
      comment = "icmp";
    };
    input_lan = {
      chain = "input";
      action = "accept";
      in_interface_list = ref "routeros_interface_list.lan.name";
      comment = "router access";
    };
    input_drop = {
      chain = "input";
      action = "drop";
      log = true;
    };
    fwd_fasttrack = {
      chain = "forward";
      action = "fasttrack-connection";
      connection_state = "established,related";
      hw_offload = true;
      comment = "fasttrack established/related";
    };
    fwd_established = {
      chain = "forward";
      action = "accept";
      connection_state = "established,related,untracked";
      comment = "established,related,untracked";
    };
    fwd_invalid = {
      chain = "forward";
      action = "drop";
      connection_state = "invalid";
      comment = "invalid";
    };
    fwd_lan_out = {
      chain = "forward";
      action = "accept";
      in_interface_list = ref "routeros_interface_list.lan.name";
      comment = "lan out";
    };
    fwd_drop = {
      chain = "forward";
      action = "drop";
    };
  };

  resource.routeros_ip_firewall_mangle =
    lib.mapAttrs' (
      wname: w:
      lib.nameValuePair "probe_out_${wname}" {
        chain = "output";
        action = "mark-routing";
        dst_address = w.probeNet;
        new_routing_mark = "via_${wname}";
        passthrough = false;
        comment = "probe via WAN${w.n}";
      }
    ) wans
    // {
      probe_pre_wan1 = {
        chain = "prerouting";
        action = "mark-routing";
        dst_address = "192.168.100.0/24";
        new_routing_mark = "via_wan1";
        passthrough = false;
      };
      probe_pre_wan2 = {
        chain = "prerouting";
        action = "mark-routing";
        dst_address = "192.168.101.0/24";
        new_routing_mark = "via_wan2";
      };
      probe_pre_wan3 = {
        chain = "prerouting";
        action = "mark-routing";
        dst_address = "192.168.102.0/24";
        new_routing_mark = "via_wan3";
      };
    }
    // lib.mapAttrs' (
      wname: w:
      lib.nameValuePair "conn_mark_${wname}" {
        chain = "postrouting";
        action = "mark-connection";
        connection_state = "new";
        out_interface = w.iface;
        new_connection_mark = "conn_${wname}";
        comment = "tag flows egressing ${wname}";
      }
    ) wans;

  resource.routeros_ip_firewall_nat =
    lib.mapAttrs' (
      wname: w:
      lib.nameValuePair "masq_${wname}" {
        chain = "srcnat";
        action = "masquerade";
        out_interface_list = ref "routeros_interface_list.${wname}.name";
      }
    ) wans
    // lib.concatMapAttrs (
      wname: w:
      lib.concatMapAttrs (pname: paddr: {
        "probe_out_${wname}_${pname}" = {
          chain = "output";
          action = "dst-nat";
          dst_address = paddr;
          to_addresses = probeTarget pname;
          comment = "ping ${probeTarget pname} via ${wname}";
        };
        "probe_dst_${wname}_${pname}" = {
          chain = "dstnat";
          action = "dst-nat";
          dst_address = paddr;
          to_addresses = probeTarget pname;
          comment = "route ${probeTarget pname} via ${wname}";
        };
      }) w.probes
    ) wans;

  resource.routeros_ip_route = {
    via_wan2 = {
      comment = "VIA_WAN2";
      distance = 1;
      dst_address = "0.0.0.0/0";
      gateway = "192.168.50.1%ether2";
      routing_table = "via_wan2";
      lifecycle.ignore_changes = [ "gateway" ];
    };
    main_wan2 = {
      comment = "MAIN_WAN2";
      distance = 3;
      dst_address = "0.0.0.0/0";
      gateway = "192.168.50.1%ether2";
      lifecycle.ignore_changes = [
        "gateway"
        "distance"
      ];
    };
    via_wan1 = {
      comment = "VIA_WAN1";
      distance = 1;
      dst_address = "0.0.0.0/0";
      gateway = "192.168.1.254%ether1";
      routing_table = "via_wan1";
      lifecycle.ignore_changes = [ "gateway" ];
    };
    main_wan1 = {
      comment = "MAIN_WAN1";
      distance = 2;
      dst_address = "0.0.0.0/0";
      gateway = "192.168.1.254%ether1";
      routing_table = "main";
      lifecycle.ignore_changes = [
        "gateway"
        "distance"
      ];
    };
    via_wan1_bh = {
      comment = "VIA_WAN1_BH";
      blackhole = true;
      gateway = "";
      distance = 10;
      dst_address = "0.0.0.0/0";
      routing_table = "via_wan1";
    };
    via_wan2_bh = {
      comment = "VIA_WAN2_BH";
      blackhole = true;
      gateway = "";
      distance = 10;
      dst_address = "0.0.0.0/0";
      routing_table = "via_wan2";
    };
    via_wan3 = {
      comment = "VIA_WAN3";
      distance = 1;
      dst_address = "0.0.0.0/0";
      gateway = "192.168.1.254%sfp-sfpplus1";
      routing_table = "via_wan3";
      lifecycle.ignore_changes = [ "gateway" ];
    };
    via_wan3_bh = {
      comment = "VIA_WAN3_BH";
      blackhole = true;
      gateway = "";
      distance = 10;
      dst_address = "0.0.0.0/0";
      routing_table = "via_wan3";
    };
    main_wan3 = {
      comment = "MAIN_WAN3";
      distance = 1;
      dst_address = "0.0.0.0/0";
      gateway = "192.168.1.254%sfp-sfpplus1";
      routing_table = "main";
      lifecycle.ignore_changes = [
        "gateway"
        "distance"
      ];
    };

    vm_net = {
      comment = "VM_NET";
      dst_address = inventory.net.vm.cidr4;
      gateway = inventory.machines.joast.lan.ip4;
    };
  };

  resource.routeros_ip_firewall_raw.vmnet_hairpin_notrack = {
    chain = "prerouting";
    action = "notrack";
    src_address = inventory.net.lan.cidr4;
    dst_address = inventory.net.vm.cidr4;
    comment = "vm hairpin replies untracked";
  };

  resource.routeros_ip_traffic_flow.settings = {
    active_flow_timeout = "10s";
    inactive_flow_timeout = "10s";
    cache_entries = "32k";
  };

  resource.routeros_ip_traffic_flow_target.akvorado = {
    dst_address = inventory.vms.akvorado.addr.ip4;
    port = 2055;
    version = "9";
    v9_template_timeout = "1m";
  };

  resource.routeros_ipv6_address.lan = {
    address = "::1/64";
    from_pool = ref "routeros_ipv6_dhcp_client.attwan.pool_name";
    advertise = true;
    interface = ref "routeros_interface_bridge.bridge1.name";
  };

  resource.routeros_ipv6_dhcp_client.attwan = {
    interface = "sfp-sfpplus1";
    request = [
      "address"
      "prefix"
    ];
    pool_name = "attwan";
    pool_prefix_length = 64;
    add_default_route = true;
    default_route_tables = [ "main" ];
    comment = "prefix from wan";
  };

  resource.routeros_ipv6_firewall_addr_list = lib.mapAttrs (n: v: v // { list = "bad_ipv6"; }) badV6;

  resource.routeros_ipv6_firewall_filter = {
    input_established = {
      chain = "input";
      action = "accept";
      connection_state = "established,related,untracked";
      comment = "allow established/related";
    };
    input_invalid = {
      chain = "input";
      action = "drop";
      connection_state = "invalid";
      comment = "invalid";
    };
    input_icmpv6 = {
      chain = "input";
      action = "accept";
      protocol = "icmpv6";
      comment = "icmpv6";
    };
    input_traceroute = {
      chain = "input";
      action = "accept";
      protocol = "udp";
      dst_port = "33434-33534";
      comment = "accept UDP traceroute";
    };
    input_lan = {
      chain = "input";
      action = "accept";
      in_interface_list = ref "routeros_interface_list.lan.name";
      comment = "router access";
    };
    input_dhcpv6 = {
      chain = "input";
      action = "accept";
      protocol = "udp";
      dst_port = "546";
      in_interface = "sfp-sfpplus1";
      src_address = "fe80::/10";
      comment = "dhcpv6";
    };
    input_drop = {
      chain = "input";
      action = "drop";
    };
    fwd_fasttrack = {
      chain = "forward";
      action = "fasttrack-connection";
      connection_state = "established,related";
      comment = "fasttrack established/related";
    };
    fwd_established = {
      chain = "forward";
      action = "accept";
      connection_state = "established,related,untracked";
      comment = "accept established/related/untracked";
    };
    fwd_invalid = {
      chain = "forward";
      action = "drop";
      connection_state = "invalid";
      comment = "invalid";
    };
    fwd_bad_src = {
      chain = "forward";
      action = "drop";
      src_address_list = "bad_ipv6";
      comment = "bad src";
    };
    fwd_bad_dst = {
      chain = "forward";
      action = "drop";
      dst_address_list = "bad_ipv6";
      comment = "bad dst";
    };
    fwd_hoplimit1 = {
      chain = "forward";
      action = "drop";
      protocol = "icmpv6";
      hop_limit = "equal:1";
      comment = "rfc4890 drop hop-limit=1";
    };
    fwd_icmpv6 = {
      chain = "forward";
      action = "accept";
      protocol = "icmpv6";
      comment = "icmpv6";
    };
    fwd_lan = {
      chain = "forward";
      action = "accept";
      in_interface_list = ref "routeros_interface_list.lan.name";
      comment = "local network";
    };
    fwd_drop = {
      chain = "forward";
      action = "drop";
    };
  };

  resource.routeros_ipv6_neighbor_discovery.default = {
    interface = ref "routeros_interface_bridge.bridge1.name";
    advertise_mac_address = false;
    advertise_dns = false;
    hop_limit = 64;
    other_configuration = true;
  };

  resource.routeros_move_items = {
    fw_filter = {
      resource_name = "routeros_ip_firewall_filter";
      sequence = moveSeq "routeros_ip_firewall_filter" filterOrder;
    };
    fw_mangle = {
      resource_name = "routeros_ip_firewall_mangle";
      sequence = moveSeq "routeros_ip_firewall_mangle" mangleOrder;
    };
    fw_nat = {
      resource_name = "routeros_ip_firewall_nat";
      sequence = moveSeq "routeros_ip_firewall_nat" natOrder;
    };
    fw6_filter = {
      resource_name = "routeros_ipv6_firewall_filter";
      sequence = moveSeq "routeros_ipv6_firewall_filter" filter6Order;
    };
  };

  resource.routeros_snmp.settings.enabled = true;

  resource.routeros_system_clock.settings.time_zone_name = "America/Chicago";

  resource.routeros_system_script.recompute_wan = {
    name = "recompute_wan";
    source = recomputeWan;
    policy = [
      "read"
      "write"
    ];
    dont_require_permissions = false;
  };

  resource.routeros_tool_netwatch = lib.concatMapAttrs (
    wname: w:
    lib.concatMapAttrs (pname: paddr: {
      "${wname}_${pname}" = {
        name = "${wname}-${pname}";
        host = paddr;
        type = "icmp";
        interval = "5s";
        packet_count = 5;
        thr_loss_percent = 80;
        timeout = "1s";
        comment = "WAN${w.n}";
        up_script = netwatchScript;
        down_script = netwatchScript;
      };
    }) w.probes
  ) wans;
}
