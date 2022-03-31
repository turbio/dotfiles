{ pkgs, hostname, ... }:
let
  assignments = import ./assignments.nix;
  self = assignments.vpn.${hostname};
in
with builtins;
{
  networking.wireguard.interfaces = {
    wg0 = {
      ips = [ "${self.ip}/24" ];
      listenPort = 51820;

      privateKeyFile = "/home/turbio/.wgpkey";

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
