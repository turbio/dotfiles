{ pkgs, ... }: {
  networking.firewall.enable = true;
  networking.firewall.allowedTCPPorts = [
    80
    443
  ];

  networking.nftables = {
    enable = true;
    ruleset = ''
      table ip vpn {
        chain prerouting {
          type nat hook prerouting priority -100;
          iifname "enp0s6" tcp dport { 80, 443 } dnat to 100.100.57.46
        }

        chain postrouting {
          type nat hook postrouting priority 100;
          #iifname "enp0s6" tcp dport { 80, 443 } snat to 100.100.57.46
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
