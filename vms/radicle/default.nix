# radicle seed node (radicle.turb.io): p2p on 8776 for other nodes, and the
# http api + explorer web ui on :80 behind joast's radicle.turb.io vhost.
#
# the node's identity is the host-delivered `radicle-key` secret (an
# unencrypted openssh ed25519 key made with `rad auth`); its public half is
# pinned below so the node id is a property of the repo, not of /var:
#   did:key:z6MkmgfLPL4FiuDTEZPz4kGKXiqz64nfQUs7Zwd7gMNN7Vwt
# repos are seeded on request only (`rad-system seed <rid>` inside the vm);
# the default policy blocks anything unsolicited from landing in storage.
{ pkgs, ... }:
let
  domain = "radicle.turb.io";
  httpdPort = 8080;

  # the explorer is a static spa configured at build time; point it at
  # ourselves so the landing page lists this seed's repos rather than the
  # upstream radicle seeds
  explorer = pkgs.radicle-explorer.withConfig {
    preferredSeeds = [
      {
        hostname = domain;
        port = 443;
        scheme = "https";
      }
    ];
  };
in
{
  services.radicle = {
    enable = true;

    privateKeyFile = "/run/host-secrets/radicle-key";
    publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGtwsU3E2I3kqpEcAKODpZjjbV3+2JZOm7KFdsyfgk4/ radicle";

    # node.listenAddress/listenPort default to [::]:8776; the guest firewall
    # and the host's vmpolicy open it from the inventory expose list
    httpd = {
      enable = true;
      listenAddress = "127.0.0.1";
      listenPort = httpdPort;
    };

    settings = {
      # links the cli prints (rad inspect etc.) point at our own explorer
      publicExplorer = "https://${domain}/nodes/$host/$rid$path";
      node = {
        alias = domain;
        # advertised to peers; also flips relay=auto on, making this a
        # proper public seed. the edges dnat public :8776 here
        externalAddresses = [ "${domain}:8776" ];
        # allow-list seeding: only repos explicitly `rad seed`ed are stored
        seedingPolicy.default = "block";
      };
      # preferredSeeds is left at the built-in default (the radicle.xyz
      # bootstrap nodes) so we discover the rest of the network
    };
  };

  # one origin for the browser: the spa at /, the httpd api and git
  # smart-http underneath it. httpd owns /api, /raw and /<rid>/... (git
  # fetch for `git clone https://radicle.turb.io/rad:z...`); everything else
  # is an spa route
  services.nginx = {
    enable = true;
    recommendedProxySettings = true;
    recommendedGzipSettings = true;

    virtualHosts.${domain} = {
      default = true;
      listen = [
        {
          addr = "0.0.0.0";
          port = 80;
        }
      ];

      root = explorer;

      locations = {
        "/".extraConfig = ''
          try_files $uri $uri/ /index.html;
        '';
        "/api/".proxyPass = "http://127.0.0.1:${toString httpdPort}";
        "/raw/".proxyPass = "http://127.0.0.1:${toString httpdPort}";
        "~ ^/rad:".proxyPass = "http://127.0.0.1:${toString httpdPort}";
      };
    };
  };

  microvm.balloon = true;
}
