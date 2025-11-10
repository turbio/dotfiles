{
  config,
  assignments,
  pkgs,
  hostname,
  lib,
  ...
}:
let
  self = assignments.vpn.hosts.${hostname};
  reachable = self ? "endpoint";
  will_route = self ? "router" && self.router == true;
  will_recv = hostname == "ballos"; # todo
in
{
  boot.kernel.sysctl."net.ipv4.ip_forward" = lib.mkIf will_route 1;
  networking.extraHosts =
    assignments.vpn.hosts
    |> lib.mapAttrsToList (name: { ip, ... }: "${ip} ${name}\n")
    |> lib.concatStrings;

  # todo(turbio): needed???????
  networking.firewall.allowedUDPPorts = [ 51820 ];

  # todo(turbio): move thise somwhere else
  systemd.network.wait-online.ignoredInterfaces = [ "wg0" ];
  systemd.network.wait-online.anyInterface = true;
  systemd.network.wait-online.enable = false;

  networking.nftables = {
    enable = true;
    ruleset = ''
      # holy shit bro, they're in my walls bro, they're dropping my packets
      # i'm being ganged stalked by firewalls and they have the nerve to
      # call it a "blat attack"
      table ip nat {
        chain postrouting {
          type nat hook postrouting priority srcnat; policy accept;
          udp sport 51820 udp dport 51820 fib daddr type != local \
            snat to :1024-65535 random,persistent
        }
      }
    '';
  };

  # to reply to the internet
  # anything with a src from the wg subnet 10.100.0.0/24 must go out the
  # wireguard interface no matter the dest

  systemd.network.config.routeTables = {
    wg-table = 100;
  };

  systemd.network.networks."10-wg".routes = [
    {
      Table = "wg-table";
      Gateway = "0.0.0.0";
    }
  ];

  systemd.network.networks."10-wg".routingPolicyRules = [
    {
      From = "10.100.0.0/24";
      Table = "wg-table";
    }
  ];

  networking.useNetworkd = true;
  networking.wireguard.interfaces = {
    wg0 = {
      table = "wg-table";
      mtu = 1420;
      ips = [ "${self.ip}/24" ];
      listenPort = 51820;
      # privateKeyFile = if hostname == "ballos" then "/keys/wireguard-priv-key" else "/home/turbio/.wgpkey"; # TODO: state
      privateKeyFile = "/home/turbio/.wgpkey"; # TODO: state
      allowedIPsAsRoutes = false;

      #postSetup = route_setup + "\n" +
      #  (lib.optionalString will_route ''
      #    #${pkgs.iptables}/bin/iptables -t nat -A POSTROUTING -s 10.100.0.0/24 -o wg0 -j MASQUERADE
      #  '') +
      #  (lib.optionalString will_recv ''
      #    ${ip} rule add from 10.100.0.0/24 lookup 100
      #    ${ip} route add default dev wg0 table 100
      #  '');

      #postShutdown = route_destroy + "\n" +
      #  (lib.optionalString will_route ''
      #    #${pkgs.iptables}/bin/iptables -t nat -D POSTROUTING -s 10.100.0.0/24 -o wg0 -j MASQUERADE
      #  '') +
      #  (lib.optionalString will_recv ''
      #    ${ip} rule del from 10.100.0.0/24 lookup 100
      #    ${ip} route del default dev wg0 table 100
      #  '');

      #dynamicEndpointRefreshSeconds = 30;

      peers =
        removeAttrs assignments.vpn.hosts [ hostname ]
        |> builtins.attrNames
        |> map (n: { hostname = n; } // builtins.getAttr n assignments.vpn.hosts)
        |> map (
          {
            hostname,
            ip,
            pubkey,
            router ? false,
            endpoint ? null,
          }:
          {
            publicKey = pubkey;
            allowedIPs = (if router then [ "0.0.0.0/0" ] else if will_route then [ "${ip}/32" ] else [ ]);
            endpoint = if endpoint != null && !will_route then "${endpoint}:51820" else /*if !will_route then "${hostname}.lan:51820" else*/ null;
            persistentKeepalive = 25;
            #dynamicEndpointRefreshSeconds = 30;
          }
        );
    };
  };
}
