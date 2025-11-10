{ pkgs, ... }:
let
  domain = "turb.io";
  zonepath = "/var/db/bind/${domain}.zone";
  zonefile = pkgs.writeText "_acme-challenge.turb.io.zone" ''
    _acme-challenge.turb.io. 300 IN SOA ns1.turb.io. hostmaster.turb.io. 1 21600 3600 259200 300
    _acme-challenge.turb.io. 300 IN NS ns1.turb.io.
  '';
  dnskeypath = "/var/lib/secrets/dnskeys.conf";
in
{
  networking.firewall.enable = true;
  networking.firewall.allowedTCPPorts = [
    80
    443
    23
  ];

  networking.nftables = {
    enable = true;
    ruleset = ''
      table ip vpn {
        chain prerouting {
          type nat hook prerouting priority -100;
          iifname "eth0" tcp dport { 80, 443, 23 } dnat to 100.100.57.46
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

  systemd.tmpfiles.rules = [
    "d /var/db/bind 0750 named named - -"
  ];

  system.activationScripts."init-zone-${domain}".text = ''
    if [ ! -e "${zonepath}" ]; then
      install -o named -g named -m 0644 ${zonefile} "${zonepath}"
    fi
  '';

  networking.firewall.allowedUDPPorts = [ 53 ];
  services.bind = {
    enable = true;

    extraConfig = ''
      include "${dnskeypath}";
    '';

    zones."_acme-challenge.${domain}" = {
      file = zonepath;
      master = true;
      extraConfig = "allow-update { key rfc2136key.${domain}.; };";
    };

    zones."turb.io" = {
      master = true;
      file = ../../zones/turb.io.zone;
    };

    zones."masonclayton.com" = {
      master = true;
      file = ../../zones/masonclayton.com.zone;
    };
  };

  systemd.services.dns-rfc2136-conf = {
    requiredBy = ["bind.service"];
    before = ["bind.service"];
    unitConfig = {
      ConditionPathExists = "!${dnskeypath}";
    };
    serviceConfig = {
      Type = "oneshot";
      UMask = 0077;
    };
    path = [ pkgs.bind ];
    script = ''
      mkdir -p /var/lib/secrets
      chmod 755 /var/lib/secrets
      tsig-keygen rfc2136key.${domain} > ${dnskeypath}
      chown named:root ${dnskeypath}
      chmod 400 ${dnskeypath}
    '';
  };
}
