# vmize: plan

Move every network-gappable service into its own microvm, declaratively. One
source of truth (`inventory.nix`) from which addressing, DNS, routing, firewall
policy, storage plumbing, and monitoring config are all derived. Moving a VM
between machines = change one attr + redeploy.

Trust model: **physical servers are fully trusted, VMs are fully untrusted.**
Every VM sits behind an enforcement point that lives on trusted hardware.

## 0. Current state (what the design has to work with)

- **Physical topology** (configs snapshotted in `*_latest.rsc`):

  ```
  servers (ballos/joast bonds, …) ──CRS326-24S+2Q+──10G──┐
                                                     CCR2004 ──10G── CRS305 ──5G rj45── AT&T BGW320   (WAN3, preferred)
  mgmt: iLO/iDRAC, backup server NICs,  ──1G rj45──────┤     ether1 ──1G───────────────  same BGW320   (WAN1)
        raspberry pis (tailscale relay rn)             │     ether2 ──1G── pepwave       (WAN2, backup)
  ```

  The CRS326 carries the server tier (two LACP bonds: `bond0` = sfp9+10,
  `bond1` = sfp19+20, all ports one flat bridge). The CCR's copper ports
  (ether3–16) carry the management gear but are bridged into the *same*
  `bridge1` / `192.168.88.0/24` as everything else. The CRS305 is effectively
  a WAN-side media converter (flow control on, per the 5G rate-adaptation
  fix). No VLANs anywhere; no static DHCP leases.
- **Router**: `192.168.88.0/24` on `bridge1`, multi-WAN failover via netwatch
  + distance rewriting, WAN3 preferred. The latest export (unlike the
  committed one) **does** have a stateful IPv4 filter (established+fasttrack,
  LAN-out accept, default drop) — but with one flat bridge there's still zero
  segmentation between servers, management gear, and clients. Per-VM
  enforcement still belongs on the hypervisors (the trusted tier).
- **IPv6**: currently broken-ish. The old static GUA on bridge1 is gone;
  DHCPv6-PD on WAN3 now fills pool `attwan`, but bridge1's address says
  `from-pool=wan` — a pool that no longer exists (the export literally
  contains `# address pool error: pool not found: wan`). Disabled HE 6to4
  tunnel remnants linger. No ULA anywhere. External IPv6 is a later stage,
  but the pool mismatch should be fixed during appliance adoption (§3).
