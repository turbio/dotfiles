{ config, pkgs, lib, ... }: {
  imports = [
    ../../services/turbio-index.nix
    ../../services/flippyflops.nix
    ./ipmi.nix
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.firewall.enable = false;
  networking.firewall.allowedTCPPorts = [ 80 443 ];

  networking.nftables = {
    enable = true;
    ruleset = ''
    '';
  };

  security.acme.defaults.email = "acme@turb.io";
  security.acme.acceptTerms = true;

  #services.immich = {
  #  enable = true;
  #  port = 8080;
  #};

  services.nfs.server = {
    enable = true;
    exports = ''
      /mnt/sync 192.168.86.0/24(rw)
    '';
  };

  services.nginx = {
    enable = true;
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
  services.nginx.virtualHosts."ballos" = {
    locations."/" = {
      proxyPass = "http://${config.services.syncthing.guiAddress}";
      extraConfig = ''
        allow 10.100.0.0/25;
        deny all;
      '';
    };
  };

  services.syncthing = {
    enable = true;
    openDefaultPorts = true;
    configDir = "/mnt/sync/config";
    dataDir = "/mnt/sync";
    settings.folders = {
      "photos" = { enable = true; path = "/mnt/sync/photos"; };
      "code" = { enable = true; path = "/mnt/sync/code"; };
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

  services.matter-server = lib.mkIf false {
    enable = true;
  };

  services.nginx.virtualHosts = {
    "graf.turb.io" = {
      forceSSL = true;
      enableACME = true;

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
    (final: { lib, buildGoModule, fetchFromGitHub, nixosTests, ... }: {
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

          ldflags = [ "-s" "-w" ];

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
    })

    (final: { buildGoModule, fetchFromGitHub, ... }: {
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
    })

    (final: { buildGoModule, fetchFromGitHub, ... }: {
      lvm-exporter = buildGoModule rec {
        pname = "prometheus-lvm-exporter";
        version = "v0.3.3";

        src = fetchFromGitHub {
          owner = "hansmi";
          repo = pname;
          rev = version;
          hash = "sha256-mA84Bnq5JF0BGfqHhcCzTef5nDotLgQuiyg3/zOPqTE=";
        };
        vendorHash = "sha256-vqxsg70ShMo4OVdzhqYDj/HT3RTpCUBGHze/EkbBJig=";
        doCheck = false;
      };
    })
  ];

  systemd.services.prometheus-comed-exporter = {
    enable = true;
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.prometheus-comed-exporter}/bin/comed_exporter --address :9010";
    };
  };

  systemd.services.prometheus-lvm-exporter = {
    enable = true;
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.lvm-exporter}/bin/prometheus-lvm-exporter --web.listen-address 127.0.0.1:9012 --command=${pkgs.lvm2.bin}/bin/lvm";
    };
  };

  services.apcupsd = {
    enable = true;
  };

  services.prometheus = {
    enable = true;
    port = 9090;
    listenAddress = "127.0.0.1";
    retentionTime = "1y";

    globalConfig = {
      scrape_interval = "1s";
    };

    scrapeConfigs = [
      {
        job_name = "comed_json";
        metrics_path = "/probe";
        params = {
          module = ["comed"];
        };
        static_configs = [
          { targets = [ "https://hourlypricing.comed.com/api?type=currenthouraverage" ]; }
        ];
        relabel_configs = [
          { source_labels = [ "__address__" ]; target_label = "__param_target"; }
          { source_labels = [ "__param_target" ]; target_label = "instance"; }
          { target_label = "__address__"; replacement = "127.0.0.1:${toString config.services.prometheus.exporters.json.port}"; }
        ];
      }
      {
        job_name = "comed";
        static_configs = [
          { targets = [ "127.0.0.1:9010" ]; }
        ];
      }
      {
        job_name = "lvm";
        static_configs = [
          { targets = [ "127.0.0.1:9012" ]; }
        ];
      }
      {
        job_name = "nodexporter";
        static_configs = [
          { targets = [ "127.0.0.1:${toString config.services.prometheus.exporters.node.port}" ]; }
        ];
      }
      {
        job_name = "apcupsd";
        static_configs = [
          { targets = [ "127.0.0.1:${toString config.services.prometheus.exporters.apcupsd.port}" ]; }
        ];
      }
      {
        job_name = "smartctl";
        static_configs = [
          { targets = [ "127.0.0.1:${toString config.services.prometheus.exporters.smartctl.port}" ]; }
        ];
      }
      {
        job_name = "nginx";
        static_configs = [
          { targets = [ "127.0.0.1:${toString config.services.prometheus.exporters.nginx.port}" ]; }
        ];
      }
      {
        job_name = "nginxlog";
        static_configs = [
          { targets = [ "127.0.0.1:${toString config.services.prometheus.exporters.nginxlog.port}" ]; }
        ];
      }
      {
        job_name = "ping";
        static_configs = [
          { targets = [ "127.0.0.1:${toString config.services.prometheus.exporters.ping.port}" ]; }
        ];
      }
    ];

    exporters = {
      ping = {
        enable = true;
        listenAddress = "127.0.0.1";
        settings = {
          targets = [
            "8.8.8.8"
            "1.1.1.1"
            "10.100.0.1"
            "turb.io"
            "udm-se.local"
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
      apcupsd = {
        enable = true;
      };
    };
  };

  fileSystems."/mnt" = {
    device = "/dev/group/five";
    options = [ "nofail" ];
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
