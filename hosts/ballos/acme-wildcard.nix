{ domain }:
let
  dnsServer = "aackle:53";
in
{ config, pkgs, ... }:
{
  security.acme.certs."${domain}" = {
    email = "acme@turb.io";
    webroot = null;
    group = "nginx";
    extraDomainNames = [ "*.${domain}" ];
    dnsProvider = "rfc2136";
    environmentFile = pkgs.writeText "acme-rfc2136-${domain}" ''
      RFC2136_NAMESERVER='${dnsServer}'
      RFC2136_TSIG_FILE='${config.age.secrets."rfc2136-acme".path}'
    '';

    dnsPropagationCheck = true;

    dnsResolver = "8.8.8.8";
  };
}
