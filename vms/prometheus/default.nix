# prometheus — stage-1 duplicate of the host instance, scraping the same
# targets from the vm's vantage point: sibling vms at their inventory
# addresses, machines/edges by int name, and the ballos hardware exporters
# (which stay on metal) at ballos's lan address. runs side by side with the
# host instance until cutover.
#
# differs from the host config on purpose:
#   - flippyflops is scraped at its vm address (the host job still points at
#     127.0.0.1:3001, dead since that service vmized)
#
# cutover notes (turbio's ledger):
#   - data: /tank/prometheus (undeclared dataset, ~44G) ->
#     /tank/enc/vms/prometheus/var/lib/prometheus2/data
#   - retarget grafana's provisioned datasource url + drop its
#     machine-ballos-9090 grant; drop host prometheus + its 9090 comment
#   - zfs destroy tank/enc/prometheus: 64G corpse of the pre-Aug-16-2025
#     tsdb location, frozen the day tank/prometheus (mountpoint
#     /var/lib/prometheus2) replaced it
#   - TODO instance labels: pinned below to the host-era values
#     ("127.0.0.1:<port>") so the copied tsdb's series continue seamlessly.
#     eventually do this properly: relabel to stable identities (machine/vm
#     names) that don't encode the scrape path, take the one-time series
#     break, and tombstone the short 192.168.88.242:* stubs written between
#     the migration and the pinning (2026-07-30)
{ inventory, ... }:
let
  # ballos's exporters, reached at its stable lan address; each port is
  # covered by this vm's `machine "ballos" [ ... ]` grant in inventory, which
  # keeps working if this vm ever moves to another hypervisor
  joast = port: "${inventory.machines.joast.lan.ip4}:${toString port}";
