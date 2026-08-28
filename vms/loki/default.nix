# loki — stage-1 duplicate of the host instance (which keeps serving
# promtail + grafana untouched until cutover). same schema/config as the
# host version so migrated data lines up, but everything lives under the
# persistVar /var. storage: virtiofs, per the 2026-07-28 bench — loki's
# write volume is orders of magnitude below its limits.
#
# cutover notes (turbio's ledger):
#   - data: /tank/enc/loki -> /tank/enc/vms/loki/var/lib/loki (+ in-guest
#     chown -R loki:loki), while both lokis are stopped
#   - retarget promtail clients url + grafana datasource, drop host loki +
#     the enc/loki dataset declaration
{ config, ... }:
let
  dataDir = config.services.loki.dataDir; # /var/lib/loki (nixos default)
in
{
  services.loki = {
    enable = true;
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
          active_index_directory = "${dataDir}/tsdb-index";
          cache_location = "${dataDir}/tsdb-cache";
        };
        filesystem.directory = "${dataDir}/chunks";
      };

      limits_config = {
        reject_old_samples = true;
        reject_old_samples_max_age = "168h";
      };

      compactor = {
        working_directory = "${dataDir}/compactor";
        compactor_ring.kvstore.store = "inmemory";
        retention_enabled = false;
      };
    };
  };
}
