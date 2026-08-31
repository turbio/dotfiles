{ pkgs, inventory, ... }: {
  boot.tmp.cleanOnBoot = true;
  zramSwap.enable = true;
  networking.hostName = "spooky";
  networking.domain = "";
  services.openssh.enable = true;
  users.users.root.openssh.authorizedKeys.keys = [''ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIONmQgB3t8sb7r+LJ/HeaAY9Nz2aPS1XszXTub8A1y4n'' ];
  system.stateVersion = "21.05"; # Did you read the comment?
  services.tailscale.enable = true;

  networking.firewall.enable = true;
  networking.firewall.allowedTCPPorts = [
    22
    80
    443
  ];

  networking.nftables = {
    enable = true;
    ruleset = ''
      table ip vpn {
        chain prerouting {
          type nat hook prerouting priority -100;
          iifname "enX0" tcp dport { 22, 80, 443 } dnat to ${inventory.machines.joast.tailscale.ip4}
        }

        chain postrouting {
          type nat hook postrouting priority 100;
          #iifname "enX0" tcp dport { 80, 443 } snat to ${inventory.machines.joast.tailscale.ip4}
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
