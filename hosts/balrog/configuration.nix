{ ... }: {
  networking.firewall.enable = true;
  networking.firewall.allowedTCPPorts = [ 80 443 ];

  networking.nftables = {
    enable = true;
    ruleset = ''
      table ip vpn {
        #chain im_already_tracer {
        #  type filter hook prerouting priority raw - 1; policy accept;
        #  tcp dport { 80, 443 } meta nftrace set 1
        #}

        chain prerouting {
            type nat hook prerouting priority -100;
            iifname "eth0" tcp dport { 80, 443 } dnat to 10.100.0.10;
        }

        chain postrouting {
          type nat hook postrouting priority 100;
          iifname "eth0" tcp dport { 80, 443 } snat to 10.100.0.128;
        }
      }
    '';
  };
}
