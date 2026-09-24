{ inventory, ... }:
let
  joast = port: "${inventory.machines.joast.lan.ip4}:${toString port}"; # TODO: don't hardcode these

  pinInstance = old: [
    {
      target_label = "instance";
      replacement = old;
    }
  ];

  # everything the snmp exporter walks; the pepwave-side gateway and the
  # .252 switch aren't in inventory (yet)
  snmpTargets = [
    inventory.appliances.ccr2004.lan.ip4
    inventory.appliances.crs326.lan.ip4
    "192.168.88.252"
    "192.168.50.1"
    inventory.appliances.crs305.wan.ip4
  ];
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
        job_name = "flippyflops";
        scrape_interval = "5s";
        static_configs = [ { targets = [ "${inventory.vms.flippyflops.addr.ip4}:3001" ]; } ];
        # format oopsie:
        # the app serves prometheus text with no content-type and the parser
        # demands a trailing "# EOF"
        fallback_scrape_protocol = "PrometheusText0.0.4";
        relabel_configs = pinInstance "127.0.0.1:3001";
      }

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
            targets = [ "ballos.int.turb.io:9100" ];
            labels.host = "ballos";
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
        relabel_configs = [
          {
            source_labels = [ "__address__" ];
            regex = builtins.replaceStrings [ "." ] [ "\\." ] (joast 9092);
            target_label = "instance";
            replacement = "127.0.0.1:9092";
          }
        ];
      }
      {
        job_name = "smartctl";
        scrape_interval = "1m";
        static_configs = [
          { targets = [ (joast 9633) ]; }
        ];
        relabel_configs = pinInstance "127.0.0.1:9633";
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
        relabel_configs = pinInstance "127.0.0.1:9113";
      }
      {
        job_name = "nginxlog";
        scrape_interval = "1s";
        static_configs = [
          { targets = [ (joast 9117) ]; }
        ];
        relabel_configs = pinInstance "127.0.0.1:9117";
      }
      {
        job_name = "ping";
        scrape_interval = "1s";
        static_configs = [
          { targets = [ (joast 9427) ]; }
        ];
        relabel_configs = pinInstance "127.0.0.1:9427";
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
        relabel_configs = pinInstance "127.0.0.1:9586";
      }
      {
        job_name = "zfs";
        scrape_interval = "1m";
        static_configs = [
          { targets = [ (joast 9134) ]; }
        ];
        relabel_configs = pinInstance "127.0.0.1:9134";
      }
      {
        job_name = "process";
        scrape_interval = "1m";
        scrape_timeout = "30s";
        static_configs = [
          { targets = [ (joast 9256) ]; }
        ];
        relabel_configs = pinInstance "127.0.0.1:9256";
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
        static_configs = [ { targets = snmpTargets; } ];
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
        static_configs = [ { targets = snmpTargets; } ];
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
