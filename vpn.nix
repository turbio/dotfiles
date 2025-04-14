{
  assignments,
  pkgs,
  hostname,
  lib,
  ...
}:
let
  self = assignments.vpn.hosts.${hostname};
  reachable = self ? "endpoint";
  will_route = self ? "router" && self.router == true;
in
{
  boot.kernel.sysctl."net.ipv4.ip_forward" = lib.mkIf will_route 1;
  networking.extraHosts =
    assignments.vpn.hosts
    |> lib.mapAttrsToList (name: { ip, ... }: "${ip} ${name}\n")
    |> lib.concatStrings;

  # todo(turbio): needed???????
  networking.firewall.allowedUDPPorts = lib.mkIf reachable [ 51820 ];

  # todo(turbio): move thise somwhere else
  systemd.network.wait-online.ignoredInterfaces = [ "wg0" ];
  systemd.network.wait-online.anyInterface = true;

  networking.interfaces.wg0.mtu = 1300;
  networking.wireguard.interfaces = {
    wg0 = {
      mtu = 1420;
      ips = [ "${self.ip}/24" ];
      listenPort = lib.mkIf reachable 51820;
      privateKeyFile = "/home/turbio/.wgpkey"; # TODO: state
      postSetup = lib.mkIf will_route ''
        ${pkgs.iptables}/bin/iptables -t nat -A POSTROUTING -s 10.100.0.0/24 -o wg0 -j MASQUERADE
      '';
      postShutdown = lib.mkIf will_route ''
        ${pkgs.iptables}/bin/iptables -t nat -D POSTROUTING -s 10.100.0.0/24 -o wg0 -j MASQUERADE
      '';

      peers =
        removeAttrs assignments.vpn.hosts [ hostname ]
        |> builtins.attrNames
        |> map (n: { hostname = n; } // builtins.getAttr n assignments.vpn.hosts)
        |> map (
          {
            hostname,
            ip,
            pubkey,
            router ? false,
            endpoint ? null,
          }:
          {
            publicKey = pubkey;
            allowedIPs = [
              (if router then assignments.vpn.subnet else "${ip}/32")
            ];
            endpoint = if endpoint != null then "${endpoint}:51820" else "${hostname}.local:51820";
            persistentKeepalive = 25;
            dynamicEndpointRefreshSeconds = 30;
          }
        );
    };
  };
}
