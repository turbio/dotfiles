# grafana — behind the graf.turb.io vhost on ballos. reaches loki at its vm
# address and the (still host-side) prometheus at the anycast gateway; when
# prometheus becomes a vm only the provisioned datasource url changes.
#
# pending data migration (turbio's ledger): host /var/lib/grafana ->
# /tank/enc/vms/grafana/var/lib/grafana (+ in-guest chown -R
# grafana:grafana); carries manually-created dashboards — the old manual
# prometheus datasource in it points at 127.0.0.1 and can be deleted in
# favor of the provisioned one
{
  pkgs,
  inventory,
  ...
}:
{
  services.grafana = {
    enable = true;

    settings.server = {
      http_addr = "0.0.0.0";
      http_port = 3000;
      root_url = "https://graf.turb.io/";
      domain = "graf.turb.io";
    };

    provision.datasources.settings.datasources = [
      {
        name = "Loki";
        type = "loki";
        uid = "loki";
        url = "http://${inventory.vms.loki.addr.ip4}:3100";
        isDefault = false;
      }
      {
        name = "Prometheus";
        type = "prometheus";
        uid = "prometheus";
        url = "http://${inventory.vms.prometheus.addr.ip4}:9090";
        isDefault = true;
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
}
