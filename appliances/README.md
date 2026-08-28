# appliances

Declarative MikroTik config (PLAN.md §3): terranix modules that compile to
Terraform JSON for the `terraform-routeros/routeros` provider (>= 1.99).

- `ccr2004.nix` — the router (from `ccr2004_latest.rsc`, 2026-07-25)
- `crs326.nix` — server-tier switch
- `crs305.nix` — wan-side media converter (flow control here is the 5GBASE-T
  loss fix — load-bearing)
- `common.nix` — one aliased provider per device; endpoints default to the
  known addresses, credentials via env only
- `combine.nix` + `root.nix` — merge the (device-oblivious) per-device
  modules into a single terraform root: resource names get device-prefixed,
  refs rewritten, each resource pinned to its device's provider alias. One
  state, one plan for the whole fleet.

`nix build .#appliance-config` builds the combined `config.tf.json`. Offline
schema validation runs as `checks.x86_64-linux.appliances` (provider plugin
from nixpkgs-unstable, no network).

`nix build .#appliance-<device>-rsc` renders the same resources as a RouterOS
script (`render-rsc.nix`) — for eyeball-diffing against the device's own
`/export`, and as a terraform-free bootstrap/rollback artifact. Review-only:
terraform stays the apply path (an .rsc has no idempotence or removal
semantics). Firewall rule order in the render is recovered from the
`move_items` sequences.

## adoption workflow (touches live devices — coordinate first)

Nothing here has been applied. The path from "validated config" to "device
under terraform":

All tofu invocations go through the wrapper, which drops the freshly built
`config.tf.json` into `appliances/root/` and runs the nix-provided tofu
(offline plugin, no registry):

    nix run .#appliance -- init
    nix run .#appliance -- plan

`appliances/root/` is the single working dir for the whole fleet:
**`terraform.tfstate` and `.terraform.lock.hcl` are committed**
(single-operator state-in-git; note the repo is public — but the raw exports
already are too); `config.tf.json`, `.terraform/`, and state backups are
gitignored. Commit the state after every apply.

Plan/apply talks to all three devices (they share the admin password via
`ROS_PASSWORD`; endpoints are defaulted in `common.nix`). For a
single-device operation use `-target`, e.g.
`nix run .#appliance -- plan -target=routeros_ip_dns.ccr2004_dns`.

1. **Prep the device**: enable the REST API — `/ip service set www
   disabled=no` (plain http on our own wires; switch to `www-ssl` + a cert
   and an `https://` hosturl override if that ever changes). Keep the serial
   console attached. Consider a `/system scheduler` rollback watchdog for the
   CCR (re-import last-known-good export unless disarmed).
2. **Env**: `export ROS_PASSWORD=...` (username defaults to `admin`,
   endpoints to the known device addresses; `TF_VAR_username` /
   `TF_VAR_<device>_hosturl` override).
3. **Import everything before any apply.** Ordinary items import by MikroTik
   internal id (`:put [/ip/address get [print show-ids]]`) or by
   `field=value` lookup; the easy-import pattern is to pull ids via REST:
   `curl -ku admin: https://<dev>/rest/ip/firewall/filter | jq -r '.[]|.".id"'`,
   then `nix run .#appliance -- import routeros_ip_firewall_filter.ccr2004_input_established '*2'`.
   Singletons (`routeros_snmp`, `routeros_system_clock`,
   `routeros_ip_traffic_flow`, `routeros_interface_ethernet_switch`) import
   with the literal id `.`. `routeros_interface_ethernet` is never imported —
   it adopts by `factory_name`. `routeros_ip_dns` **cannot** be imported: the
   first apply overwrites the dns settings (ours match the device, so this is
   a no-op — but eyeball it in the plan).
4. **`plan` until it's boring.** The goal is an empty (or fully-explained)
   diff before the first apply. Every unexplained diff is either a config bug
   here or drift worth knowing about.
5. Only then apply — with the user in the loop, per device, CRS305 last
   (it carries the wan path). Commit the updated `terraform.tfstate`.

Terraform leaves unmanaged objects alone, so anything not modeled below
survives adoption untouched.

## known gaps / deliberate deviations

Not expressible with the provider (stay manual, keep in device exports):

- CRS305 `/system swos` settings and `/interface ethernet switch
  l3hw-settings ipv6-hw=yes` — no provider resource at all.
- `/port set 0 name=serial0` (ccr, crs326); `/system note` (crs305);
  `/system routerboard settings` knobs (`enter-setup-on`, `boot-os`) — left
  unmodeled to keep the surface small; revisit if they ever matter.
- `/ip firewall connection tracking set enabled=yes` (ccr) — not modeled;
  device default behavior.
- `/ip traffic-flow` `enabled=yes` flag — not in the provider schema (v1.99);
  the rest of the traffic-flow settings are managed.
- defconf wireless security-profile line in the crs305 export — noise.

Deliberate deviations from the exports (will show as apply-time changes):

- **netwatch entries get `name`s** (`wan1-cf` etc.) — the device entries are
  unnamed, the provider requires names.
- **blackhole routes carry `gateway = ""`** — provider requires the arg;
  verify at plan time that this round-trips cleanly.

HE-tunnel cruft (disabled `sit1` 6to4 interface, its `2000::/3` route, the
two disabled ipv6 addresses) is *not* modeled: delete it from the device
during adoption instead.

## queued cleanups (apply after adoption converges)

1. Fix broken lan ipv6: `routeros_ipv6_address.lan.from_pool` → `"attwan"`
   (device says `wan`, a pool that doesn't exist; the export literally
   contains a pool-not-found error comment).
2. Drop the stray `0.0.0.0/24` dhcp-server network entry.
3. Then the M1/M5 additions: the `10.42.0.0/16 → ballos` route, generated
   static leases, the mgmt bridge split.
