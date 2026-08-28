# Every lan-resident machine holds a /32 route to every vm it doesn't host,
# via the vm's hosting machine — so machine↔vm traffic takes the normal
# direct lan path in both directions instead of the reply leg hairpinning
# through the ccr. The ccr keeps its aggregate vm-net route as the fallback
# tier for devices that can't hold routes (phones, pdus) and machines that
# haven't picked up their routes yet; vm hairpin replies there ride the raw
# notrack rule (appliances/ccr2004.nix).
#
# Applied to every host; no-ops off-lan (edges reach vms over tailscale via
# the advertised subnet route instead). v4 only for now — v6 policy/routing
# is still on the ledger (PLAN.md M3 follow-ups).
#
# proto 201 marks the routes ours so the sync can flush stale ones.
{
  lib,
  inventory,
  hostname,
  pkgs,
  ...
}:
let
  me = inventory.machines.${hostname} or null;
  onLan = me != null && me ? lan && me.lan ? ip4;

  routedVms = lib.filterAttrs (
    _: vm: vm.host != hostname && inventory.machines.${vm.host} ? lan
  ) inventory.vms;
in
{
  config = lib.mkIf (onLan && routedVms != { }) {
    systemd.services.vm-remote-routes = {
      wantedBy = [ "multi-user.target" ];
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = ''
        ${pkgs.iproute2}/bin/ip route flush proto 201 || true
        ${lib.concatStrings (
          lib.mapAttrsToList (
            name: vm:
            "${pkgs.iproute2}/bin/ip route replace ${vm.addr.ip4}/32 via ${
              inventory.machines.${vm.host}.lan.ip4
            } proto 201\n"
          ) routedVms
        )}
      '';
    };
  };
}