- **DNS today is three uncoordinated systems, one of them dead**: public
  BIND (aackle/backle) serving `zones/*.zone` including the published hack
  `*.int.turb.io → 100.100.57.46` (ballos's tailscale IP, A-only); tailscale
  MagicDNS bare names; and `.lan` names — which are **broken**: lease→DNS
  registration worked on the previous router and was never set up on the
  CCR2004 (the export has no dhcp `domain=` and no static dns entries).
  Configs still reference `ballos.lan` / `zote.lan` /
  `j2.lan` / `homeassistant.lan` (nginx upstreams, prometheus targets, NFS
  mounts) — those are limping or dead, and curly's hardcoded `/etc/hosts`
  overrides are a workaround for it. "Internal" is enforced by nginx
  `allow 100.100.0.0/16` lists, not by DNS or routing.
- **VPN**: tailscale on every host except zote, `useRoutingFeatures = "both"`,
  but all route/ACL/DNS state lives in the admin console, not the repo. The
  WireGuard mesh (`assignments.nix`, `modules/wg-vpn.nix`, `vpn.nix`) is
  dormant — imports commented out.
- **Hypervisor candidates**: ballos (big iron, ext4 root + `tank` 115T zfs
  pool); joast and j2 (diskless, netbooted from ballos, currently remote nix
  builders); zote (diskless, netbooted, runs ollama + molters). The "state on
  tank, compute elsewhere" pattern already exists via NFS from ballos and
  works.
- **microvm.nix prior art**: an aarch64 builder microvm existed and was removed
  in `3437bc2`; a dev VM in `2e0ffb8`. The `tank/enc/microvms` dataset (5.4G)
  still exists. `tests/ballos-vm.nix` boots all of ballos in a qemu test.
- **Undeclared state to be aware of**: datasets that exist but aren't in
  `zfs.pools` (`enc/nixcache`, `enc/http`, `enc/evaldb`, `tank/prometheus`, …),
  colotop is an ad-hoc binary in `/tmp` behind `colotop.turb.io`, dex and fins
  don't exist in the repo yet.

## 1. Address hierarchy

Everything gets three addresses: internal IPv4, internal IPv6 (ULA), external
IPv6 (GUA, later stage). Identity is the **name, nothing else**: a VM entry
looks like `{ host = "ballos"; }` under `vms.immich`, and all three addresses
are derived from `"immich"` by hashing —
`H = first 16 bits of sha256(name)` (`builtins.hashString` at eval time), used
identically in every address family. No id counters to maintain. Same trick
for derived MACs and tap names (C3D2 does exactly this at ~60-VM scale;
skyflake likewise).

### Allocations

| Range | Purpose |
|---|---|
| `192.168.88.0/24` | server/client LAN, unchanged. Physical machines get **generated static DHCP leases** (`.1`–`.63` infra, `.64`–`.199` static machines, `.200`–`.254` dynamic pool) |
| `192.168.89.0/24` | **management tier** (new): iLO/iDRAC, PDUs, pis, backup server NICs — a separate bridge on the CCR's copper ports (§3), same lease-generation scheme |
| `10.42.0.0/16` | VM space. VM named `n` → `10.42.(H/256).(H%256)` with `H = hash₁₆(n)`. `10.42.0.0/24` reserved (`.0.1` = on-link gateway anycast, see routing); hashes landing there demand a salt (see rules) |
| `fd53:d7e:fb6d::/48` | ULA site prefix (freshly generated, RFC 4193) |
| `fd53:d7e:fb6d:88::/64` | ULA for the server LAN; machine → `::<last octet of its lease>` |
| `fd53:d7e:fb6d:89::/64` | ULA for the management tier, same scheme |
| `fd53:d7e:fb6d:42::/64` | ULA for VMs; VM `n` → `fd53:d7e:fb6d:42::H` (same 16-bit hash as v4, so the two visibly correlate and share one collision domain) |
| GUA (later) | one /64 from the PD pool bound to the VM tier; VM `n` → `<prefix>::H`. Same hash, same last hextet |
| `100.64.0.0/10` | tailscale, unchanged |
| `10.100.0.0/24` | legacy wireguard — retire references (pando proxies in ballos nginx) or leave dormant |

Rules:

- **Collisions fail the build**: the inventory asserts pairwise-distinct
  hashes at eval time. With ~50 VMs in a 16-bit space the odds of ever seeing
  a collision are ~2%; when one happens (or a hash lands in a reserved
  range), the error names the two entries and the fix is a per-VM
  `addressSalt = 1` (hash `"immich-1"` instead) or an explicit address
  override. That's the entire escape hatch — no global renumbering, and the
  common case stays pure names.
- **Physical machines carry explicit addresses**, not hashes: their
  `192.168.88.x` values encode existing reality (`.242` ballos, `.227`
  joast, …) and the lease space is too small to hash into. The inventory
  records name → address; everything (DNS, leases, monitoring, policy) still
  keys off the name.
- VM addresses are **stable across migration and re-eval** — the hash depends
  only on the name, not on `host` or on what else exists. Renaming a VM is
  the one thing that renumbers it, which is exactly the semantics
  "identity = name" implies.

## 2. Routing

Per-VM **routed /32 + /128** (no shared L2 between VMs — an untrusted VM never
shares a broadcast domain with anything):

- Each VM gets its own tap; the hypervisor holds `10.42.x.y/32 dev vm-<name>`
  and `fd53:…:42::N/128 dev vm-<name>`. Guest uses the anycast gateway
  (`10.42.0.1` onlink) — identical guest network config on every host, so
  migration needs no guest changes.
- Every VM host carries generated routes for **all other VMs** via their owning
  host's LAN address (Nix knows the full placement map, so the route mesh is
  just a `map` over the inventory). Cross-host VM traffic goes host↔host
  directly on the LAN.
- The CCR needs routes so LAN clients can reach VMs: start with a single
  static `10.42.0.0/16 → ballos` (phase 1: all VMs live there). When VMs
  spread to other hosts, generate the per-host route set as a small `.rsc`
  pushed over the RouterOS API/ssh at deploy time (we already keep
  `ccr2004.rsc` exports; this makes a slice of it generated). If route-pushing
  ever feels clunky, the upgrade path is bird+BGP from hypervisors to the CCR
  — but don't start there.
- Tailscale reachability: ballos advertises `10.42.0.0/16` (and later the VM
  GUA /64) as a subnet route via `services.tailscale.extraUpFlags` /
  `--advertise-routes`. This is the first piece of tailscale state that moves
  from the console into the repo.
- VM egress to internet: routed out through the host to the CCR, NATed by the
  existing masquerade.
- External ingress keeps the current shape (edge nodes DNAT → tailscale →
  nginx), except nginx eventually proxies to VM addresses instead of
  localhost ports.
