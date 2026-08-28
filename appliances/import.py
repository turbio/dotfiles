#!/usr/bin/env python3
"""bulk-adopt existing mikrotik objects into the terraform state.

reads appliances/root/config.tf.json, looks every declared object up over the
device REST api, and maps it to a `tofu import` command. dry-run by default —
prints the mapping; pass --go to execute the imports (imports only write
local state, never the device).

env: ROS_PASSWORD (required), TF_VAR_username / TF_VAR_<dev>_hosturl override.

deliberately not imported:
  routeros_interface_ethernet   adopts by factory_name on first apply
  routeros_ip_dns               provider can't import; first apply overwrites
  routeros_move_items           no device object; apply-only ordering helper
so the post-import plan should show only those as "to add".
"""

import base64
import json
import os
import subprocess
import sys
import urllib.request
from pathlib import Path

REPO = Path(
    subprocess.run(
        ["git", "rev-parse", "--show-toplevel"], capture_output=True, text=True, check=True
    ).stdout.strip()
)
CFG = REPO / "appliances/root/config.tf.json"

SKIP = {"routeros_interface_ethernet", "routeros_ip_dns", "routeros_move_items"}

# type -> (rest path, matcher). matcher maps a config entry to a lookup key;
# the same key fn is applied to device objects (kebab-case fields).
BY_FIELD = {
    "routeros_interface_bridge": ("interface/bridge", ["name"]),
    "routeros_interface_bonding": ("interface/bonding", ["name"]),
    "routeros_interface_list": ("interface/list", ["name"]),
    "routeros_interface_list_member": ("interface/list/member", ["interface", "list"]),
    "routeros_interface_bridge_port": ("interface/bridge/port", ["interface"]),
    "routeros_routing_table": ("routing/table", ["name"]),
    "routeros_ip_pool": ("ip/pool", ["name"]),
    "routeros_ip_dhcp_server": ("ip/dhcp-server", ["name"]),
    "routeros_ip_dhcp_server_network": ("ip/dhcp-server/network", ["address"]),
    "routeros_ip_dhcp_client": ("ip/dhcp-client", ["interface"]),
    "routeros_ip_address": ("ip/address", ["address"]),
    "routeros_ip_route": ("ip/route", ["comment"]),
    "routeros_ip_traffic_flow_target": ("ip/traffic-flow/target", ["dst-address"]),
    "routeros_ipv6_address": ("ipv6/address", ["interface", "from-pool"]),
    "routeros_ipv6_dhcp_client": ("ipv6/dhcp-client", ["interface"]),
    "routeros_ipv6_firewall_addr_list": ("ipv6/firewall/address-list", ["list", "address"]),
    "routeros_tool_netwatch": ("tool/netwatch", ["host"]),
    "routeros_system_script": ("system/script", ["name"]),
}

# firewall rules match positionally within their chain, in move_items order
POSITIONAL = {
    "routeros_ip_firewall_filter": "ip/firewall/filter",
    "routeros_ip_firewall_mangle": "ip/firewall/mangle",
    "routeros_ip_firewall_nat": "ip/firewall/nat",
    "routeros_ipv6_firewall_filter": "ipv6/firewall/filter",
}

# singletons and find-by-default objects: fixed import ids / device lookups
SINGLETON = {
    "routeros_snmp": ".",
    "routeros_system_clock": ".",
    "routeros_ip_traffic_flow": ".",
}
FIND_DEFAULT = {
    "routeros_ipv6_neighbor_discovery": "ipv6/nd",  # entry with default=true
    "routeros_interface_ethernet_switch": "interface/ethernet/switch",  # first entry
}

DEVICES = ["ccr2004", "crs326", "crs305"]

cfg = json.loads(CFG.read_text())
password = os.environ.get("ROS_PASSWORD") or sys.exit("export ROS_PASSWORD first")
username = os.environ.get("TF_VAR_username", "admin")


def hosturl(dev):
    return os.environ.get(
        f"TF_VAR_{dev}_hosturl", cfg["variable"][f"{dev}_hosturl"]["default"]
    )


