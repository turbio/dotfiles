{
  config,
  lib,
  pkgs,
  hostname,
  ...
}:
let
  master = hostname == "aackle";

  ns1Ip = "100.64.177.49";
  ns1Host = "ns1.turb.io";
  adminEmail = "hostmaster.turb.io";

  domains = [
    "turb.io"
    "turbi.ooo"
    "masonclayton.com"
    "nice.meme"
  ];
in
{
  networking.firewall.allowedUDPPorts = [ 53 ];
  networking.firewall.allowedTCPPorts = [ 53 ];

  services.bind.extraConfig = ''
    include "${config.age.secrets."rfc2136-acme".path}";
    include "${config.age.secrets."rfc2136-xfer".path}";
  '';

  imports =
    domains
    |> lib.map (
      domain:

      let
        zonedir = "/var/db/bind/${domain}";
        zonepath = "${zonedir}/${domain}.zone";
        zonefile = pkgs.writeText "_acme-challenge.${domain}.zone" ''
          _acme-challenge.${domain}. 300 IN SOA ${ns1Host}. ${adminEmail}. 1 21600 3600 259200 300
          _acme-challenge.${domain}. 300 IN NS  ${ns1Host}.
        '';
      in
      {
        # zone file must be writable for allow-update to work
        systemd.services."init-zone-${domain}" = {
          description = "Initialize BIND zone for ${domain}";
          wantedBy = [ "bind.service" ];
          before = [ "bind.service" ];
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
          };
          script = ''
            rm -rf "${zonedir}"
            mkdir -p -m 0750 "${zonedir}"
            chown named:named "${zonedir}"
            install -o named -g named -m 0644 ${zonefile} "${zonepath}"
          '';
        };

        services.bind = {
          enable = true;

          zones."_acme-challenge.${domain}" = {
            inherit master;

            slaves = [ "key rfc2136-xfer" ];
            masters = [ "${ns1Ip} key rfc2136-xfer" ];

            file = zonepath;
            extraConfig = lib.optionalString master ''
              notify yes;
              also-notify { 100.64.52.73 key "rfc2136-xfer"; };
              allow-update { key rfc2136-acme; };
            '';
          };
        };
      }
    );
}
