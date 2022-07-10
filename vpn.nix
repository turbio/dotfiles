{ pkgs, hostname, lib, ... }:
let
  assignments = import ./assignments.nix;
  self = assignments.vpn.${hostname};
  is_server = hasAttr "endpoint" self;
in
with builtins;
{
  boot.kernel.sysctl."net.ipv4.ip_forward" =
    lib.mkIf is_server 1;

  networking.wireguard.interfaces = {
    wg0 = {
      ips = [ "${self.ip}/24" ];
      listenPort = 51820;

      privateKeyFile = "/home/turbio/.wgpkey";

      postSetup = lib.mkIf is_server ''
        ${pkgs.iptables}/bin/iptables -t nat -A POSTROUTING -s 10.100.0.0/24 -o wg0 -j MASQUERADE
      '';
      postShutdown = lib.mkIf is_server ''
        ${pkgs.iptables}/bin/iptables -t nat -D POSTROUTING -s 10.100.0.0/24 -o wg0 -j MASQUERADE
      '';


      peers =
        if hasAttr "endpoint" self then
          (map
            ({ ip, pubkey, endpoint ? null }: {
              publicKey = pubkey;
              allowedIPs = [ "${ip}/32" ];
              endpoint = if endpoint == null then null else "${endpoint}:51820";
            })
            (attrValues (removeAttrs assignments.vpn [ hostname ])))
        else
          (map
            ({ ip, pubkey, endpoint }: {
              publicKey = pubkey;
              allowedIPs = [ "${ip}/32" ];
              endpoint = "${endpoint}:51820";
              persistentKeepalive = 25;
            })
            (filter (hasAttr "endpoint") (attrValues (removeAttrs assignments.vpn [ hostname ]))));
    };
  };
}