def rest(dev, path):
    req = urllib.request.Request(f"{hosturl(dev)}/rest/{path}")
    tok = base64.b64encode(f"{username}:{password}".encode()).decode()
    req.add_header("Authorization", f"Basic {tok}")
    with urllib.request.urlopen(req, timeout=15) as r:
        out = json.loads(r.read())
    return [o for o in out if o.get("dynamic") != "true"]


def dev_of(rname):
    for d in DEVICES:
        if rname.startswith(d + "_"):
            return d
    sys.exit(f"can't infer device from resource name {rname}")


def kebab(k):
    return k.replace("_", "-")


def resolve(v):
    """resolve terraform refs like ${type.name.attr} against the config"""
    if isinstance(v, str) and v.startswith("${") and v.endswith("}"):
        t, name, attr = v[2:-1].split(".")
        return resolve(cfg["resource"][t][name][attr])
    return v


def key_of(fields, obj, is_config):
    vals = []
    for f in fields:
        v = obj.get(f if not is_config else f.replace("-", "_"), "")
        vals.append(str(resolve(v) if is_config else v))
    return tuple(vals)


imports = []  # (address, id)
problems = []

for rtype, entries in cfg.get("resource", {}).items():
    if rtype in SKIP:
        continue

    if rtype in SINGLETON:
        for rname in entries:
            imports.append((f"{rtype}.{rname}", SINGLETON[rtype]))
        continue

    if rtype in FIND_DEFAULT:
        for rname, entry in entries.items():
            objs = rest(dev_of(rname), FIND_DEFAULT[rtype])
            match = next((o for o in objs if o.get("default") == "true"), objs[0] if objs else None)
            if match:
                imports.append((f"{rtype}.{rname}", match[".id"]))
            else:
                problems.append(f"{rtype}.{rname}: nothing on device")
        continue

    if rtype in BY_FIELD:
        path, fields = BY_FIELD[rtype]
        cache = {}
        for rname, entry in entries.items():
            dev = dev_of(rname)
            if dev not in cache:
                cache[dev] = rest(dev, path)
            want = key_of(fields, entry, True)
            hits = [o for o in cache[dev] if key_of(fields, o, False) == want]
            if len(hits) == 1:
                imports.append((f"{rtype}.{rname}", hits[0][".id"]))
            else:
                problems.append(
                    f"{rtype}.{rname}: {len(hits)} device matches for {dict(zip(fields, want))}"
                )
        continue

    if rtype in POSITIONAL:
        # config order: the move_items sequence for this type
        order = []
        for mi in cfg["resource"].get("routeros_move_items", {}).values():
            for ref in mi["sequence"]:
                t, name, _ = ref[2:-1].split(".")
                if t == rtype:
                    order.append(name)
        by_dev_chain = {}
        for rname in order:
            dev = dev_of(rname)
            chain = entries[rname]["chain"]
            by_dev_chain.setdefault((dev, chain), []).append(rname)
        for (dev, chain), rnames in by_dev_chain.items():
            objs = [o for o in rest(dev, POSITIONAL[rtype]) if o.get("chain") == chain]
            if len(objs) != len(rnames):
                problems.append(
                    f"{rtype} {dev}/{chain}: config has {len(rnames)} rules, device has {len(objs)} — refusing to zip"
                )
                continue
            for rname, obj in zip(rnames, objs):
                imports.append((f"{rtype}.{rname}", obj[".id"]))
        continue

    problems.append(f"{rtype}: no matcher defined, skipped")

go = "--go" in sys.argv
for addr, oid in imports:
    print(f"import {addr} {oid}")
if problems:
    print("\nUNRESOLVED (import by hand, or fix and rerun):", file=sys.stderr)
    for p in problems:
        print(f"  {p}", file=sys.stderr)

print(f"\n{len(imports)} matched, {len(problems)} unresolved", file=sys.stderr)

if not go:
    print("dry run — rerun with --go to execute", file=sys.stderr)
    sys.exit(1 if problems else 0)

for i, (addr, oid) in enumerate(imports, 1):
    print(f"[{i}/{len(imports)}] {addr}", file=sys.stderr)
    subprocess.run(
        ["nix", "run", f"{REPO}#appliance", "--", "import", addr, oid],
        check=True,
    )