in
{
  services.prometheus = {
    enable = true;
    port = 9090;
    listenAddress = "0.0.0.0";
    retentionTime = "1y";

    globalConfig = {
      scrape_interval = "1s";
    };

    scrapeConfigs = [
      {
        job_name = "ipmi";
        scrape_interval = "10s";
        scrape_timeout = "8s";
        static_configs = [
          {
            targets = [ (joast 9290) ];
            labels.host = "joast";
          }
          {
            targets = [ "zote.int.turb.io:9290" ];
            labels.host = "zote";
          }
          {
            targets = [ "ballos.int.turb.io:9290" ];
            labels.host = "ballos";
          }
          {
            targets = [ "j2.int.turb.io:9290" ];
            labels.host = "j2";
          }
        ];
      }

      {
        job_name = "flippyflops";
        scrape_interval = "5s";
        static_configs = [ { targets = [ "${inventory.vms.flippyflops.addr.ip4}:3001" ]; } ];
        # the app serves prometheus text with no content-type; the host job's
        # OpenMetrics fallback made the parser demand a trailing "# EOF" the
        # app doesn't send
        fallback_scrape_protocol = "PrometheusText0.0.4";
      }
      {
        job_name = "prometheus";
        scrape_interval = "5s";
        static_configs = [
          { targets = [ "127.0.0.1:9090" ]; }
        ];
      }
      {
        job_name = "pushgateway";
        scrape_interval = "5s";
        static_configs = [
          { targets = [ "${inventory.vms.pushgateway.addr.ip4}:9091" ]; }
        ];
      }
      {
        job_name = "raritan-pdu";
        scrape_interval = "30s";
        scrape_timeout = "10s";
        scheme = "https";
        metrics_path = "/cgi-bin/dump_prometheus.cgi";
        basic_auth = {
          username = "admin";
          password = "ZCG8ihvcznuHPdzvVYig";
        };
        tls_config = {
          insecure_skip_verify = true;
        };
        static_configs = [
          {
            targets = [ "${inventory.appliances.raritan-pdu-112.lan.ip4}:443" ];
            labels.host = "raritan-pdu-112";
          }
          {
            targets = [ "${inventory.appliances.raritan-pdu-113.lan.ip4}:443" ];
            labels.host = "raritan-pdu-113";
          }
        ];
      }
      {
        job_name = "nodexporter";
        scrape_interval = "30s";
        static_configs = [
          {
            # instance pinned to the host-era loopback label (conditional:
            # the job's other targets keep their int names)
            targets = [ "ballos.int.turb.io:9100" ];
            labels.host = "ballos";
          }
          {
            targets = [ "mote.int.turb.io:9100" ];
            labels.host = "mote";
          }
          {
            targets = [ "aackle.int.turb.io:9100" ];
            labels.host = "aackle";
          }
          {
            targets = [ "backle.int.turb.io:9100" ];
            labels.host = "backle";
          }
          {
            targets = [ "cackle.int.turb.io:9100" ];
            labels.host = "cackle";
          }
          {
            targets = [ "zote.int.turb.io:9100" ];
            labels.host = "zote";
          }
          {
            targets = [ (joast 9100) ]; # // TODO
            labels.host = "joast";
          }
          {
            targets = [ "j2.int.turb.io:9100" ];
            labels.host = "j2";
          }
        ];
      }
      {
        job_name = "smartctl";
        scrape_interval = "1m";
        static_configs = [
          { targets = [ (joast 9633) ]; }
        ];
      }
      {
        job_name = "nut";
        scrape_interval = "1s";
        metrics_path = "/ups_metrics";
        static_configs = [
          {
            targets = [
              "ups0"
              "ups1"
            ];
          }
        ];
        relabel_configs = [
          {
            source_labels = [ "__address__" ];
            target_label = "__param_ups";
          }
          {
            source_labels = [ "__param_ups" ];
            target_label = "ups";
          }
          {
            target_label = "__address__";
            replacement = joast 9199;
          }
        ];
      }
      {
        job_name = "nginx";
        scrape_interval = "1s";
        static_configs = [
          { targets = [ (joast 9113) ]; }
        ];
      }
      {
        job_name = "nginxlog";
        scrape_interval = "1s";
        static_configs = [
          { targets = [ (joast 9117) ]; }
        ];
      }
      {
        job_name = "ping";
        scrape_interval = "1s";
        static_configs = [
          { targets = [ (joast 9427) ]; }
        ];
      }
      {
        # the permanent vm/host ping-exporter pair (perf comparison)
        job_name = "ping-vm";
        scrape_interval = "1s";
        static_configs = [
          { targets = [ "${inventory.vms.pingexp.addr.ip4}:9427" ]; }
        ];
      }
      {
        job_name = "wireguard";
        scrape_interval = "5s";
        static_configs = [
          { targets = [ (joast 9586) ]; }
        ];
      }
      {
        job_name = "zfs";
        scrape_interval = "1m";
        static_configs = [
          { targets = [ (joast 9134) ]; }
        ];
      }
      {
        job_name = "process";
        scrape_interval = "1m";
        # the global 1s scrape_interval caps the *default* timeout at 1s;
        # process-exporter walks all of /proc and answers in ~1.1s and
        # growing (every microvm adds qemu threads) — needs an explicit
        # timeout
        scrape_timeout = "30s";
        static_configs = [
          { targets = [ (joast 9256) ]; }
        ];
      }
      {
        job_name = "snmp_exporter";
        scrape_interval = "1m";
        static_configs = [
          { targets = [ "${inventory.vms.snmpexp.addr.ip4}:9116" ]; }
        ];
      }
      {
        job_name = "snmp";
        scrape_interval = "300s";
        scrape_timeout = "20s";
        metrics_path = "/snmp";
        static_configs = [
          {
            targets = [
              "192.168.88.1"
              "192.168.88.245"
              "192.168.88.252"
              "192.168.50.1"
              "192.168.1.69"
            ];
          }
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
            replacement = "${inventory.vms.snmpexp.addr.ip4}:9116";
          }
        ];
      }
      {
        job_name = "snmp_bw";
        scrape_interval = "10s";
        scrape_timeout = "9s";
        metrics_path = "/snmp";
        params.module = [ "if_bw_fast" ];
        static_configs = [
          {
            targets = [
              "192.168.88.1"
              "192.168.88.245"
              "192.168.88.252"
              "192.168.50.1"
              "192.168.1.69"
            ];
          }
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
            replacement = "${inventory.vms.snmpexp.addr.ip4}:9116";
          }
        ];
      }
    ];
  };
}
