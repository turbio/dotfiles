# ingress for flippyflops, which runs in its own vm (vms/flippyflops).
{ inventory, ... }:
{
  services.nginx.virtualHosts."dots.turb.io" = {
    forceSSL = true;
    useACMEHost = "turb.io";

    locations."/" = {
      proxyPass = "http://${inventory.vms.flippyflops.addr.ip4}:3001";
    };

    extraConfig = ''
      proxy_http_version 1.1;
      chunked_transfer_encoding off;
      proxy_buffering off;
      proxy_cache off;
    '';
  };
}
