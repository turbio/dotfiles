{ repos, config, pkgs, ... }: {
  environment.systemPackages = with pkgs; [
    libraspberrypi
    bluez
  ];

  services.openssh.enable = true;

  networking.networkmanager.enable = true;
  networking.firewall.enable = false;

  users.groups.gpio = { };

  services.prometheus = {
    enable = true;
    port = 9090;
    listenAddress = "127.0.0.1";
    retentionTime = "1y";

    scrapeConfigs = [
      {
        job_name = "vanio";
        scrape_interval = "1s";
        static_configs = [{
          targets = [ "127.0.0.1:3000" ];
        }];
      }
      {
        job_name = "nodexporter";
        static_configs = [{
          targets = [ "127.0.0.1:${toString config.services.prometheus.exporters.node.port}" ];
        }];
      }
    ];

    exporters = {
      node = {
        enable = true;
        enabledCollectors = [ "systemd" ];
        listenAddress = "127.0.0.1";
        port = 9092;
      };
    };
  };

  users.groups.grafana.members = [ "nginx" ]; # so nginx can poke grafan's socket
  services.grafana = {
    enable = true;
    settings.server = {
      socket = "/run/grafana/grafana.sock";
      domain = "graph.turb.io";
      protocol = "socket";
      root_url = "http://graph.turb.io/";
    };
    provision.datasources.settings = {
      apiVersion = 1;

      datasources = [{
        name = "Prometheus";
        type = "prometheus";
        url = "http://${config.services.prometheus.listenAddress}:${toString config.services.prometheus.port}";
        uid = "prom";
      }];
    };

    provision.dashboards.settings = {
      apiVersion = 1;

      providers = [{
        name = "default";
        type = "file";
        updateIntervalSeconds = 60;
        options.path = ./dashboards;
      }];

    };
  };

  security.acme.defaults.email = "letsencrypt@turb.io";
  security.acme.acceptTerms = true;

  services.nginx.enable = true;
  services.nginx.virtualHosts = {
    "graph.turb.io" = {
      addSSL = true;
      enableACME = true;
      locations."/" = {
        proxyPass = "http://unix:/${config.services.grafana.settings.server.socket}";
        extraConfig = ''
          proxy_set_header Host $host;
        '';

      };
    };
  };
  services.nginx.virtualHosts = {
    "ctrl.turb.io" = {
      addSSL = true;
      enableACME = true;

      locations."/" = {
        proxyPass = "http://127.0.0.1:3000";
      };

      locations."/ws" = {
        proxyPass = "http://127.0.0.1:3000";
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

  systemd.services = {
    ctrl = {
      description = "the actual point of this device";
      wantedBy = [ "multi-user.target" ];

      wants = [ "network-online.target" ];
      after = [ "network-online.target" ];

      serviceConfig = {
        ExecStart = (pkgs.writeShellScript "start-ctrl" ''
          ${pkgs.bash}/bin/bash ${./ctrl/setupgpio.sh}
          ${repos.ctrl.packages.${pkgs.system}.ctrl}/bin/ctrl
        '');
        MemoryLimit = "512M";
        RestartSec = "60s";
        Restart = "on-failure";
      };
    };
  };
}
