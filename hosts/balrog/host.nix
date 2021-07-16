{ config, pkgs, stdenv, lib, ... }:

let
  turbio-index = (pkgs.writeTextDir "index.html" ''
    Hey!
    ====


    I'm Turbio
    🐧
  '');
  prom = config.services.prometheus;
in
{
  nixpkgs.overlays = [
    (a: b: {
      flippyflops =
        (import (builtins.fetchTarball {
          url = https://github.com/turbio/flippyflops/archive/master.tar.gz;
        }));
    })
  ];

  security.acme.email = "letsencrypt@turb.io";
  security.acme.acceptTerms = true;

  services.nginx.enable = true;
  services.nginx.virtualHosts = {
    "turb.io" = {
      addSSL = true;
      enableACME = true;

      root = "${turbio-index}";
      extraConfig = ''
        add_header Content-Type 'text/plain; charset=utf-8';
      '';
    };

    "dash.turb.io" = {
      addSSL = true;
      enableACME = true;

      locations."/" = {
        proxyPass = "http://unix:/${config.services.grafana.socket}";
      };
    };

    "push.turb.io" = {
      addSSL = true;
      enableACME = true;

      locations."/" = {
        proxyPass = "http://${prom.pushgateway.web.listen-address}";
      };
    };

    "dots.turb.io" = {
      addSSL = true;
      enableACME = true;

      locations."/" = {
        proxyPass = "http://127.0.0.1:3001";
      };

      extraConfig = ''
        proxy_http_version 1.1;
        chunked_transfer_encoding off;
        proxy_buffering off;
        proxy_cache off;
      '';
    };
  };

  systemd.services.flippyflops = {
    description = "flipdots as a service";
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      ExecStart = "${pkgs.flippyflops { port = 3001;
      host = "127.0.0.1";
    }}/bin/flippyflops";
    };
  };

  users.groups.grafana.members = [ "nginx" ];
  services.grafana = {
    enable = true;
    socket = "/run/grafana/grafana.sock";
    domain = "dash.turb.io";
    protocol = "socket";
    rootUrl = "https://dash.turb.io/";
  };

  services.prometheus = {
    enable = true;
    port = 9090;
    listenAddress = "127.0.0.1";

    scrapeConfigs = [
      {
        job_name = "pushgateway";
        scrape_interval = "5s";
        static_configs = [{
          targets = [ prom.pushgateway.web.listen-address ];
        }];
      }
      {
        job_name = "nodexporter";
        static_configs = [{
          targets = [ "127.0.0.1:${toString prom.exporters.node.port}" ];
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

  services.prometheus.pushgateway = {
    enable = true;
    web.listen-address = "127.0.0.1:9091";
  };

  systemd.services.promtail = {
    description = "Promtail service for Loki";
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      ExecStart = ''
        ${pkgs.grafana-loki}/bin/promtail --config.file ${(pkgs.writeText "promtail.yaml" (builtins.toJSON {
          server = {
            http_listen_port = 20183;
            grpc_listen_port = 0;
          };
          positions = { filename = "/tmp/positions.yaml";};
          clients = [{ url = "http://127.0.0.1:3100/loki/api/v1/push"; }];
          scrape_configs = [
            {
              job_name = "journal";
              journal = { max_age = "12h"; labels = { job = "systemd-journal"; host = "balrog"; };};
              relabel_configs = [{ source_labels = [ "__journal__systemd_unit" ]; target_label = "unit"; }];
            }
          ]
            ;
        }))}
      '';
    };
  };

  services.loki = {
    enable = true;
    configuration = {
      auth_enabled = false;
      server = {
        http_listen_port = 3100;
        http_listen_address = "127.0.0.1";
      };
      ingester = {
        chunk_idle_period = "1h";
        max_chunk_age = "1h";
        chunk_target_size = 1048576;
        chunk_retain_period = "30s";
        max_transfer_retries = 0;
        lifecycler = {
          address = "0.0.0.0";
          ring = {
            kvstore = {
              store = "inmemory";
            };
            replication_factor = 1;
          };
          final_sleep = "0s";
        };
      };

      storage_config = {
        boltdb_shipper = {
          active_index_directory = "/var/lib/loki/boltdb-shipper-active";
          cache_location = "/var/lib/loki/boltdb";
          cache_ttl = "24h";
          shared_store = "filesystem";
        };
        filesystem = {
          directory = "/var/lib/loki/chunks";
        };
      };

      limits_config = {
        reject_old_samples = true;
        reject_old_samples_max_age = "168h";
      };

      chunk_store_config = {
        max_look_back_period = "0s";
      };

      table_manager = {
        retention_deletes_enabled = false;
        retention_period = "0s";
      };

      compactor = {
        working_directory = "/tmp/loki/boltdb-shipper-compactor";
        shared_store = "filesystem";
      };

      schema_config = {
        configs = [
          {
            from = "2020-10-24";
            store = "boltdb-shipper";
            object_store = "filesystem";
            schema = "v11";
            index = {
              prefix = "index_";
              period = "24h";
            };
          }
        ];
      };
    };
  };
}
