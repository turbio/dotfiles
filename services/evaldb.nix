# ingress for evaldb, which runs in its own vm (vms/evaldb).
{ inventory, ... }:
{
  services.nginx.virtualHosts."evaldb.turb.io" = {
    forceSSL = true;
    useACMEHost = "turb.io";

    locations."/" = {
      proxyPass = "http://${inventory.vms.evaldb.addr.ip4}:3005";
      extraConfig = ''
        proxy_set_header Host $host;
      '';
    };

    extraConfig = ''
      proxy_http_version 1.1;
      chunked_transfer_encoding off;
      proxy_buffering off;
      proxy_cache off;
    '';
  };
}
