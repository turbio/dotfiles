{ inventory, ... }:
let
  ballosTs4 = inventory.machines.joast.tailscale.ip4;
  ballosTs6 = inventory.machines.joast.tailscale.ip6;
  forgejo = inventory.vms.forgejo.addr;
in
{
  # accept ballos's advertised vm-tier subnet routes (10.42.0.0/16 + ula):
  # vms reach edges over tailscale (e.g. prometheus scraping edge node
  # exporters) and the forgejo dnat below targets a vm address; without the
  # routes the edge can't deliver either
  services.tailscale.extraSetFlags = [ "--accept-routes" ];

  networking.firewall.enable = true;
  networking.firewall.allowedTCPPorts = [
    22
    80
    443
    23
  ];

  networking.nftables = {
    enable = true;
    # Port 22 from the public internet goes to the forgejo vm's built-in SSH
    # (2222), riding the advertised vm subnet route over tailscale.
    # Tailscale-direct SSH to ballos (ballos:22) keeps going to the system
    # sshd — forge.turb.io resolves via public DNS even from the tailnet, so
    # `git@forge.turb.io` naturally rides this DNAT. http/https/23 still
    # land on ballos (nginx).
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
