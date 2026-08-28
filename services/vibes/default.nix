# ingress for vibes, which runs in its own vm (vms/vibes). the host's nginx
# serves the webroot + media statics straight off the pool (it's trusted and
# local to tank); only /c/ round-trips through the vm.
{
  mediaRoot,
  domain,
  pageTitle ? "vibes",
  useACMEHost ? domain,
  extraHead ? "",
}:
{
  pkgs,
  inventory,
  ...
}:
let
  webroot = pkgs.linkFarm "vibes-webroot" [
    {
      name = "index.html";
      path = pkgs.replaceVars ./webroot/index.html {
        inherit pageTitle extraHead;
      };
    }
  ];
in
{
  services.nginx.virtualHosts."${domain}" = {
    inherit useACMEHost;
    forceSSL = useACMEHost != null;

    locations."/" = {
      root = webroot;
      index = "index.html";
    };

    locations."/c/" = {
      proxyPass = "http://${inventory.vms.vibes.addr.ip4}:3010";
    };

    locations."/media/" = {
      root = "${mediaRoot}";
    };

    extraConfig = ''
      charset utf-8;
    '';
  };
}
