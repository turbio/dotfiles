{ ... }:
{
  networking.firewall.enable = true;
  networking.firewall.allowedTCPPorts = [
    22
    80
    443
    23
  ];

  networking.nftables = {
    enable = true;
    # Port 22 from the public internet is redirected to ballos's forgejo SSH
    # port (2222). Tailscale-direct SSH to ballos (ballos:22) keeps going to
    # the system sshd — forge.turb.io resolves via public DNS even from the
    # tailnet, so `git@forge.turb.io` naturally rides this DNAT.
    ruleset = ''
      table ip vpn {
        chain prerouting {
          type nat hook prerouting priority -100;
          iiftype ether tcp dport 22 dnat to 100.100.57.46:2222
          iiftype ether tcp dport { 80, 443, 23 } dnat to 100.100.57.46
        }

        chain postrouting {
          type nat hook postrouting priority 100;
          oifname "tailscale0" masquerade
        }
      }

      table ip6 vpn {
        chain prerouting {
          type nat hook prerouting priority -100;
          iiftype ether tcp dport 22 dnat to [fd7a:115c:a1e0::2233:392e]:2222
          iiftype ether tcp dport { 80, 443, 23 } dnat to fd7a:115c:a1e0::2233:392e
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
