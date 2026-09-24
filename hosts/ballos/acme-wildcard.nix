{
  domain,
  extraNames ? [ ],
}:
{
  config,
  pkgs,
  inventory,
  ...
}:
let
  # rfc2136 updates go to the acme-dns master (aackle) over tailscale, by
  # address — a bare magicdns name here broke when accept-dns went off
  dnsServer = "${inventory.machines.aackle.tailscale.ip4}:53";
in
{
  security.acme.certs."${domain}" = {
    email = "acme@turb.io";
    webroot = null;
    group = "nginx";
    extraDomainNames = [ "*.${domain}" ] ++ extraNames;
    dnsProvider = "rfc2136";
    environmentFile = pkgs.writeText "acme-rfc2136-${domain}" ''
      RFC2136_NAMESERVER='${dnsServer}'
      RFC2136_TSIG_FILE='${config.age.secrets."rfc2136-acme".path}'
    '';

    dnsPropagationCheck = true;

    dnsResolver = "8.8.8.8";
  };
}
