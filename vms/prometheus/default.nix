{ inventory, ... }:
let
  ballos = port: "${inventory.machines.ballos.lan.ip4}:${toString port}";

  pinInstance = old: [
    {
      target_label = "instance";
      replacement = old;
    }
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
            targets = [ (ballos 9092) ];
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
            targets = [ "joast.int.turb.io:9100" ];
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
            regex = builtins.replaceStrings [ "." ] [ "\\." ] (ballos 9092);
            target_label = "instance";
            replacement = "127.0.0.1:9092";
          }
        ];
      }
      {
        job_name = "smartctl";
        scrape_interval = "1m";
        static_configs = [
          { targets = [ (ballos 9633) ]; }
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
            replacement = ballos 9199;
          }
        ];
      }
      {
        job_name = "nginx";
        scrape_interval = "1s";
        static_configs = [
          { targets = [ (ballos 9113) ]; }
        ];
        relabel_configs = pinInstance "127.0.0.1:9113";
      }
      {
        job_name = "nginxlog";
        scrape_interval = "1s";
        static_configs = [
          { targets = [ (ballos 9117) ]; }
        ];
        relabel_configs = pinInstance "127.0.0.1:9117";
      }
      {
        job_name = "ping";
        scrape_interval = "1s";
        static_configs = [
          { targets = [ (ballos 9427) ]; }
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
          { targets = [ (ballos 9586) ]; }
        ];
        relabel_configs = pinInstance "127.0.0.1:9586";
      }
      {
        job_name = "zfs";
        scrape_interval = "1m";
        static_configs = [
          { targets = [ (ballos 9134) ]; }
        ];
        relabel_configs = pinInstance "127.0.0.1:9134";
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
          { targets = [ (ballos 9256) ]; }
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
        static_configs = [
          {
            targets = [
              "192.168.88.1"
              "192.168.88.245"
              "192.168.88.252"
              "192.168.50.1"
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