- VM egress "may" — i.e. whether a VM is allowed out at all — is policy (§5),
  not routing.

## 3. Appliances as Nix (CCR2004, CRS326, CRS305)

The MikroTik gear becomes declaratively managed from this repo, and the
physical layout (devices, ports, links, bonds) becomes inventory data.

- **Mechanism**: Terranix + the RouterOS Terraform provider (the
  [nix-routeros](https://github.com/aleks-sidorenko/nix-routeros) approach) —
  typed Nix options compile to Terraform JSON, `tofu plan` shows the diff
  against the live device, `apply` converges it incrementally. This repo
  runs tofu through a nix-wrapped app with per-device state committed under
  `appliances/<device>/`, so the workflow is native. The export-diff-apply alternative (mikrotik.nix) is younger and
  riskier. (Done: all three devices adopted, plans converge clean, and the
  `*_latest.rsc` dumps are retired — `nix build .#appliance-<dev>-rsc`
  renders fresh equivalents from the models.)
- **Repo shape**: `appliances/<device>.nix` per device, consuming the same
  inventory: the CCR's DHCP leases, DNS forwarder, per-host VM routes, and
  bridge/port layout; the CRS326's bonds (which must mirror the NixOS-side
  `bond0` declarations on ballos/joast — today those two halves of each LACP
  pair live in different places with nothing keeping them consistent); the
  CRS305's flow-control settings (currently load-bearing for upload
  throughput — encode it, don't lose it).
- **Adoption before change**: first milestone is importing each device's
  *current* state into the Nix/Terranix model until `plan` shows an empty
  diff — zero behavior change, config now in git. Only then make changes
  through it. Known cleanups to make once adopted: the broken
  `from-pool=wan` → `attwan` IPv6 mismatch, dead HE tunnel remnants, the
  stray `0.0.0.0/24` DHCP network entry.
- **Management tier**: the CCR's copper ports (ether3–16) leave `bridge1` and
  form a `mgmt` bridge on `192.168.89.0/24`. That's where iLO/iDRAC, PDUs,
  the pis, and the servers' backup NICs (the metric-2000 `eno1`s) land.
  Management firmware is notoriously crusty, so mgmt is its own trust tier:
  reachable *from* trusted hosts and tailscale, but mgmt devices cannot
  initiate into the server LAN or VMs, and VMs can never reach mgmt. This
  slots into the same policy matrix (§5) — enforced at the CCR since it
  routes between the tiers.
- **Safety**: appliance changes are the one part of the system where a bad
  apply can cut off the path used to fix it. Rules: never apply remotely
  without MikroTik Safe Mode semantics or a scheduled config-rollback
  (`/system scheduler` watchdog that re-imports last-known-good unless
  disarmed), and keep the serial console cable plugged in.

## 4. DNS

Goal: one generated source of truth, split-horizon, no more `.lan` /
`*.int.turb.io`-published-publicly / MagicDNS-bare-name mixture.

- **Zone**: keep `int.turb.io` as the internal namespace (it's already
  established in vhost names and allow-lists). Every inventory entry — machine
  or VM — gets `<name>.int.turb.io` A (internal v4) + AAAA (ULA). Service
  aliases (e.g. `forge.int.turb.io`) are CNAMEs declared next to the VM.
  Reverse zones for `10.42/16`, `88.168.192.in-addr.arpa`, and the ULA /48 are
  generated from the same data.
- **Server**: an authoritative+recursive resolver (unbound or bind, zone files
  rendered by Nix) — this becomes one of the first VMs (`ns.int.turb.io`,
  address in the reserved block), initially with a fallback instance directly on
  ballos so DNS never depends on the VM layer being healthy. It forwards
  everything non-internal upstream.
- **Distribution**:
  - LAN clients: CCR DHCP hands out the internal resolver (or the CCR keeps
    serving DNS but gains a generated forwarder rule for `int.turb.io`).
  - Tailscale clients: split DNS in the admin console: `int.turb.io` → the
    resolver's tailscale-reachable address.
  - Hosts/VMs: `services.resolved` pointed at it declaratively.
- **Public zone cleanup**: once split-horizon works, delete the public
  `*.int.turb.io → 100.100.57.46` record and curly's `/etc/hosts` hack; keep
  public `turb.io` zones exactly as they are (edges unchanged).
- **Certs**: `*.turb.io` does **not** cover `*.int.turb.io` (single label
  wildcard). Add `*.int.turb.io` to the turb.io cert's `extraDomainNames` so
  internal vhosts can use TLS instead of today's plain HTTP + allow-list.
- `.lan` consumers get migrated as their targets do (`ballos.lan` in zote
  mounts, `zote.lan`/`j2.lan` in ballos nginx + prometheus). Note
  `.lan` is *already broken* (see §0) — which makes internal DNS a repair,
  not a nicety. Stopgap (done 2026-07-26): static leases + `.lan` A records
  generated from inventory on the CCR for ballos/zote/j2. **`.lan` is
  on borrowed time** — the stopgap exists only to unbreak current configs,
  and the suffix gets abandoned entirely once the unified `int.turb.io`
  hierarchy lands; no new `.lan` references should be added.

## 5. Policy: who can talk to whom

Declarative matrix in the inventory, enforced as **nftables on each
hypervisor** (the trusted tier), applied to the VM tap interfaces' forward
path. The router is not an enforcement point.

- Defaults: physical machines and tailscale (`100.64.0.0/10`) may reach
  everything. VMs are **default-deny both directions** (including VM→VM and
  VM→internet).
- Each VM declares needs, e.g.:

  ```nix
  vms.immich = {
    host = "ballos";
    expose = [ { port = 2283; to = [ "vm:ingress" ]; } ];
    allow = [ "dns" ];           # nearly every VM gets this
    egress = false;              # no internet
  };
  ```

  Selectors: `vm:<name>`, `host:<name>`, `tag:<tag>` (e.g. `tag:monitoring`
  so prometheus can scrape every VM's exporters without N² rules), `lan`,
  `mgmt`, `tailscale`, `internet`. (`mgmt` is its own semi-trusted tier —
  see §3; those rules are enforced at the CCR, which routes between tiers.)
- The generator emits, per host, one nftables table keyed by tap interface +
  source address (both checked — a VM can't help itself by spoofing, since
  its /32 is pinned to its tap and rp_filter/static neighbor entries pin the
  rest).
- Cross-host flows are enforced twice (source host egress, dest host ingress)
  from the same matrix, so a single misdeployed host fails closed.
- Same matrix later drives the CCR's v6 forward chain for externally exposed
  services (GUA stage).

## 6. VM architecture (microvm.nix)

Re-add `microvm.nix` as a flake input (prior art in git history: `3437bc2`,
`2e0ffb8`).

- **Layout**: `vms/<name>/default.nix` is a complete NixOS config for the
  guest (service, its own postgres/redis if needed, promtail, node_exporter,
  sshd trusted-only). A shared `modules/vm-guest.nix` base profile pins:
  addressing from inventory, resolver, minimal closure, serial console, no
  desktop/home-manager. `modules/vm-host.nix` turns a physical host into a
  hypervisor: microvm.host, taps, routes, the nftables policy engine, storage
  plumbing.
- **Self-contained services**: each VM bundles its own dependencies (immich VM
  runs its own postgres+redis) rather than a shared DB VM — this keeps "one
  service = one VM = one nix file = one unit of migration".
- **Nix store**: guests use the standard virtiofs read-only share of the host
  store on disked hosts. Diskless hosts: see §7.
- **Secrets**: the *host* decrypts agenix secrets and passes them into the
  guest via a per-VM virtiofs share (or microvm credentials). VMs never hold
  age identities; `secrets/secrets.nix` doesn't grow per-VM keys. (Also worth
  narrowing existing secrets to the hosts that need them while touching this.)
- **Deploy/ops**: stay with the existing `nixos-rebuild switch` flow — VMs are
  systemd units in the host closure (`microvm.vms.*`), so deploying the host
  deploys its VMs, and `checks` (extend the `tests/ballos-vm.nix` pattern
  per-VM) gate it in buildbot. Migration = change `host` attr, redeploy old
  host (VM unit removed), redeploy new host (unit added), router route set
  regenerates. Storage follows automatically because of §6.

## 7. Storage

`tank` on ballos is the backing store for all VM state, everywhere.

- **Per-VM dataset**: `tank/enc/vms/<name>` declared via the existing
  `modules/zfs-datasets.nix` machinery, sanoid snapshot coverage by default.
  Reuse/rename the leftover `tank/enc/microvms`.
- **VMs on ballos**: dataset attached via virtiofs share (file-level state:
  keeps snapshots/`zfs send` meaningful and avoids opaque images) or a zvol as
  virtio-blk for DB-heavy loads if virtiofs perf disappoints. Start virtiofs.
- **VMs on other hosts**: host NFS-mounts `tank/enc/vms/<name>` from ballos
  and virtiofs-shares it into the guest. The **VM never touches NFS itself**
  (an untrusted VM with an NFS client credential against tank would be a hole
  through the trust model). Fallback for workloads where NFS+virtiofs hurts:
  zvol exported from ballos via iSCSI/NBD, attached as virtio-blk — keep in
  the back pocket, don't build it in phase 1.
- Because the state path is "whatever host, mount from ballos", migration
  requires no data movement.
- **Diskless hypervisors (joast/zote/j2)** are the hard case: their store is
  an immutable netboot image, so a VM update would mean rebuild+reboot of the
  host image. Options, in order of preference:
  1. give them a scratch-disk-backed writable store overlay (the netboot
     module already formats scratch disks; `star` uses
     `formatFirstAvailableDisk`) so VM closures can be `nix copy`ed from
     ballos without reboot;
  2. use microvm's per-VM store disk image (`storeDiskType = "erofs"`) living
     on the NFS mount, so the host closure only needs qemu + runner;
  3. accept image-rebuild+reboot per VM change (fine for slow-moving VMs like
     builders).
  Decide when we get to milestone M6 with real measurements; don't block the
  ballos-local phases on it.

## 8. Milestones

Each is a complete, deployable, working unit; order within a wave is flexible.

- **M0 — inventory** *(done 2026-07-25)*: create `inventory.nix` (supersedes
  `assignments.nix`, which stays until wg leftovers are cleaned): machines
  (explicit addresses) + vms (name-hash-derived addresses), the hash/address
  functions, collision + reserved-range assertions. Wire into `specialArgs`.
  No behavior change. Since grown: per-NIC lease/DNS data
  (`lan.mac`/`lan.extra.<label>`).
- **M0.5 — appliance adoption** *(done 2026-07-26)*: Terranix + RouterOS
  provider models for the CCR2004, CRS326, and CRS305 (§3), imported until
  `tofu plan` was an empty diff. Cleanups applied through the tooling: IPv6
  `wan`→`attwan` pool fix (LAN v6 works again), HE-tunnel remnants deleted,
  stray DHCP network destroyed, netwatch entries named. The provider carries
  a local patch for its blackhole read bug (presence-flag misparse; upstream
  filing pending). Bonus landed early: inventory-generated static leases +
  `.lan`/`<label>.<host>.lan` DNS records for the physical fleet (the old
  router's dead `.lan` feature, resurrected declaratively — see §4), with
  bond MACs pinned to hardware in joast/ballos host configs so leases hold
  across netboots.
- **M1 — fabric on ballos** *(done 2026-07-26)*: `modules/vm-host.nix` —
  VM route/nftables generation from inventory, tailscale advertises
  `10.42.0.0/16` + the ULA /64 (approved in the console), CCR carries the
  inventory-generated `VM_NET` route. Deployed and verified live
  (vmpolicy chains, forwarding, tap catchall w/ ConfigureWithoutCarrier).
- **M2 — microvm scaffolding + first VM** *(done 2026-07-26)*: flake input,
  `vm-guest.nix` base profile, `microvm.vms` generated from inventory
  placement in `vm-host.nix`, `vms/flippyflops/` as the canary. Live:
  `dots.turb.io` → nginx → `10.42.85.220:3001`, egress default-deny
  verified by the drop counters. Lessons folded into the base profile:
  bind services to 0.0.0.0 inside guests (specific-ip binds race networkd),
  `Restart=always`, guest ntp off (kvm-clock tracks the chrony-synced
  host). Known wart for M4: stateless guests regenerate ssh host keys every
  rebuild — persist them once per-VM state datasets exist. Next stateless
  candidates identified: pushgateway (zero policy needs), ping exporter
  (first `egress = true`), snmp exporter (needs a raw-cidr/iot selector for
  `192.168.50.1`).
- **M3 — DNS** *(in progress)*: internal resolver (on ballos first, then as
  `vms/ns/`), generated forward+reverse zones, CCR forwarder records,
  tailscale split DNS, `*.int.turb.io` added to the cert, public hack record
  removed. Landed so far: unbound on ballos (explicit binds — wildcard :53
  collides with resolved's stub + podman's aardvark), CCR FWD records,
  `_acme-challenge.int.turb.io` writable zone, cert SAN config. Incident
  learnings baked in: the CCR's RDNSS relayed the *BGW's* resolver to all
  v6 clients (silently bypassing internal zones — surfaced by a ballos
  reboot resetting resolved's sticky server choice), now disabled;
  **queued follow-up: proper v6 DNS advertisement** — RDNSS-only RA from
  the resolver itself on a ULA, rather than relying on v4 fallback. LAN
  servers set `--accept-dns=false` (magicdns's `~.` claim captures `.lan`
  and int names into public DNS). **Queued follow-up: roaming clients** —
  itoh can't resolve `int.turb.io` (observed 2026-07-29); laptops/desktops
  need the *opposite* posture from servers (accept-dns on, split DNS
  actually reaching them, stale RA-learned resolver state from the
  BGW-RDNSS era flushed). Goal: any client, home or roaming, resolves int
  names and reaches exposed services over the advertised `10.42.0.0/16`
  route. **Vhost-only int names are dead** (found 2026-07-31): flow/prow/
  rad/son/see/bt.int.turb.io have been NXDOMAIN since M3 removed the
  public `*.int.turb.io` wildcard — unbound only serves inventory-derived
  records. Deferred by choice (turbio: "for now lets just drop those
  vhost names"); candidate fix when it matters: generate A records from
  the host's `*.int.turb.io` nginx vhosts. Related footgun (2026-07-31):
  when internal resolution misses
  (e.g. ccr FWD records pending an appliance apply for new vms), int
  names fall through to public DNS where the `*.turb.io` wildcard answers
  with the edge IPs — silently wrong instead of NXDOMAIN. Confirmed
  2026-07-31 via roaming itoh: the tailscale console has NO split-dns
  route for int.turb.io (despite M3 notes) — the fix for every roaming
  client is the console entry `int.turb.io -> 100.100.57.46` (ballos;
  console state, not repo-manageable until headscale).
- **M4 — stateful pattern**: per-VM dataset + virtiofs recipe; migrate
  **evaldb** (tiny state) then **vibes** (media dir). Sanoid covers
  `tank/enc/vms`.
- **M5 — leases, mgmt tier, `.lan` retirement**: generated static DHCP
  leases for physical machines; the CCR's copper ports split into the `mgmt`
  bridge/subnet with iLO/iDRAC/PDU/pi gear renumbered into it (and the
  ipmi-exporter/SNMP/PDU scrape targets in ballos's prometheus config updated
  from inventory); nginx/prometheus/mounts move to `int.turb.io` names.
  Requires M0.5.
- **M6 — second hypervisor**: `vm-host.nix` on joast (or zote), NFS-backed
  state, diskless-store decision (§7), generated per-host CCR routes for
  multi-host, then **prove migration** by moving flippyflops back and forth.
- **M7+ — service backlog** (each its own self-contained task; roughly
  easiest-first and dependency-ordered):

  | wave | service | notes from inventory |
  |---|---|---|
  | early | flippyflops, evaldb, vibes | done in M2/M4 |
  | early | ollama | dropped instead — unused on ballos/zote (itoh's desktop ROCm instance stays) |
  | done | pushgateway, ping exporter, snmp exporter | cut over; ping runs host *and* vm permanently for perf comparison; snmp.yml moved to `vms/snmpexp/` |
  | done | forgejo (+ssh :22 via edge dnat) | cut over 2026-07-30 with data; bootstrap/agenix-in-guest superseded by host-delivered secrets; host copy at `/tank/enc/forgejo` on the destroy ledger |
  | done | buildbot (master+worker+postgres, one vm) | cut over 2026-07-30; builds run in-vm (writable store overlay on a blk volume, no /dev/kvm); host-delivered secrets mechanism born here; old `buildbot` db in ballos postgres on the ledger |
  | done | grafana, loki | cut over (grafana socket→tcp behind the vhost, state + db-uid rewrite done; host `/var/lib/grafana` + `tank/enc/loki` kept as fallbacks for now); promtail-in-guest-base still open |
  | stage-2 parked | prometheus | vm live with migrated tsdb + pinned instance labels; host instance deliberately kept running as a warm backup (turbio, 2026-07-31) — cutover on turbio's call: flip grafana's default datasource, retire host prometheus + its 9090 machine grants, destroy `tank/prometheus` + the `tank/enc/prometheus` corpse |
  | done | cgit | cut over 2026-07-31 in one step (stateless, reads the same live dataset); first readOnly dataset mount |
  | done | syncthing | vm added 2026-08-28; folders ride virtiofs at their host paths (`tank/enc/{misc,photos,code,webcamlog}`) so config paths carry over, sqlite index (1.4G) on a blk volume per the storage policy. first vm to hold an *identity* secret: cert/key are `secrets/syncthing-{cert,key}.age`, so the device id survives the move and no peer re-pairs; gui password is a secret too, which is what lets the panel be a plain tailnet-reachable `syncthing.int.turb.io` instead of an ip-allowlisted vhost. found while moving it: peers had been dialling `tcp://<ballos tailscale ip>:22000` and nothing had synced since the pool moved to joast — they now dial the vm's address over the advertised `10.42.0.0/16` |
  | mid | immich | own postgres+redis in-VM; `tank/enc/immich`; ML container CPU-only initially |
  | late | akvorado | already podman — lift the whole compose into one VM; flow ingest UDP needs `lan` ingress policy |
  | late | cgit | reads `tank/enc/git` read-only — nice test of ro shares |
  | late | nginx + acme | last: the ingress VM. Needs rfc2136 secret, `tank/enc/http` + nixcache root (or nixcache becomes its own VM), nginxlog exporter follows the log. Edges then DNAT to the ingress VM's address |
  | special | pixiecore/pixiectrl | proxyDHCP needs L2 on the LAN → this VM uniquely gets a bridged NIC, and hypervisors must not netboot-depend on a VM they host. Do late, carefully — or leave on ballos metal permanently |
  | blocked | dex, colotop, fins | not in the repo today (colotop runs from `/tmp`); nixify first, then vmize |
  | n/a | webcam archive | it's an rsync timer over tank data — stays a host unit |

- **M-side — dynamic tenant tier (deferred until core milestones settle)**:
  friend-VMs and other pet instances don't fit the inventory model (dynamic
  by nature), so they get a bounded imperative enclave: **incus** on the
  hypervisors — NixOS module + `preseed` for pools/networks/projects, the
  `terraform-provider-incus` (in nixpkgs-unstable) through our existing
  terranix/tofu root for the declared skeleton, per-project `restricted`
  tokens for tenants, instances on `routed` NICs named `vm-*` out of a
  reserved dynamic slice (e.g. `10.42.240.0/20`, per-host /24s) so the
  existing vmpolicy + route generation apply unchanged. Storage: zfs-driver
  pool on `tank/incus` (+ incus stateDir on tank so the ballos↔joast swap
  stays cheap); diskless hosts get NFS-backed `dir` pools until they grow
  disks. Multi-machine as independent *remotes*, not a cluster (raft wants
  3 always-on members; ours netboot and nap). microvm.nix remains the
  engine for our own services — flake-native closures, atomic host+guest
  deploys; incus is for tenants. A minimal alternative if scope stays "one
  friend, one vm": ssh forced-command menu over a microvm/qemu unit, no new
  daemon at all.
- **M8 — external IPv6 (deferred stage)**: bind the PD pool's /64 to the VM
  tier, per-VM GUA = same name-hash, AAAA in public DNS for exposed services, CCR v6
  forward chain generated from the same policy matrix. Watch out: AT&T PD is
  not guaranteed stable → GUA records must be generated, never hand-written.

## 9. Prior art

The design above is an assembly of proven patterns, not an invention. Closest
neighbors, and what to borrow from each:

- **[C3D2 / Zentralwerk](https://gitea.c3d2.de/c3d2/nix-config)** (Dresden
  hackerspace, ~60 microvms across a few hypervisors, very active) — the
  strongest match. A central net registry flake maps hostname → addresses;
  `modules/microvm.nix` derives each VM's NICs/MACs/static config from which
  nets its hostname appears in; knot forward+reverse zones are generated from
  the same data (via dns.nix); placement is literally
  `c3d2.deployment.server = "server10"` and the host autostarts every flake
  config whose attr matches — our "move = edit one attr" model, deployed at
  scale. Deltas from us: they bridge per-VLAN instead of routing /32s (so
  isolation is VLAN-level, not per-VM), storage is hypervisor-local ZFS
  (`microvm-zfs-datasets@` template unit — steal this), and dataset moves on
  migration are manual (our NFS-from-tank approach removes that step).
- **[microvm.nix routed-network chapter](https://github.com/microvm-nix/microvm.nix/blob/main/doc/src/routed-network.md)**
  — the manual documents exactly our §2: per-VM tap with /32+/128 host routes,
  numeric never-reused VM index deriving addresses, and the rationale (bridged
  VMs can spoof MAC/ARP/DHCP). Validates the fabric design; also `tap.vhost =
  true` for throughput. (Repo moved to the `microvm-nix` org, active.)
- **[oddlama/nix-config](https://github.com/oddlama/nix-config)** +
  [nixos-extra-modules](https://github.com/oddlama/nixos-extra-modules) —
  service-per-microvm homelab whose `globals.nix` is the best inventory
  precedent: hosts get a numeric `id`, `lib.net.cidr.host id cidr` computes
  addresses, and DHCP reservations, wireguard meshes, DNS rewrites, and
  cross-node firewall openings (consumer-declared, materialized on the other
  node) all regenerate from it. Uses
  [thelegy/nixos-nftables-firewall](https://github.com/thelegy/nixos-nftables-firewall)
  (zone-based nftables DSL) — a strong candidate to build our §4 policy engine
  on instead of hand-rolling rule generation.
- **[Flying Circus](https://github.com/flyingcircusio/fc-nixos)** — the one
  production/institutional instance of the whole stack: NixOS hypervisors,
  addressing pulled from a central directory into eval, default-deny generated
  firewall, network storage (Ceph RBD) making `fc.qemu` migration a placement
  change. Validates "network storage + config-driven placement"; their
  two-tier frontend/server-net policy model is a simpler fallback if per-VM
  matrices get tedious.
- **[skyflake](https://github.com/astro/skyflake)** — Nomad-scheduled
  microvm.nix on Ceph; the only dynamic-scheduling story in the ecosystem,
  dormant since 2024. Reinforces our choice of static placement in Nix.
- **Router-side**: [nix-routeros](https://github.com/aleks-sidorenko/nix-routeros)
  (Nix → Terranix → RouterOS Terraform provider; one host entry generates
  static lease + DNS record) and
  [mikrotik.nix](https://discourse.nixos.org/t/mikrotik-nix-declaratively-manage-routeros-configuration/78900)
  are prior art for the appliance management adopted in §3 — the Terraform
  provider route is sturdier than hand-rolled `.rsc` over ssh.
- **DNS**: [dns.nix](https://github.com/kirelagin/dns.nix) (zones as Nix
  attrsets, used by C3D2) is the obvious building block for §3;
  [NixOS-DNS](https://github.com/Janik-Haag/NixOS-DNS) shows records derived
  from service configs across a fleet.
- Smaller reusable ideas: Spectrum OS's netvm/per-VM /31 links,
  extra-container's `addressPrefix` veth pattern,
  [ipam.nix](https://github.com/fooker/ipam.nix) (early-stage IPAM data model,
  reference only).

Notably, no project unifies inventory → addresses + forward/reverse DNS +
routes + per-VM policy + storage placement; everyone hand-assembles the same
stack. So `inventory.nix` is ours to own, but every consumer of it has a
working precedent.

## 10. Risks / open questions

- **Appliance convergence**: Terraform-provider coverage of RouterOS is broad
  but not total — anything the provider can't express (e.g. the netwatch
  failover scripts) stays as an imported/opaque blob or a documented manual
  step. Verify coverage of the failover machinery early in M0.5, and treat
  lockout risk per §3's safety rules.
- **virtiofs-over-NFS performance** for remote stateful VMs — measure before
  committing immich/postgres-class workloads off-ballos; zvol+iSCSI is the
  escape hatch.
- **ballos SPOF deepens**: DNS, storage, ingress, netboot all root there. The
  on-host resolver fallback (M3) and keeping hypervisor-critical paths off
  the VM layer are the mitigations; true HA is out of scope.
- **`egress = true` is too blunt** (turbio, 2026-07-31): immich, forgejo,
  buildbot, and pingexp all hold full-internet egress when their real needs
  are a handful of destinations (webhooks to our own edges, huggingface
  model pulls, substituters, probe targets). The policy engine should grow
  a narrower egress shape — per-destination allows are hard at the
  nftables layer for FQDNs, so likely: document exact needs per vm, then
  either dns-resolved sets, an egress proxy vm, or at minimum
  port-restricted egress (443-only etc). Revisit before adding more
  egress-y vms.
- **Netboot hosts can't hold secrets**: joast/zote/j2 regenerate ssh host
  keys every boot, so they can't be stable age recipients (they're already
  excluded from `userpassword.age`). VMs sidestep this via host-delivered
  secrets (`/run/host-secrets`, inventory `secrets` list); metal netboot
  secret delivery is still open — needs persisted identities (local disk,
  TPM, or host-delivery from the netboot server).
- **Tailscale console state** (ACLs, split DNS, subnet route approval) can't
  be fully repo-managed without moving to headscale or the TS API — accept
  manual console steps, but document each in the repo as they're made.
  Console steps taken so far: approved ballos's advertised subnet routes
  (`10.42.0.0/16` + `fd53:d7e:fb6d:42::/64`, 2026-07-26). **Eventually: try
  headscale** — self-hosting the coordination server would pull ACLs, route
  approvals, and split DNS into this repo like everything else (it'd fit the
  vm-per-service model as its own vm, though bootstrapping order matters:
  the overlay shouldn't depend on a vm that needs the overlay to reach).
- **`hosts/vm` placeholder + `tests/ballos-vm.nix`** should grow with this:
  each `vms/<name>` gets a boot test in `checks`, cheap CI insurance.
