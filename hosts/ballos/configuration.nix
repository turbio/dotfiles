{
  config,
  pkgs,
  lib,
  ...
}:
let
  internalIp = (import ../../assignments.nix).vpn.internal;
in
{
  imports = [
    ../../modules/zfs-datasets.nix
    ../../services/turbio-index.nix
    ../../services/flippyflops.nix
    ../../services/evaldb.nix
    ../../services/netboot_host.nix
    ./ipmi.nix
    (import ./acme-wildcard.nix { domain = "turb.io"; })
    (import ../../services/vibes.nix { mediaRoot = "/tank/enc/vibes"; domain = "vibes.turb.io"; })
  ];

  environment.enableAllTerminfo = true;

  zfs.pools.tank.datasets = {
    "enc/media" = {
      perms.owner = "jellyfin";
      perms.group = "media";
      perms.mode = "775";
      properties.sync = "standard";
    };
    "enc/jellyfin" = {
      perms.owner = "jellyfin";
      perms.group = "media";
      perms.mode = "775";
      properties.sync = "standard";
    };
    "enc/photos" = {
      properties.sync = "standard";
      properties.sharenfs = "rw=@100.100.0.0/16:192.168.0.0/16,async";
    };
  };

  services.nginx.virtualHosts."jelly.turb.io" = {
    forceSSL = true;
    useACMEHost = "turb.io";
    http2 = true;

    locations."/" = {
      proxyPass = "http://${config.containers.jellyfin.localAddress}:8096";
    };
  };
  services.nginx.virtualHosts."see.int.turb.io" = {
    extraConfig = ''
      allow ${internalIp};
      deny all;
    '';
    locations."/" = {
      proxyPass = "http://${config.containers.jellyfin.localAddress}:5055";
    };
  };
  services.nginx.virtualHosts."son.int.turb.io" = {
    extraConfig = ''
      allow ${internalIp};
      deny all;
    '';
    locations."/" = {
      proxyPass = "http://${config.containers.jellyfin.localAddress}:8989";
    };
  };
  services.nginx.virtualHosts."rad.int.turb.io" = {
    extraConfig = ''
      allow ${internalIp};
      deny all;
    '';
    locations."/" = {
      proxyPass = "http://${config.containers.jellyfin.localAddress}:7878";
    };
  };
  services.nginx.virtualHosts."prow.int.turb.io" = {
    extraConfig = ''
      allow ${internalIp};
      deny all;
    '';
    locations."/" = {
      proxyPass = "http://${config.containers.jellyfin.localAddress}:9696";
    };
  };
  services.nginx.virtualHosts."bt.int.turb.io" = {
    extraConfig = ''
      allow ${internalIp};
      deny all;
    '';
    locations."/" = {
      extraConfig = ''
        proxy_set_header Host $host;
      '';
      proxyPass = "http://${config.containers.jellyfin.localAddress}:9472";
    };
  };

  users.users.jellyfin = {
    isSystemUser = true;
    group = "media";
    uid = 996;
  };
  users.groups.media = { gid = 994; };

  # container traffic -> internet
  # tbh we should quarantine this off to it's own interface
  networking.nat = {
    enable = true;
    internalInterfaces = ["ve-*"];
    externalInterface = "enp4s0";
    enableIPv6 = true;
  };

  containers.jellyfin = {
    ephemeral = true;
    autoStart = true;
    privateNetwork = true;
    hostAddress = "192.168.100.10";
    localAddress = "192.168.100.11";
    privateUsers = "pick";
    bindMounts = {
      "/media" = {
        mountPoint = "/media:idmap"; # nasty hax (https://github.com/NixOS/nixpkgs/issues/329530)
        hostPath = "/tank/enc/media";
        isReadOnly = false;
      };
      "/persist" = {
        mountPoint = "/persist:idmap";
        hostPath = "/tank/enc/jellyfin";
        isReadOnly = false;
      };
    };
    config = { ... }: {
      imports = [
        (import ../../services/jelly.nix {
          internalIp = internalIp;
          userId = config.users.users.jellyfin.uid;
          groupId = config.users.groups.media.gid;
          persistDataDir = "/persist";
        })
      ];

      networking.firewall = {
        enable = true;
        allowedTCPPorts = [
          8096 # jellyfin
          9472 # qbittorrent
          9696 # prowlarr
          5055 # seerr
          7878 # radarr
          8989 # sonarr
        ];
      };
      networking.useHostResolvConf = false;
      services.resolved.enable = true;
    };
  };

  networking.wireguard.enable = true;
  networking.wireguard.interfaces = {
    # "wg0" is the network interface name. You can name the interface arbitrarily.
    wg0 = {
      ips = [ "10.100.1.2/24" ];
      listenPort = 51820; # to match firewall allowedUDPPorts (without this wg uses random port numbers)
      allowedIPsAsRoutes = false;

      # postSetup = ''
      #   ${ip} rule add from 10.100.1.0/24 lookup 100
      #   ${ip} route add default dev wg0 table 100
      # '';

      # postShutdown = ''
      #   ${ip} rule del from 10.100.1.0/24 lookup 100
      #   ${ip} route del default dev wg0 table 100
      # '';

      privateKeyFile = "/root/wireguard-keys/private";

      peers = [
        {
          publicKey = "SnuLTHTNwJuW/7VHMcLLTPUOFhyZaTbpLtSTnrd3zwE=";
          allowedIPs = [ "0.0.0.0/0" ];
          endpoint = "185.216.68.61:51820";
          persistentKeepalive = 25;
        }
      ];
    };

    wg1 = {
      ips = [ "10.100.2.2/24" ];
      allowedIPsAsRoutes = false;

      privateKeyFile = "/root/wireguard-keys2/private";

      peers = [
        {
          publicKey = "NFxVkrIsKcW7Wp9ToLmwC4l1di1sXf+uZ3ipG9rq3X4=";
          allowedIPs = [ "0.0.0.0/0" ];
          endpoint = "185.216.68.66:51820";
          persistentKeepalive = 25;
        }
      ];
    };

    wg3 = {
      ips = [ "10.100.3.2/24" ];
      allowedIPsAsRoutes = false;

      privateKeyFile = "/root/wireguard-keys-wg3/private";

      peers = [
        {
          publicKey = "Ig1QRX9Brp1rTPRCYMbVFx2x6v1EyVmszVTm71XOITw=";
          allowedIPs = [ "0.0.0.0/0" ];
          endpoint = "144.202.10.83:51820";
          persistentKeepalive = 25;
        }
      ];
    };

    wg4 = {
      ips = [ "10.100.4.2/24" ];
      allowedIPsAsRoutes = false;

      privateKeyFile = "/root/wireguard-keys-wg4/private";

      peers = [
        {
          publicKey = "hjuO1aj0chglToYOGFSpQTcJs1BNeRr5hvrvAVyomxo=";
          allowedIPs = [ "0.0.0.0/0" ];
          endpoint = "167.172.206.235:51820";
          persistentKeepalive = 25;
        }
      ];
    };
  };

  systemd.network.networks."10-wg4" = {
    matchConfig.Name = "wg4";
    networkConfig = {
      Address = "10.100.4.2/24";
    };
    routes = [
      {
        Table = "204";
        Destination = "0.0.0.0/0";
      }
    ];
    routingPolicyRules = [
      {
        From = "10.100.4.0/24";
        Table = "204";
      }
    ];
  };

  systemd.network.networks."10-wg" = {
    matchConfig.Name = "wg0";
    networkConfig = {
      Address = "10.100.1.2/24";
    };
    routes = [
      {
        Table = "123";
        Destination = "0.0.0.0/0";
      }
    ];
    routingPolicyRules = [
      {
        From = "10.100.1.0/24";
        Table = "123";
      }
    ];
  };

  systemd.network.networks."10-wg1" = {
    matchConfig.Name = "wg1";
    networkConfig = {
      Address = "10.100.2.2/24";
    };
    routes = [
      {
        Table = "124";
        Destination = "0.0.0.0/0";
      }
    ];
    routingPolicyRules = [
      {
        From = "10.100.2.0/24";
        Table = "124";
      }
    ];
  };

  systemd.network.networks."10-wg3" = {
    matchConfig.Name = "wg3";
    networkConfig = {
      Address = "10.100.3.2/24";
    };
    routes = [
      {
        Table = "125";
        Destination = "0.0.0.0/0";
      }
    ];
    routingPolicyRules = [
      {
        From = "10.100.3.0/24";
        Table = "125";
      }
    ];
  };

  zfs.pools.tank.datasets = {
    "enc/primary" = {
      properties.sync = "disabled";
      mountpoint = "/mnt/sync/";
    };
    "enc/ollama" = {
      properties.sync = "disabled";
    };
  };

  zfs.pools.tank.datasets."enc/ollama" = { perms.group = "ollama"; perms.mode = "775"; };
  services.ollama = {
    enable = true;
    models = config.zfs.pools.tank.datasets."enc/ollama".mountpoint;
    user = "ollama";
    group = "ollama";
    environmentVariables = {
      OLLAMA_MAX_LOADED_MODELS = "2";
      OLLAMA_NUM_PARALLEL = "5";
    };
  };

  boot.binfmt.emulatedSystems = [ "aarch64-linux" ];

  security.acme.acceptTerms = true;

  services.nix-serve = {
    enable = true;
    secretKeyFile = "/var/cache-priv-key.pem"; # TODO: state
    # secretKeyFile = "/keys/nix-cache-priv-key.pem"; # TODO: state
  };

  services.nginx.virtualHosts."nixcache.turb.io" = {
    forceSSL = true;
    useACMEHost = "turb.io";

    locations."/" = {
      proxyPass = "http://${config.services.nix-serve.bindAddress}:${toString config.services.nix-serve.port}";
      extraConfig = ''
        allow ${internalIp};
        deny all;
      '';

    };
    locations."/.well-known/acme-challenge" = {
      extraConfig = ''
        allow all;
      '';
    };
  };

  users.groups.locate = { };
  users.users.locate = {
    group = "locate";
    description = "locate Daemon user";
    isSystemUser = true;
    extraGroups = [ "users" ];
  };
  services.locate = {
    enable = true;
    pruneNames = [ ];
  };

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.firewall.enable = true;

  services.zfs.autoScrub.enable = true;
  services.sanoid = {
    enable = true;
    datasets = {
      "tank/enc/primary" = {
        hourly = 24;
        daily = 30;
        monthly = 12;

        autosnap = true;
        autoprune = true;
      };
    };
  };

  networking.nftables = {
    enable = true;
    ruleset = ''
    '';
  };

  networking.firewall.allowedUDPPorts = [
    111
    2049
    10809
    5201
  ];
  networking.firewall.allowedTCPPorts = [
    111
    2049
    10809
    5201
  ];
  services.nfs.server = {
    enable = true;
    exports = ''
      /mnt/sync 192.168.0.0/16(rw)
      /mnt/sync 100.100.0.0/16(rw)
    '';
  };

  services.nginx = {
    defaultListenAddresses = [
      "100.100.57.46"
    ];

    enable = true;

    appendConfig = ''
      worker_processes 32;
      worker_rlimit_nofile 2048;
    '';

    eventsConfig = ''
      worker_connections 1024;
    '';

    recommendedGzipSettings = true;
    recommendedZstdSettings = true;
    recommendedBrotliSettings = true;
    recommendedTlsSettings = true;
    recommendedOptimisation = true;

    # todo: breaks grafana
    # recommendedProxySettings = true;

    statusPage = true; # for prom metrics
    enableReload = true;
    appendHttpConfig = ''
      error_log stderr;
      log_format vhosts '$host $remote_addr - $remote_user [$time_local] '
                        '"$request" $status $body_bytes_sent "$http_referer" '
                        '"$http_user_agent" '
                        'rt=$request_time ';
      access_log syslog:server=unix:/dev/log vhosts;
      access_log /var/log/nginx/access.log vhosts;
    '';
  };

  # vpn internal traffic to us
  services.nginx.virtualHosts."ctrl.turb.io" = {
    forceSSL = true;
    useACMEHost = "turb.io";

    locations."/" = {
      proxyPass = "http://10.100.0.6";
      extraConfig = ''
        proxy_set_header Host $host;
      '';

    };
  };
  services.nginx.virtualHosts."graph.turb.io" = {
    forceSSL = true;
    useACMEHost = "turb.io";

    locations."/" = {
      proxyPass = "http://10.100.0.6";
      extraConfig = ''
        proxy_set_header Host $host;
      '';
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
  services.nginx.virtualHosts."ollama.int.turb.io" = {
    extraConfig = ''
      allow ${internalIp};
      deny all;
    '';
    locations."/" = {
      proxyPass = "http://127.0.0.1:11434";
    };
  };

  services.nginx.virtualHosts."sync.int.turb.io" = {
    extraConfig = ''
      allow ${internalIp};
      deny all;
    '';
    locations."/" = {
      proxyPass = "http://${config.services.syncthing.guiAddress}";
    };
  };

  services.nginx.virtualHosts."home.int.turb.io" = {
    extraConfig = ''
      allow ${internalIp};
      deny all;
    '';
    locations."/" = {
      extraConfig = ''
        resolver 127.0.0.53;
        set $ha_url "http://homeassistant.lan:8123";
        proxy_pass $ha_url;
        proxy_set_header Host $host;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection $connection_upgrade;
      '';
    };
  };

  services.syncthing = {
    enable = true;

    configDir = "/mnt/sync/config";
    dataDir = "/mnt/sync";
    settings.folders = {
      "photos" = {
        enable = true;
        path = "/tank/enc/photos";
      };
      "code" = {
        enable = true;
        path = "/mnt/sync/code";
      };
      "notes" = {
        enable = true;
        path = "/mnt/sync/notes";
      };
      "ios_photos" = {
        enable = true;
        path = "/mnt/sync/ios_photos";
      };
      "clips" = {
        enable = true;
        path = "/mnt/sync/clips";
      };
      "webcamlog" = {
        enable = true;
        path = "/tank/enc/webcamlog";
      };
    };
  };

  users.groups.grafana.members = [ "nginx" ]; # so nginx can poke grafana's socket
  services.grafana = {
    enable = true;

    settings.server = {
      socket = "/run/grafana/grafana.sock";
      root_url = "https://graf.turb.io/";
      domain = "graf.turb.io";
      protocol = "socket";
    };
  };

  virtualisation.oci-containers = lib.mkIf false {
    backend = "podman";
    containers.homeassistant = {
      volumes = [ "home-assistant:/config" ];
      environment.TZ = "America/Chicago";
      image = "ghcr.io/home-assistant/home-assistant:stable"; # Warning: if the tag does not change, the image will not be updated
      extraOptions = [
        "--network=host"
      ];
    };
  };

  services.nginx.virtualHosts = {
    "graf.turb.io" = {
      forceSSL = true;
      useACMEHost = "turb.io";

      locations."/" = {
        proxyPass = "http://unix:/${config.services.grafana.settings.server.socket}";
        extraConfig = ''
          proxy_set_header Host $host;
        '';
      };

      locations."/api/live/" = {
        proxyPass = "http://unix:/${config.services.grafana.settings.server.socket}";
        extraConfig = ''
          proxy_http_version 1.1;
          proxy_set_header Upgrade $http_upgrade;
          proxy_set_header Connection $connection_upgrade;
          proxy_set_header Host $host;
        '';
      };
    };
  };

  nixpkgs.overlays = [
    (
      final:
      {
        lib,
        buildGoModule,
        fetchFromGitHub,
        nixosTests,
        ...
      }:
      {
        prometheus-idrac-exporter = buildGoModule rec {
          pname = "idrac_exporter";
          version = "unstable-2023-06-29";

          src = fetchFromGitHub {
            owner = "mrlhansen";
            repo = "idrac_exporter";
            rev = "3b311e0e6d602fb0938267287f425f341fbf11da";
            sha256 = "sha256-N8wSjQE25TCXg/+JTsvQk3fjTBgfXTiSGHwZWFDmFKc=";
          };

          vendorHash = "sha256-iNV4VrdQONq7LXwAc6AaUROHy8TmmloUAL8EmuPtF/o=";

          patches = [ ./idrac-exporter/config-from-environment.patch ];

          ldflags = [
            "-s"
            "-w"
          ];

          doCheck = true;

          passthru.tests = { inherit (nixosTests.prometheus-exporters) idrac; };

          meta = with lib; {
            inherit (src.meta) homepage;
            description = "Simple iDRAC exporter for Prometheus";
            mainProgram = "idrac_exporter";
            license = licenses.mit;
            maintainers = with maintainers; [ codec ];
          };
        };
      }
    )

    (
      final:
      { buildGoModule, fetchFromGitHub, ... }:
      {
        prometheus-comed-exporter = buildGoModule {
          pname = "comed_exporter";
          version = "1.0";
          src = fetchFromGitHub {
            owner = "kklipsch";
            repo = "comed_exporter";
            rev = "1a90f09ceb0ebdfe09c2b307b4080d81b7d8de5f";
            hash = "sha256-oDvOp7SGz7RTWW3b74I1V3WhiNsHvO3hv01Gr4UkyiY=";
          };

          vendorHash = null;

          doCheck = false;
        };
      }
    )
  ];

  #systemd.timers."archive-webcam" = {
  #  wantedBy = [ "timers.target" ];
  #  timerConfig = {
  #    OnCalendar = "daily";
  #    Unit = "archive-webcam.service";
  #  };
  #};
  #systemd.services.archive-webcam = {
  #  path = [
  #    pkgs.rsync
  #  ];
  #  serviceConfig.Type = "oneshot";
  #  script = ''
  #    rsync -av /mnt/sync/webcamlog/ /mnt/sync/archive/webcamlog/ --exclude=".*" --remove-source-files
  #  '';
  #};

  systemd.services.fanspeed = {
    enable = true;
    wantedBy = [ "multi-user.target" ];
    path = [
      pkgs.ipmitool
      pkgs.bc
      pkgs.bash
    ];
    serviceConfig = {
      User = "root";
      ExecStart = "${pkgs.bash}/bin/bash ${./fan_speed.sh} --disengage-temp 74 --target-temp 55";
    };
  };

  systemd.services.prometheus-comed-exporter = {
    enable = true;
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.prometheus-comed-exporter}/bin/comed_exporter --address :9010";
    };
  };

  services.prometheus = {
    enable = true;
    port = 9090;
    listenAddress = "127.0.0.1";
    retentionTime = "1y";

    globalConfig = {
      scrape_interval = "1s";
    };

    pushgateway.enable = true;
    pushgateway.web.listen-address = "127.0.0.1:9091";

    scrapeConfigs = [
      {
        job_name = "flippyflops";
        scrape_interval = "5s";
        static_configs = [ { targets = [ "127.0.0.1:3001" ]; } ];
        fallback_scrape_protocol = "OpenMetricsText1.0.0";
      }
      {
        job_name = "big-ups";
        scrape_interval = "1s";
        static_configs = [
          { targets = [ "big-ups.lan:8080" ]; }
        ];
      }
      {
        job_name = "prometheus";
        scrape_interval = "5s";
        static_configs = [
          { targets = [ "127.0.0.1:9090" ]; }
        ];
      }
      {
        job_name = "reth";
        scrape_interval = "5s";
        static_configs = [
          { targets = [ "127.0.0.1:9551" ]; }
        ];
      }
      {
        job_name = "pushgateway";
        scrape_interval = "5s";
        static_configs = [
          { targets = [ config.services.prometheus.pushgateway.web.listen-address ]; }
        ];
      }
      {
        job_name = "comed_json";
        metrics_path = "/probe";
        params = {
          module = [ "comed" ];
        };
        static_configs = [
          { targets = [ "https://hourlypricing.comed.com/api?type=currenthouraverage" ]; }
        ];
        relabel_configs = [
          {
            source_labels = [ "__address__" ];
            target_label = "__param_target";
          }
          {
            source_labels = [ "__param_target" ];
            target_label = "instance";
          }
          {
            target_label = "__address__";
            replacement = "127.0.0.1:${toString config.services.prometheus.exporters.json.port}";
          }
        ];
      }
      {
        job_name = "comed";
        scrape_interval = "10s";
        static_configs = [
          { targets = [ "127.0.0.1:9010" ]; }
        ];
      }
      {
        job_name = "nodexporter";
        scrape_interval = "30s";
        static_configs = [
          { targets = [ "127.0.0.1:${toString config.services.prometheus.exporters.node.port}" ]; }
        ];
      }
      {
        job_name = "smartctl";
        scrape_interval = "1m";
        static_configs = [
          { targets = [ "127.0.0.1:${toString config.services.prometheus.exporters.smartctl.port}" ]; }
        ];
      }
      {
        job_name = "nginx";
        scrape_interval = "1s";
        static_configs = [
          { targets = [ "127.0.0.1:${toString config.services.prometheus.exporters.nginx.port}" ]; }
        ];
      }
      {
        job_name = "nginxlog";
        scrape_interval = "1s";
        static_configs = [
          { targets = [ "127.0.0.1:${toString config.services.prometheus.exporters.nginxlog.port}" ]; }
        ];
      }
      {
        job_name = "ping";
        scrape_interval = "1s";
        static_configs = [
          { targets = [ "127.0.0.1:${toString config.services.prometheus.exporters.ping.port}" ]; }
        ];
      }
      {
        job_name = "wireguard";
        scrape_interval = "5s";
        static_configs = [
          { targets = [ "127.0.0.1:${toString config.services.prometheus.exporters.wireguard.port}" ]; }
        ];
      }
      {
        job_name = "zfs";
        scrape_interval = "1m";
        static_configs = [
          { targets = [ "127.0.0.1:${toString config.services.prometheus.exporters.zfs.port}" ]; }
        ];
      }
      {
        job_name = "process";
        scrape_interval = "1m";
        static_configs = [
          { targets = [ "127.0.0.1:${toString config.services.prometheus.exporters.process.port}" ]; }
        ];
      }
    ];

    exporters = {
      process = {
        enable = true;
        settings.process_names = [
          # { name = "{{.Matches.Wrapped}} {{ .Matches.Args }}"; cmdline = [ "^/nix/store[^ ]*/(?P<Wrapped>[^ /]*) (?P<Args>.*)" ]; }
          {
            name = "{{.Comm}}";
            cmdline = [ ".+" ];
          }
        ];
        listenAddress = "127.0.0.1";
      };
      zfs = {
        enable = true;
        listenAddress = "127.0.0.1";
      };
      wireguard = {
        enable = true;
      };
      ping = {
        enable = true;
        listenAddress = "127.0.0.1";
        settings = {
          targets = [
            "8.8.8.8"
            "1.1.1.1"
            "10.100.0.1"
            "turb.io"
            "udm-se.lan"
          ];
        };
      };
      nginxlog = {
        enable = true;
        group = "nginx";
        settings = {
          namespaces = [
            {
              name = "local";
              format = ''$host $remote_addr - $remote_user [$time_local] "$request" $status $body_bytes_sent "$http_referer" "$http_user_agent" rt=$request_time'';
              source = {
                files = [ "/var/log/nginx/access.log" ];
              };
              relabel_configs = [
                {
                  target_label = "host";
                  from = "host";
                }
              ];
              histogram_buckets = [
                0.005
                0.01
                0.025
                0.05
                0.1
                0.25
                0.5
                1
                2.5
                5
                10
              ];
            }
          ];
        };
      };
      nginx = {
        enable = true;
      };
      smartctl = {
        enable = true;
      };
      json = {
        enable = true;
        configFile = pkgs.writeText "json-exporter-config" ''
          modules:
            comed:
              metrics:
              - name: comed
                type: object
                path: '{ [*] }'
                values:
                  price_per_kwh: '{ .price }'
                  millis_utc: '{ .millisUTC }'
        '';
      };
      node = {
        enable = true;
        enabledCollectors = [ "systemd" ];
        listenAddress = "127.0.0.1";
        port = 9092;
      };
    };
  };

  #boot.uki.settings.UKI.Cmdline = "init=${config.system.build.toplevel}/init ${toString config.boot.kernelParams}";
  #boot.loader.external = let arch = pkgs.stdenv.hostPlatform.efiArch; in {
  #  enable = true;
  #  installHook = pkgs.writeScript "install-bootloader" ''
  #    cp ${pkgs.systemd}/lib/systemd/boot/efi/systemd-boot${arch}.efi /efi/EFI/BOOT/BOOT${lib.toUpper arch}.EFI

  #  ''

  #    #echo ${config.system.build.uki}
  #    #cp ${config.system.build.uki}/${config.system.boot.loader.ukiFile} /efi/EFI/Linux/${config.system.boot.loader.ukiFile}
  #  ;
  #};
}
