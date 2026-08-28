# renders a device module's terraform resources as a RouterOS .rsc script.
# review/bootstrap artifact only — terraform remains the apply path (rsc has
# no idempotence or removal semantics). rule order within firewall chains is
# recovered from the routeros_move_items sequences, so it needs no
# duplication here.
{ lib }:
let
  # "${routeros_x.y.attr}" -> { type, name, attr } or null
  refMatch =
    s:
    let
      m = builtins.match "[$][{]([a-z0-9_]+)[.]([A-Za-z0-9_]+)[.]([a-z_]+)[}]" s;
    in
    if m == null then
      null
    else
      {
        type = builtins.elemAt m 0;
        name = builtins.elemAt m 1;
        attr = builtins.elemAt m 2;
      };

  kebab = lib.replaceStrings [ "_" ] [ "-" ];

  # RouterOS quoted-string escapes: backslash, quote, $ (interpolation), newline
  escape = lib.replaceStrings [ "\\" "\"" "$" "\n" ] [ "\\\\" "\\\"" "\\$" "\\n" ];

  # emission mode per resource type; path order below is dependency-safe
  types = [
    {
      t = "routeros_interface_bridge";
      path = "/interface bridge";
      mode = "add";
    }
    {
      t = "routeros_interface_ethernet";
      path = "/interface ethernet";
      mode = "find-default-name";
    }
    {
      t = "routeros_interface_bonding";
      path = "/interface bonding";
      mode = "add";
    }
    {
      t = "routeros_interface_list";
      path = "/interface list";
      mode = "add";
    }
    {
      t = "routeros_interface_bridge_port";
      path = "/interface bridge port";
      mode = "add";
    }
    {
      t = "routeros_interface_ethernet_switch";
      path = "/interface ethernet switch";
      mode = "find-name";
    }
    {
      t = "routeros_interface_list_member";
      path = "/interface list member";
      mode = "add";
    }
    {
      t = "routeros_routing_table";
      path = "/routing table";
      mode = "add";
    }
    {
      t = "routeros_ip_pool";
      path = "/ip pool";
      mode = "add";
    }
    {
      t = "routeros_ip_dhcp_server";
      path = "/ip dhcp-server";
      mode = "add";
    }
    {
      t = "routeros_ip_address";
      path = "/ip address";
      mode = "add";
    }
    {
      t = "routeros_ip_dhcp_client";
      path = "/ip dhcp-client";
      mode = "add";
    }
    {
      t = "routeros_ip_dhcp_server_network";
      path = "/ip dhcp-server network";
      mode = "add";
    }
    {
      t = "routeros_ip_dns";
      path = "/ip dns";
      mode = "set";
    }
    {
      t = "routeros_ip_firewall_filter";
      path = "/ip firewall filter";
      mode = "add";
    }
    {
      t = "routeros_ip_firewall_mangle";
      path = "/ip firewall mangle";
      mode = "add";
    }
    {
      t = "routeros_ip_firewall_nat";
      path = "/ip firewall nat";
      mode = "add";
    }
    {
      t = "routeros_ip_route";
      path = "/ip route";
      mode = "add";
    }
    {
      t = "routeros_ip_traffic_flow";
      path = "/ip traffic-flow";
      mode = "set";
    }
    {
      t = "routeros_ip_traffic_flow_target";
      path = "/ip traffic-flow target";
      mode = "add";
    }
    {
      t = "routeros_ipv6_address";
      path = "/ipv6 address";
      mode = "add";
    }
    {
      t = "routeros_ipv6_dhcp_client";
      path = "/ipv6 dhcp-client";
      mode = "add";
    }
    {
      t = "routeros_ipv6_firewall_addr_list";
      path = "/ipv6 firewall address-list";
      mode = "add";
    }
    {
      t = "routeros_ipv6_firewall_filter";
      path = "/ipv6 firewall filter";
      mode = "add";
    }
    {
      t = "routeros_ipv6_neighbor_discovery";
      path = "/ipv6 nd";
      mode = "find-default";
    }
    {
      t = "routeros_snmp";
      path = "/snmp";
      mode = "set";
    }
    {
      t = "routeros_system_clock";
      path = "/system clock";
      mode = "set";
    }
    {
      t = "routeros_system_script";
      path = "/system script";
      mode = "add";
    }
    {
      t = "routeros_tool_netwatch";
      path = "/tool netwatch";
      mode = "add";
    }
  ];
in
resources:
let
  resolve =
    v:
    if builtins.isString v then
      let
        m = refMatch v;
      in
      if m == null then v else resolve resources.${m.type}.${m.name}.${m.attr}
    else
      v;

  renderVal =
    v:
    let
      r = resolve v;
    in
    if r == true then
      "yes"
    else if r == false then
      "no"
    else if builtins.isInt r then
      toString r
    else if builtins.isList r then
      "\"${escape (lib.concatStringsSep "," (map resolve r))}\""
    else
      "\"${escape r}\"";

  # terraform meta-arguments, not device fields
  meta = [
    "lifecycle"
    "provider"
    "depends_on"
  ];

  renderArgs =
    skip: entry:
    lib.attrNames entry
    # empty strings only exist to satisfy provider-required args (e.g.
    # blackhole route gateways) — the device form omits them
    |> builtins.filter (
      k: !(builtins.elem k skip) && !(builtins.elem k meta) && resolve entry.${k} != ""
    )
    |> map (k: "${kebab k}=${renderVal entry.${k}}")
    |> lib.concatStringsSep " ";

  renderEntry =
    mode: entry:
    if mode == "add" then
      "add ${renderArgs [ ] entry}"
    else if mode == "set" then
      "set ${renderArgs [ ] entry}"
    else if mode == "find-default-name" then
      "set [ find default-name=${renderVal entry.factory_name} ] ${renderArgs [ "factory_name" ] entry}"
    else if mode == "find-default" then
      "set [ find default=yes ] ${renderArgs [ ] entry}"
    else if mode == "find-name" then
      "set [ find name=${renderVal entry.name} ] ${renderArgs [ "name" ] entry}"
    else
      throw "render-rsc: unknown mode ${mode}";

  # chain order comes from move_items sequences: parse each ref back into
  # (type, resource-name) and emit in that order
  orderFromMoveItems =
    lib.attrValues (resources.routeros_move_items or { })
    |> map (mi: map refMatch mi.sequence)
    |> lib.concatLists
    |> builtins.filter (m: m != null)
    |> lib.groupBy (m: m.type)
    |> lib.mapAttrs (_: ms: map (m: m.name) ms);

  entryNames = t: orderFromMoveItems.${t} or (lib.attrNames (resources.${t} or { }));

  section =
    {
      t,
      path,
      mode,
    }:
    let
      entries = resources.${t} or { };
      names = entryNames t;
    in
    lib.optionalString (entries != { }) (
      "${path}\n" + lib.concatMapStrings (n: "${renderEntry mode entries.${n}}\n") names
    );
in
lib.concatMapStrings section types
