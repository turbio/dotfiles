{ inventory, ... }:
let
  # TODO(turbio): todo don't hard code lol, should be part of inventory
  ballosTs4 = inventory.machines.joast.tailscale.ip4;
  ballosTs6 = inventory.machines.joast.tailscale.ip6;
  forgejo = inventory.vms.forgejo.addr;
in
{
  services.tailscale.extraSetFlags = [ "--accept-routes" ];

  networking.firewall.enable = true;

  # TODO(turbio): should be part of inventory
  networking.firewall.allowedTCPPorts = [
    22
    80
    443
    23
  ];

  networking.nftables = {
    enable = true;
    # TODO(turbio): should be part of inventory
    ruleset = ''
      table ip vpn {
        chain prerouting {
          type nat hook prerouting priority -100;
          iiftype ether tcp dport 22 dnat to ${forgejo.ip4}:2222
          iiftype ether tcp dport { 80, 443, 23 } dnat to ${ballosTs4}
        }

        chain postrouting {
          type nat hook postrouting priority 100;
          oifname "tailscale0" masquerade
        }
      }

      table ip6 vpn {
        chain prerouting {
          type nat hook prerouting priority -100;
          iiftype ether tcp dport 22 dnat to [${forgejo.ip6}]:2222
          iiftype ether tcp dport { 80, 443, 23 } dnat to ${ballosTs6}
        }

        chain postrouting {
          type nat hook postrouting priority 100;
          oifname "tailscale0" masquerade
        }
      }
    '';
  };

  boot.kernel.sysctl = {
    "net.ipv4.ip_forward" = true;
    "net.ipv6.conf.all.forwarding" = true;
  };
}
