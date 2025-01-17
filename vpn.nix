{ pkgs, hostname, lib, ... }:
with builtins;
let
  assignments = import ./assignments.nix;
  self = assignments.vpn.hosts.${hostname};
  is_server = hasAttr "endpoint" self;
in
{
  boot.kernel.sysctl."net.ipv4.ip_forward" = lib.mkIf is_server 1;
  networking.extraHosts =
    assignments.vpn.hosts
    |> lib.mapAttrsToList (name: { ip, ... }: "${ip} ${name}\n")
    |> lib.concatStrings;

  # needed???????
  networking.firewall.allowedUDPPorts = lib.mkIf is_server [ 51820 ];

  systemd.network.wait-online.ignoredInterfaces = [ "wg0" ];
  systemd.network.wait-online.anyInterface = true;

  networking.interfaces.wg0.mtu = 1300;
  networking.wireguard.interfaces = {
    wg0 = {
      ips = [ "${self.ip}/24" ];
      listenPort = lib.mkIf is_server 51820;

      privateKeyFile = "/home/turbio/.wgpkey"; # TODO lol

      postSetup = lib.mkIf is_server ''
        ${pkgs.iptables}/bin/iptables -t nat -A POSTROUTING -s 10.100.0.0/24 -o wg0 -j MASQUERADE
      '';
      postShutdown = lib.mkIf is_server ''
        ${pkgs.iptables}/bin/iptables -t nat -D POSTROUTING -s 10.100.0.0/24 -o wg0 -j MASQUERADE
      '';

      peers =
        if is_server then
          removeAttrs assignments.vpn.hosts [ hostname ]
          |> attrValues
          |> map
            ({ ip, pubkey, endpoint ? null }: {
              publicKey = pubkey;
              allowedIPs = [ "${ip}/32" ];
              endpoint = if endpoint == null then null else "${endpoint}:51820";
            })
        else
          removeAttrs assignments.vpn.hosts [ hostname ]
          |> attrValues
          |> filter (hasAttr "endpoint")
          |> map
            ({ ip, pubkey, endpoint }: {
              publicKey = pubkey;
              allowedIPs = [ assignments.vpn.subnet ];
              endpoint = "${endpoint}:51820";
              persistentKeepalive = 25;
              dynamicEndpointRefreshSeconds = 30;
            });
    };
  };
}
