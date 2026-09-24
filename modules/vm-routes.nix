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
      # TODO(turbio): proto 201 marks the routes ours??? wat
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
