{ domain }: { pkgs, ... }: {
  networking.firewall.allowedUDPPorts = [ 53 ];

  security.acme.certs."${domain}" = {
    webroot = null;
    extraDomainNames = [ "*.${domain}" ];
    dnsProvider = "rfc2136";
    environmentFile = pkgs.writeText "TODO-get-these-secrets-out" ''
      RFC2136_NAMESERVER='balrog:53'
      RFC2136_TSIG_ALGORITHM='hmac-sha256.'
      RFC2136_TSIG_KEY='rfc2136key.${domain}'
      RFC2136_TSIG_SECRET='ybxDkTw666VBlp6GYd/kkLobCf6dIjA46Ft2JKmwbaQ='
    '';

    dnsPropagationCheck = true;
  };
}
