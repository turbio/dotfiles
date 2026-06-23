{
  config,
  pkgs,
  lib,
  ...
}:
let
  internalIp = (import ../../assignments.nix).vpn.internal;
  gitDir = config.zfs.pools.tank.datasets."enc/git".mountpoint;
in
{
  imports = [
    ../../modules/zfs-datasets.nix
    ../../services/turbio-index.nix
    ../../services/flippyflops.nix
    ../../services/evaldb.nix
    ../../services/forgejo.nix
    ../../services/nix-builders.nix
    #../../services/gerrit.nix
    ../../services/netboot_host.nix
    ./ipmi.nix
    (import ./acme-wildcard.nix { domain = "turb.io"; })
    (import ./acme-wildcard.nix { domain = "turbi.ooo"; })
    (import ./acme-wildcard.nix { domain = "masonclayton.com"; })
    (import ./acme-wildcard.nix { domain = "nice.meme"; })
    (import ./acme-wildcard.nix { domain = "molters.xyz"; })
    (import ../../services/vibes {
      mediaRoot = "/tank/enc/vibes";
      domain = "vibes.turb.io";
      useACMEHost = "turb.io";
    })
    # (import ../../services/vibes {
    #   mediaRoot = "/tank/enc/vibes";
    #   domain = "nice.meme";
    #   pageTitle = "nice meme";
    #   useACMEHost = "nice.meme";
    #   extraHead = ''
    #     <script async src="https://www.googletagmanager.com/gtag/js?id=G-6E4JY4KNSC"></script>
    #     <script>
    #       window.dataLayer = window.dataLayer || [];
    #       function gtag(){dataLayer.push(arguments);}
    #       gtag('js', new Date());
    #       gtag('config', 'G-6E4JY4KNSC');
    #     </script>
    #   '';
    # })
  ];

  users.users.turbio = {
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPaSIYZYHcTVrctash3bTrayw2D4psofDHsbGZH3BxLP iphone" # TODO(turbio): key management
    ];
  };

  environment.enableAllTerminfo = true; # test

  zfs.pools.tank.datasets = {
    "enc/media" = {
      perms.owner = "jellyfin";
      perms.group = "media";
      perms.mode = "775";
      properties.sync = "standard";
      properties.sharenfs = "rw=@100.100.0.0/16:192.168.0.0/16,async";
    };
    "enc/jellyfin" = {
      perms.owner = "jellyfin";
      perms.group = "media";
      perms.mode = "775";
      properties.sync = "standard";
      properties.sharenfs = "rw=@100.100.0.0/16:192.168.0.0/16,async";
    };
    "enc/photos" = {
      properties.sync = "standard";
      properties.sharenfs = "rw=@100.100.0.0/16:192.168.0.0/16,async";
    };
    "enc/git" = {
      perms.owner = "git";
      perms.group = "git";
      perms.mode = "750";
    };
  };

  users.users.git = {
    isSystemUser = true;
    group = "git";
    home = gitDir;
    createHome = false;
  };
  users.groups.git = { };

  environment.etc.gitconfig.text = ''
    [safe]
      directory = *
  '';

  services.cgit.default = {
    group = "git";
    enable = true;
    scanPath = "${gitDir}/repositories";
    nginx.virtualHost = "git.turb.io";

    gitHttpBackend.enable = true;
    gitHttpBackend.checkExportOkFiles = false;

    settings = {
      enable-git-config = 1;
      remove-suffix = 1;
      enable-index-owner = 0;
      logo = "";
      root-title = "turbio git";
      clone-url = "https://git.turb.io/$CGIT_REPO_URL";
    };
  };
  services.nginx.virtualHosts."git.turb.io" = {
    forceSSL = true;
    useACMEHost = "turb.io";
    http2 = true;
  };

  services.nginx.virtualHosts."jelly.turb.io" = {
    forceSSL = true;
    useACMEHost = "turb.io";
    http2 = true;

    extraConfig = ''
      resolver 127.0.0.53;
      set $jellyfin_url "http://mote.lan:8096";
    '';

    locations."/" = {
      extraConfig = ''
        proxy_pass $jellyfin_url;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header X-Forwarded-Protocol $scheme;
        proxy_set_header X-Forwarded-Host $http_host;

        proxy_buffering off;
      '';
    };
    locations."/socket" = {
      extraConfig = ''
        proxy_pass $jellyfin_url;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header X-Forwarded-Protocol $scheme;
        proxy_set_header X-Forwarded-Host $http_host;
      '';
    };
  };
  services.nginx.virtualHosts."prow.int.turb.io" = {
    extraConfig = ''
      allow ${internalIp};
      deny all;
      resolver 127.0.0.53;
      set $u "http://mote.lan:9696";
    '';
    locations."/".proxyPass = "$u";
  };
  services.nginx.virtualHosts."rad.int.turb.io" = {
    extraConfig = ''
      allow ${internalIp};
      deny all;
      resolver 127.0.0.53;
      set $u "http://mote.lan:7878";
    '';
    locations."/".proxyPass = "$u";
  };
  services.nginx.virtualHosts."son.int.turb.io" = {
    extraConfig = ''
      allow ${internalIp};
      deny all;
      resolver 127.0.0.53;
      set $u "http://mote.lan:8989";
    '';
    locations."/".proxyPass = "$u";
  };
  services.nginx.virtualHosts."see.int.turb.io" = {
    extraConfig = ''
      allow ${internalIp};
      deny all;
      resolver 127.0.0.53;
      set $u "http://mote.lan:5055";
    '';
    locations."/".proxyPass = "$u";
  };
  services.nginx.virtualHosts."bt.int.turb.io" = {
    extraConfig = ''
      allow ${internalIp};
      deny all;
      resolver 127.0.0.53;
      set $u "http://mote.lan:9472";
    '';
    locations."/" = {
      extraConfig = ''
        proxy_set_header Host $host;
      '';
      proxyPass = "$u";
    };
  };

  services.nginx.virtualHosts."nice.meme" = {
    http2 = true;
    forceSSL = true;
    useACMEHost = "nice.meme";
    root = ./nice.meme;
    extraConfig = ''
      error_page 404 = @fsfallback;
      charset utf-8;
    '';

    locations."@fsfallback" = {
      root = "/tank/enc/http/$host";
      extraConfig = ''
        try_files $uri @spafallback;
      '';
    };
    locations."@spafallback" = {
      extraConfig = ''
        try_files /index.html =404;
      '';
    };

    locations."/tessa" = {
      root = "/nix/store/9pi7db2qa4a4zk7zrjq6907gi3lp5dlf-source";
      extraConfig = ''
        rewrite  ^/tessa/(.*) /$1 break;
        autoindex on;
      '';
    };

    locations."/reddit/" = {
      proxyPass = "http://127.0.0.1:8080/";
    };
    locations."= /reddit" = {
      return = "302 /reddit/";
    };
  };
  services.nginx.virtualHosts."*.nice.meme" = {
    http2 = true;
    forceSSL = true;
    useACMEHost = "nice.meme";
    root = ./nice.meme;
    extraConfig = ''
      error_page 404 =200 /index.html;
      charset utf-8;
    '';
  };

  services.nginx.virtualHosts."turbi.ooo" = {
    forceSSL = true;
    useACMEHost = "turbi.ooo";
    root = pkgs.writeTextDir "index.html" ''
      wow

      what a deal
    '';
    extraConfig = ''
      error_page 404 = @fsfallback;
    '';
    locations."@fsfallback" = {
      root = "/tank/enc/http/$host";
      extraConfig = ''
        try_files $uri =404;
      '';
    };
  };

  services.nginx.virtualHosts."masonclayton.com" = {
    forceSSL = true;
    useACMEHost = "masonclayton.com";
    root = pkgs.writeTextDir "index.html" ''
      heyo
    '';
    extraConfig = ''
      error_page 404 = @fsfallback;
    '';
    locations."@fsfallback" = {
      root = "/tank/enc/http/$host";
      extraConfig = ''
        try_files $uri =404;
      '';
    };
  };

  services.nginx.virtualHosts."molters.xyz" = {
    forceSSL = true;
    useACMEHost = "molters.xyz";
    extraConfig = ''
      resolver 127.0.0.53;
      set $zote_url "http://zote.lan";
    '';
    locations."/" = {
      extraConfig = ''
        proxy_pass $zote_url;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection $connection_upgrade;
      '';
    };
  };
  services.nginx.virtualHosts."*.molters.xyz" = {
    forceSSL = true;
    useACMEHost = "molters.xyz";
    extraConfig = ''
      resolver 127.0.0.53;
      set $zote_url "http://zote.lan";
    '';
    locations."/" = {
      extraConfig = ''
        proxy_pass $zote_url;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection $connection_upgrade;
      '';
    };
  };

  users.users.jellyfin = {
    isSystemUser = true;
    group = "media";
    uid = 996;
  };
  users.groups.media = {
    gid = 994;
  };

  users.users.molters = {
    isSystemUser = true;
    group = "molters";
    uid = 1100;
    home = "/tank/enc/molters";
  };
  users.groups.molters = {
    gid = 1100;
  };

  networking.nat = {
    enable = true;
    internalInterfaces = [
      "ve-*"

      # tailscale0 needs masquerade for peers using ballos as an exit node
      "tailscale0"
    ];
    externalInterface = "bond0";
    enableIPv6 = true;
  };

  networking.wireguard.enable = true;
  networking.wireguard.interfaces = { };

  zfs.pools.tank.datasets = {
    "enc/misc" = {
      properties.sync = "disabled";
      properties.sharenfs = "rw=@100.100.0.0/16:192.168.0.0/16,async";
    };
    "enc/ollama" = {
      properties.sync = "disabled";
    };
    "enc/molters" = {
      properties.sync = "standard";
      properties.sharenfs = "rw=@192.168.0.0/16,async,no_root_squash";
      perms.owner = "molters";
      perms.group = "molters";
      perms.mode = "750";
    };
  };

  zfs.pools.tank.datasets."enc/ollama" = {
    perms.group = "ollama";
    perms.mode = "775";
  };

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

  nix.settings.system-features = [
    "gccarch-armv7-a"
  ];
  boot.binfmt.emulatedSystems = [
    # "aarch64-linux"
    "armv7l-linux"
    "i686-linux"
  ];

  security.acme.acceptTerms = true;

  services.nginx.virtualHosts."nixcache.turb.io" = {
    addSSL = true;
    useACMEHost = "turb.io";

    root = "/tank/enc/nixcache";

    locations."/nar/" = {
      extraConfig = ''
        open_file_cache          max=1000 inactive=20s;
        open_file_cache_valid    30s;
        open_file_cache_min_uses 2;
        open_file_cache_errors   on;
      '';
    };

    extraConfig = ''
      sendfile on;
      tcp_nopush on;
      tcp_nodelay on;

      keepalive_timeout 65;
      keepalive_requests 1000;

      gzip off;

      autoindex off;
    '';
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
      "tank/enc/misc" = {
        hourly = 24;
        daily = 30;
        monthly = 12;

        autosnap = true;
        autoprune = true;
      };
      "tank/enc/code" = {
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
    ruleset = "";
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
  };

  services.nginx = {
    defaultListenAddresses = [
      "100.100.57.46"
      "[fd7a:115c:a1e0::2233:392e]"
      "0.0.0.0"
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
      allow 192.168.0.0/16;
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

    configDir = "/tank/enc/misc/config";
    dataDir = "/tank/enc/misc";
    settings.folders = {
      "photos" = {
        enable = true;
        path = "/tank/enc/photos";
      };
      "code" = {
        enable = true;
        path = "/tank/enc/code";
      };
      "notes" = {
        enable = true;
        path = "/tank/enc/misc/notes";
      };
      "ios_photos" = {
        enable = true;
        path = "/tank/enc/misc/ios_photos";
      };
      "clips" = {
        enable = true;
        path = "/tank/enc/misc/clips";
      };
      "webcamlog" = {
        enable = true;
        path = config.zfs.pools.tank.datasets."enc/webcamlog".mountpoint;
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

    provision.datasources.settings.datasources = [
      {
        name = "Loki";
        type = "loki";
        uid = "loki";
        url = "http://127.0.0.1:${toString config.services.loki.configuration.server.http_listen_port}";
        isDefault = false;
      }
    ];

    provision.dashboards.settings.providers = [
      {
        name = "NixOS";
        options.path = pkgs.linkFarm "grafana-dashboards" [
          {
            name = "node-exporter-full.json";
            path = ./node_exporter_full.json;
          }
          {
            name = "nginx-logs.json";
            path = pkgs.writeText "nginx-logs.json" (
              builtins.toJSON {
                title = "Nginx Logs";
                uid = "nginx-logs";
                editable = false;
                panels = [
                  {
                    type = "logs";
                    title = "Access Logs";
                    gridPos = {
                      x = 0;
                      y = 0;
                      w = 24;
                      h = 20;
                    };
                    datasource = {
                      type = "loki";
                      uid = "loki";
                    };
                    targets = [
                      {
                        expr = ''{syslog_identifier="nginx"}'';
                        refId = "A";
                      }
                    ];
                    options = {
                      showTime = true;
                      showLabels = true;
                      wrapLogMessage = true;
                      sortOrder = "Descending";
                      enableLogDetails = true;
                    };
                  }
                ];
                templating.list = [ ];
                time = {
                  from = "now-1h";
                  to = "now";
                };
                refresh = "5s";
              }
            );
          }
        ];
      }
    ];
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

  zfs.pools.tank.datasets = {
    "enc/webcamlog" = { };
    "enc/webcamlog-archive" = { };
  };
  systemd.timers."auto-archive-webcam" = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "daily";
      Unit = "auto-archive-webcam.service";
    };
  };
  systemd.services.auto-archive-webcam = {
    path = [
      pkgs.rsync
    ];
    serviceConfig.Type = "oneshot";
    script = ''
      rsync -av \
        ${config.zfs.pools.tank.datasets."enc/webcamlog".mountpoint}/ \
        ${config.zfs.pools.tank.datasets."enc/webcamlog-archive".mountpoint} \
        --exclude=".*" \
        --remove-source-files
    '';
  };

  systemd.services.fanspeed = {
    enable = true;
    wantedBy = [ "multi-user.target" ];
    path = [
      pkgs.ipmitool
      pkgs.bc
      pkgs.bash
      pkgs.lm_sensors
      pkgs.gawk
    ];
    serviceConfig = {
      User = "root";
      ExecStart = "${pkgs.bash}/bin/bash ${./fan_speed.sh} --disengage-temp 80 --target-temp 60 --verbose-log";
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
          {
            targets = [ "127.0.0.1:${toString config.services.prometheus.exporters.node.port}" ];
            labels = {
              host = "ballos";
            };
          }
          {
            targets = [ "mote.lan:9100" ];
            labels = {
              host = "mote";
            };
          }
          {
            targets = [ "aackle:9100" ];
            labels = {
              host = "aackle";
            };
          }
          {
            targets = [ "backle:9100" ];
            labels = {
              host = "backle";
            };
          }
          {
            targets = [ "cackle:9100" ];
            labels = {
              host = "cackle";
            };
          }
          {
            targets = [ "zote.lan:9100" ];
            labels = {
              host = "zote";
            };
          }
          {
            targets = [ "j1.lan:9100" ];
            labels = {
              host = "j1";
            };
          }
          {
            targets = [ "j2.lan:9100" ];
            labels = {
              host = "j2";
            };
          }
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

  zfs.pools.tank.datasets."enc/loki" = {
    perms.owner = "loki";
    perms.group = "loki";
    perms.mode = "750";
  };

  services.loki = {
    enable = true;
    dataDir = config.zfs.pools.tank.datasets."enc/loki".mountpoint;
    configuration = {
      auth_enabled = false;
      server.http_listen_port = 3100;

      ingester = {
        lifecycler = {
          address = "127.0.0.1";
          ring = {
            kvstore.store = "inmemory";
            replication_factor = 1;
          };
          final_sleep = "0s";
        };
        chunk_idle_period = "5m";
        chunk_retain_period = "30s";
      };

      schema_config.configs = [
        {
          from = "2025-01-01";
          store = "tsdb";
          object_store = "filesystem";
          schema = "v13";
          index = {
            prefix = "index_";
            period = "24h";
          };
        }
      ];

      storage_config = {
        tsdb_shipper = {
          active_index_directory = "${config.zfs.pools.tank.datasets."enc/loki".mountpoint}/tsdb-index";
          cache_location = "${config.zfs.pools.tank.datasets."enc/loki".mountpoint}/tsdb-cache";
        };
        filesystem.directory = "${config.zfs.pools.tank.datasets."enc/loki".mountpoint}/chunks";
      };

      limits_config = {
        reject_old_samples = true;
        reject_old_samples_max_age = "168h";
      };

      compactor = {
        working_directory = "${config.zfs.pools.tank.datasets."enc/loki".mountpoint}/compactor";
        compactor_ring.kvstore.store = "inmemory";
        retention_enabled = false;
      };
    };
  };

  services.postgresql.package = pkgs.postgresql_16;

  services.buildbot-nix.master = {
    enable = true;
    domain = "buildbot.turb.io";
    workersFile = pkgs.writeText "buildbot-workers.json" (
      builtins.toJSON [
        {
          name = "ballos";
          pass = "password";
          cores = 32;
        }
      ]
    );
    useHTTPS = true;
    authBackend = "gitea";
    admins = [ "turbio" ];
    gitea = {
      enable = true;
      instanceUrl = "https://forge.turb.io";
      oauthId = "buildbot";
      oauthSecretFile = config.age.secrets."forgejo-oauth-secret".path;
      tokenFile = "/var/lib/forgejo-bootstrap/api-token";
      webhookSecretFile = config.age.secrets."forgejo-webhook-secret".path;
    };
    buildSystems = [
      "x86_64-linux"
      #"aarch64-linux"
    ];
    branches.all.matchGlob = "*";
    evalWorkerCount = 4;
  };

  services.buildbot-nix.worker = {
    enable = true;
    workerPasswordFile = pkgs.writeText "buildbot-worker-password" "password";
  };

  systemd.services.buildbot-master = {
    after = [ "forgejo-bootstrap.service" ];
    requires = [ "forgejo-bootstrap.service" ];
    # Any change to forgejo's settings restarts buildbot-master. The
    # preStart then blanks the gitea-project-cache so the reload scheduler
    # refetches `ssh_url` etc. from the live API — otherwise a stale cached
    # URL makes the SingleBranchScheduler's repository filter miss incoming
    # webhooks (see buildbot_nix/project_config.py and gitea_projects.py).
    restartTriggers = [
      (builtins.toJSON config.services.forgejo.settings)
    ];
    serviceConfig.ExecStartPre = [
      "${pkgs.coreutils}/bin/rm -f /var/lib/buildbot/gitea-project-cache.json"
    ];
  };

  # Worker should track master — if master restarts, worker reconnects.
  # On deploy, `systemctl restart buildbot-master` alone used to leave the
  # worker stopped; bind them so the worker comes back automatically.
  systemd.services.buildbot-worker = {
    after = [ "buildbot-master.service" ];
    bindsTo = [ "buildbot-master.service" ];
  };

  services.nginx.virtualHosts."buildbot.turb.io" = {
    forceSSL = true;
    useACMEHost = "turb.io";
  };

  services.promtail = {
    enable = true;
    configuration = {
      server = {
        http_listen_port = 9080;
        grpc_listen_port = 0;
      };
      clients = [ { url = "http://127.0.0.1:3100/loki/api/v1/push"; } ];
      scrape_configs = [
        {
          job_name = "journal";
          journal = {
            max_age = "12h";
            labels.job = "systemd-journal";
          };
          relabel_configs = [
            {
              source_labels = [ "__journal__systemd_unit" ];
              target_label = "unit";
            }
            {
              source_labels = [ "__journal_syslog_identifier" ];
              target_label = "syslog_identifier";
            }
            {
              source_labels = [ "__journal__hostname" ];
              target_label = "hostname";
            }
            {
              source_labels = [ "__journal_priority_keyword" ];
              target_label = "level";
            }
          ];
        }
      ];
    };
  };
}
