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

      peers = map
        ({ ip, pubkey, endpoint ? null }: {
          publicKey = pubkey;
          allowedIPs = [ "10.100.0.0/24" ];
          endpoint = if endpoint == null then null else "${endpoint}:51820";
        })
        (attrValues (removeAttrs assignments.vpn [ hostname ]));
    };
  };
}
