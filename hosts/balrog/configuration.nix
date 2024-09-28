{ config, pkgs, lib, ... }: {
  imports = [
    #./flippyflops.nix
    #./grafana.nix
    #./index.nix
    #./schemeclub.nix
    #./evaldb.nix
    #./protip.nix
    #./vibes.nix
    #./photoprism.nix
    #./progress.nix
    #./factorio.nix
  ];

  networking.firewall.enable = true;
  networking.firewall.allowedTCPPorts = [ 80 443 ];

  networking.nftables = {
    enable = true;
    #ruleset = ''
    #  table ip vpn {
    #      chain prerouting {
    #          type nat hook prerouting priority -100;

    #          tcp dport { 80, 443 } meta nftrace set 1
    #          tcp dport { 80, 443 } dnat to 10.100.0.10
    #      }

    #      chain postrouting {
    #        type nat hook postrouting priority 100;
    #        ip saddr 10.100.0.10 meta nftrace set 1;
    #        ip saddr 10.100.0.10 snat to 10.128.0.2;

    #        #ip protocol tcp snat ip to 10.12.0.1-10.12.255.255:3000-4000
    #      }
    #  }
    #'';
  };

  /*
  networking.nat = {
    enable = true;
    externalInterface = "eth0";
    externalIP = "35.208.90.40";
    internalInterfaces = [ "wg0" ];
    internalIPs = [ "10.100.0.0/24" ];
    forwardPorts = [
      {
        destination = "10.100.0.10:80";
        proto = "tcp";
        sourcePort = 80;
      }
    ];
  };
  */

  security.acme.defaults.email = "letsencrypt@turb.io";
  security.acme.acceptTerms = true;

  services.nginx.appendHttpConfig = ''
    error_log stderr;
    access_log syslog:server=unix:/dev/log combined;
  '';

  #services.nginx.enable = true;
  services.nginx.virtualHosts = {
    "masonclayton.com" = {
      addSSL = true;
      enableACME = true;

      locations."/" = {
        extraConfig = ''
          return 301 https://turb.io$request_uri;
        '';
      };
    };

    "dggx.turb.io" = {
      addSSL = true;
      enableACME = true;
      locations."/" = {
        proxyPass = "http://localhost:8080";
      };
      locations."/live" = {
        proxyPass = "http://localhost:8080";
        extraConfig = ''
          proxy_set_header Host $host;
          proxy_http_version 1.1;
          proxy_set_header Upgrade $http_upgrade;
          proxy_set_header Connection "upgrade";
          proxy_read_timeout 86400;
        '';
      };
    };

    "graph.turb.io" = {
      addSSL = true;
      enableACME = true;
      acmeFallbackHost = "10.100.0.6";
      locations."/" = {
          proxyPass = "http://10.100.0.6";
          extraConfig = ''
            proxy_set_header Host $host;
          '';
      };
    };

    "ctrl.turb.io" = {
      addSSL = true;
      enableACME = true;
      acmeFallbackHost = "10.100.0.6";
      locations."/" = {
          proxyPass = "http://10.100.0.6";
      };

      locations."/ws" = {
        proxyPass = "http://10.100.0.6";
        extraConfig = ''
          proxy_set_header Host $host;
          proxy_http_version 1.1;
          proxy_set_header Upgrade $http_upgrade;
          proxy_set_header Connection "upgrade";
          proxy_read_timeout 86400;
        '';
      };
    };
  };
}
