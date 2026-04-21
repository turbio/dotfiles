{
  config,
  pkgs,
  ...
}:
{
  services.gerrit = {
    enable = true;
    listenAddress = "[::]:8081";
    serverId = "4a822bf8-22c9-49ce-a1ce-e78b853c0cea";

    builtinPlugins = [
      "download-commands"
      "webhooks"
    ];

    settings = {
      gerrit.canonicalWebUrl = "https://cl.turb.io/";
      auth.type = "DEVELOPMENT_BECOME_ANY_ACCOUNT";
      sshd.listenAddress = "*:29418";
    };
  };

  services.nginx.virtualHosts."cl.turb.io" = {
    forceSSL = true;
    useACMEHost = "turb.io";
    http2 = true;

    locations."/" = {
      proxyPass = "http://[::1]:8081";
      extraConfig = ''
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
      '';
    };
  };

  networking.firewall.allowedTCPPorts = [ 29418 ];
}
