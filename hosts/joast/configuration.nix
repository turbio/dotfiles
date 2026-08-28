{
  config,
  pkgs,
  lib,
  inventory,
  ...
}:
let
  internalIp = (import ../../assignments.nix).vpn.internal;
  gitDir = config.zfs.pools.tank.datasets."enc/git".mountpoint;

  mediaRoot = "/tank/enc/vibes";
  webroot = pkgs.linkFarm "vibes-webroot" [
    {
      name = "index.html";
      path = pkgs.replaceVars ../../services/vibes/webroot/index.html {
        pageTitle = "nice memes";
        extraHead = ''
          <script async src="https://www.googletagmanager.com/gtag/js?id=G-6E4JY4KNSC"></script>
          <script>
            window.dataLayer = window.dataLayer || [];
            function gtag(){dataLayer.push(arguments);}
            gtag('js', new Date());

            gtag('config', 'G-6E4JY4KNSC');
          </script>
        '';
      };
    }
  ];
in
{
  imports = [
    #../../services/netboot_host.nix - TODO
    #../../services/nix-builders.nix

    ../../modules/ipmi-exporter.nix
    ../../modules/zfs-datasets.nix
    ../../services/turbio-index.nix
    ../../services/flippyflops.nix
    ../../services/evaldb.nix
    ../../services/forgejo.nix
    #../../services/gerrit.nix
    # *.turb.io doesn't cover second-level labels; internal vhosts need the
    # explicit *.int SAN (PLAN.md §4)
    (import ./acme-wildcard.nix {
      domain = "turb.io";
      extraNames = [ "*.int.turb.io" ];
    })
    (import ./acme-wildcard.nix { domain = "turbi.ooo"; })
    (import ./acme-wildcard.nix { domain = "masonclayton.com"; })
    # dns is afraid rn
    #(import ./acme-wildcard.nix { domain = "nice.meme"; })
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

  vmhost.enable = true;
  intDns.enable = true;

  # lan-resident server: dns comes from the ccr (which forwards int zones to
  # unbound here), never from magicdns — tailscale's ~. claim would capture
  # every query and leak them to public dns (.lan breaks, int names get the
  # public wildcard hack)
  services.tailscale.extraSetFlags = [ "--accept-dns=false" ];

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

  # immich lives in vms/immich (cut over 2026-07-31, data migrated).
  # leftovers on disk, remove later (turbio): tank/enc/immich (the old
  # library — the vm's copy reflink-shares its blocks, so destroying frees
  # little until both diverge) and the `immich` db in ballos postgres.

  # cgit lives in vms/cgit (cut over 2026-07-31), reading enc/git through a
  # read-only mount; the git user/group and dataset stay host-owned here
  services.nginx.virtualHosts."git.turb.io" = {
    forceSSL = true;
    useACMEHost = "turb.io";
    http2 = true;

    locations."/" = {
      proxyPass = "http://${inventory.vms.cgit.addr.ip4}:80";
      extraConfig = ''
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-Proto $scheme;
      '';
    };
  };

  services.nginx.virtualHosts."colotop.turb.io" = {
    forceSSL = true;
    useACMEHost = "turb.io";
    http2 = true;
    locations."/".proxyPass = "http://127.0.0.1:8080";
  };

  security.acme.certs."nice.meme".email = "nicememe@nice.meme";
  security.acme.certs."www.nice.meme".email = "nicememe@nice.meme";
  services.nginx.virtualHosts."www.nice.meme" = {
    http2 = true;
    forceSSL = true;
    enableACME = true;

    locations."/" = {
      return = "302 https://nice.meme$request_uri";
    };
  };

  services.nginx.virtualHosts."nice.meme" = {
    http2 = true;
    forceSSL = true;
    enableACME = true;
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

    locations."/" = {
      root = ./nice.meme;
    };

    locations."/reddit/" = {
      proxyPass = "http://127.0.0.1:8085/";
    };

    locations."= /reddit" = {
      return = "302 /reddit/";
    };

    locations."/vids" = {
      return = "302 /vids/";
    };

    locations."/vids/" = {
      alias = "${webroot}/";
      index = "index.html";
    };

    locations."/c/" = {
      proxyPass = "http://${inventory.vms.vibes.addr.ip4}:3010/c/";
    };

    locations."/media/" = {
      alias = "${mediaRoot}/media/";
    };
  };
  #services.nginx.virtualHosts."wow.nice.meme" = {
  #  http2 = true;
  #  forceSSL = true;
  #  useACMEHost = "nice.meme";
  #  locations."/".proxyPass = "http://joast.int.turb.io:8085";
  #};
  #services.nginx.virtualHosts."*.nice.meme" = {
  #  http2 = true;
  #  forceSSL = true;
  #  useACMEHost = "nice.meme";
  #  root = ./nice.meme;
  #  extraConfig = ''
  #    error_page 404 =200 /index.html;
  #    charset utf-8;
  #  '';
  #};

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
      set $zote_url "http://zote.int.turb.io";
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
      set $zote_url "http://zote.int.turb.io";
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
    "enc/molters" = {
      properties.sync = "standard";
      properties.sharenfs = "rw=@192.168.0.0/16,async,no_root_squash";
      perms.owner = "molters";
      perms.group = "molters";
      perms.mode = "750";
    };
  };

  nix.settings.system-features = [
    "gccarch-armv7-a"
  ];
  boot.binfmt.emulatedSystems = [
    "aarch64-linux"
    "armv7l-linux"
    "i686-linux"
  ];

  security.acme.acceptTerms = true;

  services.nginx.virtualHosts."nixcache.turb.io" = {
    addSSL = true;
    useACMEHost = "turb.io";
    # the internal name (inventory dnsAliases) — lan machines substitute
    # from here directly, skipping the cloud-edge hairpin (bench
    # 2026-07-31: ~6x throughput, ~3x latency). cert SAN *.int.turb.io
    # covers it.
    serverAliases = [ "nixcache.int.turb.io" ];

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

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.firewall.enable = true;

  services.zfs.autoScrub.enable = true;
  services.sanoid = {
    enable = true;
    datasets = {
      # every stateful vm's /var (recursive picks up new vms automatically)
      "${inventory.storage.pool}/${inventory.storage.vmsDataset}" = {
        recursive = true;
        hourly = 24;
        daily = 30;
        monthly = 12;

        autosnap = true;
        autoprune = true;
      };
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
      "tank/enc/photos" = {
        hourly = 24;
        daily = 30;
        monthly = 12;

        autosnap = true;
        autoprune = true;
      };
      "tank/enc/backups" = {
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
      "[::]"
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

  services.nginx.virtualHosts = {
    "graf.turb.io" = {
      forceSSL = true;
      useACMEHost = "turb.io";

      locations."/" = {
        proxyPass = "http://${inventory.vms.grafana.addr.ip4}:3000";
        extraConfig = ''
          proxy_set_header Host $host;
        '';
      };

      locations."/api/live/" = {
        proxyPass = "http://${inventory.vms.grafana.addr.ip4}:3000";
        extraConfig = ''
          proxy_http_version 1.1;
          proxy_set_header Upgrade $http_upgrade;
          proxy_set_header Connection $connection_upgrade;
          proxy_set_header Host $host;
        '';
      };
    };
  };

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

  power.ups = {
    enable = true;
    mode = "standalone";
    upsmon.enable = false;
    ups.ups0 = {
      driver = "usbhid-ups";
      port = "auto";
      description = "CyberPower CP2000PFCRM2U";
      directives = [
        "vendorid = 0764"
        "serial = CYWQY7003869"
      ];
    };
    ups.ups1 = {
      driver = "usbhid-ups";
      port = "auto";
      description = "CyberPower CP2000PFCRM2U";
      directives = [
        "vendorid = 0764"
        "serial = CYWQY7003858"
      ];
    };
  };

  services.prometheus.exporters = {
    # exporters bind 0.0.0.0 but the firewall admits nothing beyond what the
    # inventory machine-ballos grants generate (the prometheus vm scrapes
    # them at ballos's lan address)
    nut = {
      enable = true;
      listenAddress = "0.0.0.0";
      nutVariables = [
        "battery.charge"
        "battery.runtime"
        "battery.voltage"
        "battery.voltage.nominal"
        "input.voltage"
        "input.voltage.nominal"
        "output.voltage"
        "ups.load"
        "ups.realpower"
        "ups.power"
        "ups.status"
      ];
    };
    process = {
      enable = true;
      settings.process_names = [
        # { name = "{{.Matches.Wrapped}} {{ .Matches.Args }}"; cmdline = [ "^/nix/store[^ ]*/(?P<Wrapped>[^ /]*) (?P<Args>.*)" ]; }
        {
          name = "{{.Comm}}";
          cmdline = [ ".+" ];
        }
      ];
      listenAddress = "0.0.0.0";
    };
    zfs = {
      enable = true;
      listenAddress = "0.0.0.0";
    };
    wireguard = {
      enable = true;
    };
    ping = {
      enable = true;
      listenAddress = "0.0.0.0";
      settings = {
        targets = [
          "8.8.8.8"
          "1.1.1.1"

          "192.168.100.1"
          "192.168.100.2"

          "192.168.101.1"
          "192.168.101.2"

          "192.168.102.1"
          "192.168.102.2"
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
              (
                let
                  vhostNames = builtins.attrNames config.services.nginx.virtualHosts;
                  escapeRegex = lib.replaceStrings [ "." ] [ "\\." ];
                  exactVhosts = builtins.filter (n: !(lib.hasPrefix "*" n) && n != "_") vhostNames;
                  wildcardVhosts = builtins.filter (lib.hasPrefix "*.") vhostNames;
                  # nginx prefers the longest wildcard match; sort by length desc
                  wildcardsByLength = lib.sort (a: b: lib.stringLength a > lib.stringLength b) wildcardVhosts;
                in
                {
                  target_label = "host";
                  from = "host";
                  matches =
                    (map (n: {
                      regexp = "^${escapeRegex n}$";
                      replacement = n;
                    }) exactVhosts)
                    ++ (map (w: {
                      regexp = "^.+${escapeRegex (lib.removePrefix "*" w)}$";
                      replacement = w;
                    }) wildcardsByLength)
                    ++ [
                      {
                        regexp = ".*";
                        replacement = "_";
                      }
                    ];
                }
              )
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
    /*
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
    */
    node = {
      enable = true;
      enabledCollectors = [ "systemd" ];
      listenAddress = "0.0.0.0";
      port = 9100;
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

  services.postgresql.package = pkgs.postgresql_16;

  # buildbot (master, worker, and its postgres) lives in vms/buildbot — cut
  # over 2026-07-30, builds now run inside the vm. this vhost terminates tls
  # and mirrors the three locations the buildbot-nix module tunes on the
  # vm's own nginx. ledger: ballos postgres still carries the old unused
  # `buildbot` db.
  services.nginx.virtualHosts."ci.turb.io" = {
    forceSSL = true;
    useACMEHost = "turb.io";

    locations."/" = {
      proxyPass = "http://${inventory.vms.buildbot.addr.ip4}:80";
      extraConfig = ''
        proxy_set_header Host $host;
        proxy_connect_timeout 120s;
        proxy_send_timeout 120s;
        proxy_read_timeout 120s;
      '';
    };
    locations."/sse" = {
      proxyPass = "http://${inventory.vms.buildbot.addr.ip4}:80/sse";
      extraConfig = ''
        proxy_set_header Host $host;
        proxy_buffering off;
      '';
    };
    locations."/ws" = {
      proxyPass = "http://${inventory.vms.buildbot.addr.ip4}:80/ws";
      proxyWebsockets = true;
      extraConfig = ''
        proxy_set_header Host $host;
        proxy_read_timeout 6000s;
      '';
    };
  };

  services.promtail = {
    enable = true;
    configuration = {
      server = {
        http_listen_port = 9080;
        grpc_listen_port = 0;
      };
      clients = [ { url = "http://${inventory.vms.loki.addr.ip4}:3100/loki/api/v1/push"; } ];
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
