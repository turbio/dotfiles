{
  pkgs,
  lib,
  inventory,
  vm,
  ...
}:
let
  inv = inventory;
  net = "akvorado";
  image = "quay.io/akvorado/akvorado:2.4.0";

  clickhouseData = "/var/lib/akvorado-clickhouse";
  kafkaData = "/var/lib/akvorado-kafka";
  geoipDir = "/var/lib/akvorado-geoip";

  clickhouseUid = "101";
  kafkaUid = "1000";

  # flow attribution. akvorado has no reverse-dns step (by design), so every
  # address inventory knows about becomes a /32 (/128) entry named after its
  # host, nested inside the network entries. when the orchestrator builds
  # networks.csv it merges supernet attributes into each leaf, so a host entry
  # only needs `name` and inherits role/site. net: SrcNetName/DstNetName show
  # the hostname where known (network name otherwise) and SrcNetSite/DstNetSite
  # still group by network.
  networkEntries =
    let
      seg = name: {
        inherit name;
        site = name;
        role = "internal";
      };
    in
    {
      ${inv.net.lan.cidr4} = seg "lan";
      ${inv.net.lan.ula} = seg "lan";
      ${inv.net.mgmt.cidr4} = seg "mgmt";
      ${inv.net.mgmt.ula} = seg "mgmt";
      ${inv.net.vm.cidr4} = seg "vm";
      ${inv.net.vm.ula} = seg "vm";
      ${inv.net.tailscale} = seg "tailscale";
      ${inv.net.tailscale6} = seg "tailscale";
      "192.168.50.0/24" = seg "lan-iot";
      "192.168.1.0/24" = seg "upstream";
    };

  hostEntries =
    let
      host = name: ip: {
        name = "${ip}/${if lib.hasInfix ":" ip then "128" else "32"}";
        value = { inherit name; };
      };
      machines = lib.concatLists (
        lib.mapAttrsToList (
          name: m:
          lib.optional (m ? lan.ip4) (host name m.lan.ip4)
          # extra nics carry their dns label (mgmt.joast, aux.ballos)
          ++ lib.mapAttrsToList (label: nic: host "${label}.${name}" nic.ip4) (m.lan.extra or { })
          ++ lib.optional (m ? tailscale.ip4) (host name m.tailscale.ip4)
          ++ lib.optional (m ? tailscale.ip6) (host name m.tailscale.ip6)
          ++ lib.optional (m ? public.ip4) (host name m.public.ip4)
          ++ lib.optional (m ? public.ip6) (host name m.public.ip6)
        ) inv.machines
      );
      appliances = lib.concatLists (
        lib.mapAttrsToList (
          name: a:
          lib.optional (a ? lan.ip4) (host name a.lan.ip4) ++ lib.optional (a ? wan.ip4) (host name a.wan.ip4)
        ) inv.appliances
      );
      vms = lib.concatLists (
        lib.mapAttrsToList (name: v: [
          (host name v.addr.ip4)
          (host name v.addr.ip6)
        ]) inv.vms
      );
    in
    lib.listToAttrs (machines ++ appliances ++ vms);

  serverXml = pkgs.writeText "akvorado-clickhouse-server.xml" ''
    <clickhouse>
     <asynchronous_metric_log><ttl>event_date + INTERVAL 30 DAY DELETE</ttl></asynchronous_metric_log>
     <metric_log><ttl>event_date + INTERVAL 30 DAY DELETE</ttl></metric_log>
     <part_log><ttl>event_date + INTERVAL 30 DAY DELETE</ttl></part_log>
     <text_log><ttl>event_date + INTERVAL 30 DAY DELETE</ttl></text_log>
     <query_log><ttl>event_date + INTERVAL 30 DAY DELETE</ttl></query_log>
     <query_thread_log><ttl>event_date + INTERVAL 30 DAY DELETE</ttl></query_thread_log>
     <query_metric_log><ttl>event_date + INTERVAL 30 DAY DELETE</ttl></query_metric_log>
     <query_views_log><ttl>event_date + INTERVAL 30 DAY DELETE</ttl></query_views_log>
     <trace_log><ttl>event_date + INTERVAL 30 DAY DELETE</ttl></trace_log>
     <error_log><ttl>event_date + INTERVAL 30 DAY DELETE</ttl></error_log>
     <latency_log><ttl>event_date + INTERVAL 30 DAY DELETE</ttl></latency_log>
    </clickhouse>
  '';

  observabilityXml = pkgs.writeText "akvorado-clickhouse-observability.xml" ''
    <clickhouse>
     <prometheus>
      <endpoint>/metrics</endpoint>
      <metrics>true</metrics>
      <events>true</events>
      <asynchronous_metrics>true</asynchronous_metrics>
     </prometheus>
    </clickhouse>
  '';

  flowInput = decoder: port: {
    type = "udp";
    inherit decoder;
    listen = ":${toString port}";
    workers = 4;
    receive-buffer = 212992;
  };

  akvoradoConfig = (pkgs.formats.yaml { }).generate "akvorado.yaml" {
    kafka = {
      topic = "flows";
      brokers = [ "kafka:9092" ];
      topic-configuration = {
        num-partitions = 4;
        replication-factor = 1;
        config-entries = {
          "segment.bytes" = 1073741824;
          "retention.ms" = 86400000; # 1 day buffer for clickhouse
          "cleanup.policy" = "delete";
          "compression.type" = "producer";
        };
      };
    };

    clickhousedb.servers = [ "clickhouse:9000" ];

    clickhouse = {
      orchestrator-url = "http://akvorado-orchestrator:8080";
      prometheus-endpoint = "/metrics";
      networks = networkEntries // hostEntries;
    };

    geoip = {
      optional = true;
      asn-database = [ "/usr/share/GeoIP/asn.mmdb" ];
      geo-database = [ "/usr/share/GeoIP/country.mmdb" ];
    };

    inlet.flow.inputs = [
      (flowInput "netflow" 2055)
      (flowInput "netflow" 4739)
      (flowInput "sflow" 6343)
    ];

    outlet = {
      core = {
        default-sampling-rate = 1;
        interface-classifiers = [
          ''Interface.Name matches "^(ether1|ether2|sfp-sfpplus1)$" && ClassifyExternal()''
          "ClassifyInternal()"
        ];
      };
      metadata.providers = [
        {
          type = "snmp";
          credentials."::/0".communities = "public";
        }
      ];
    };

    console.http.cache = {
      type = "redis";
      server = "redis:6379";
    };
  };

  containerNames = [
    "kafka"
    "redis"
    "clickhouse"
    "akvorado-orchestrator"
    "akvorado-inlet"
    "akvorado-outlet"
    "akvorado-console"
  ];
in
{
  microvm.volumes = [
    {
      image = "${inventory.storage.vmsPath}/${vm.name}/clickhouse.img";
      mountPoint = clickhouseData;
      size = 51200;
    }
  ];

  virtualisation.podman.enable = true;
  virtualisation.oci-containers.backend = "podman";

  virtualisation.oci-containers.containers = {
    kafka = {
      image = "docker.io/apache/kafka:4.2.0";
      extraOptions = [ "--network=${net}" ];
      volumes = [ "${kafkaData}:/var/lib/kafka/data" ];
      environment = {
        KAFKA_NODE_ID = "1";
        KAFKA_PROCESS_ROLES = "controller,broker";
        KAFKA_CONTROLLER_QUORUM_VOTERS = "1@kafka:9093";
        KAFKA_LISTENERS = "CLIENT://:9092,CONTROLLER://:9093";
        KAFKA_LISTENER_SECURITY_PROTOCOL_MAP = "CLIENT:PLAINTEXT,CONTROLLER:PLAINTEXT";
        KAFKA_ADVERTISED_LISTENERS = "CLIENT://kafka:9092";
        KAFKA_CONTROLLER_LISTENER_NAMES = "CONTROLLER";
        KAFKA_INTER_BROKER_LISTENER_NAME = "CLIENT";
        KAFKA_DELETE_TOPIC_ENABLE = "true";
        KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR = "1";
        KAFKA_TRANSACTION_STATE_LOG_MIN_ISR = "1";
        KAFKA_TRANSACTION_STATE_LOG_REPLICATION_FACTOR = "1";
        KAFKA_SHARE_COORDINATOR_STATE_TOPIC_REPLICATION_FACTOR = "1";
        KAFKA_SHARE_COORDINATOR_STATE_TOPIC_MIN_ISR = "1";
        KAFKA_LOG_DIRS = "/var/lib/kafka/data";
      };
    };

    redis = {
      image = "docker.io/valkey/valkey:9.0";
      extraOptions = [ "--network=${net}" ];
    };

    clickhouse = {
      image = "docker.io/clickhouse/clickhouse-server:26.3";
      extraOptions = [
        "--network=${net}"
        "--cap-add=SYS_NICE"
      ];
      volumes = [
        "${clickhouseData}:/var/lib/clickhouse"
        "${observabilityXml}:/etc/clickhouse-server/config.d/observability.xml:ro"
        "${serverXml}:/etc/clickhouse-server/config.d/akvorado.xml:ro"
      ];
      environment = {
        CLICKHOUSE_INIT_TIMEOUT = "60";
        CLICKHOUSE_SKIP_USER_SETUP = "1";
      };
    };

    akvorado-orchestrator = {
      inherit image;
      extraOptions = [ "--network=${net}" ];
      dependsOn = [ "kafka" ];
      cmd = [
        "orchestrator"
        "/etc/akvorado/akvorado.yaml"
      ];
      volumes = [
        "${akvoradoConfig}:/etc/akvorado/akvorado.yaml:ro"
        "${geoipDir}:/usr/share/GeoIP:ro"
      ];
    };

    akvorado-inlet = {
      inherit image;
      extraOptions = [ "--network=${net}" ];
      dependsOn = [
        "akvorado-orchestrator"
        "kafka"
      ];
      cmd = [
        "inlet"
        "http://akvorado-orchestrator:8080"
      ];
      volumes = [ "akvorado-run:/run/akvorado" ];
      ports = [
        "2055:2055/udp"
        "4739:4739/udp"
        "6343:6343/udp"
      ];
    };

    akvorado-outlet = {
      inherit image;
      extraOptions = [ "--network=${net}" ];
      dependsOn = [
        "akvorado-orchestrator"
        "kafka"
        "clickhouse"
      ];
      cmd = [
        "outlet"
        "http://akvorado-orchestrator:8080"
      ];
      volumes = [ "akvorado-run:/run/akvorado" ];
      environment = {
        AKVORADO_CFG_OUTLET_METADATA_CACHEPERSISTFILE = "/run/akvorado/metadata.cache";
        AKVORADO_CFG_OUTLET_FLOW_STATEPERSISTFILE = "/run/akvorado/flow.state";
      };
    };

    akvorado-console = {
      inherit image;
      extraOptions = [ "--network=${net}" ];
      dependsOn = [
        "akvorado-orchestrator"
        "clickhouse"
        "redis"
      ];
      cmd = [
        "console"
        "http://akvorado-orchestrator:8080"
      ];
      volumes = [ "akvorado-console-db:/run/akvorado" ];
      environment = {
        AKVORADO_CFG_CONSOLE_DATABASE_DSN = "/run/akvorado/console.sqlite";
      };
      ports = [ "8080:8080" ];
    };
  };

  systemd.services = lib.mkMerge [
    {
      init-akvorado-network = {
        description = "Create the akvorado podman network";
        wantedBy = [ "multi-user.target" ];
        after = [ "podman.service" ];
        serviceConfig.Type = "oneshot";
        serviceConfig.RemainAfterExit = true;
        script = ''
          ${pkgs.podman}/bin/podman network exists ${net} \
            || ${pkgs.podman}/bin/podman network create ${net}
        '';
      };

      akvorado-prepare = {
        description = "Prepare akvorado data directories";
        wantedBy = [ "multi-user.target" ];
        after = [ "local-fs.target" ];
        serviceConfig.Type = "oneshot";
        serviceConfig.RemainAfterExit = true;
        script = ''
          ${pkgs.coreutils}/bin/mkdir -p ${kafkaData} ${geoipDir}
          ${pkgs.coreutils}/bin/chown ${clickhouseUid}:${clickhouseUid} ${clickhouseData}
          ${pkgs.coreutils}/bin/chown ${kafkaUid}:${kafkaUid} ${kafkaData}
        '';
      };

      akvorado-geoip-update = {
        description = "Download IPinfo GeoIP databases for akvorado";
        after = [ "network-online.target" ];
        wants = [ "network-online.target" ];
        path = [ pkgs.curl ];
        serviceConfig.Type = "oneshot";
        script = ''
          set -eu
          if [ ! -s /run/host-secrets/ipinfo-token ]; then
            echo "no host-delivered ipinfo-token — skipping (geoip stays disabled)"
            exit 0
          fi
          token=$(cat /run/host-secrets/ipinfo-token)
          for db in country asn; do
            curl -fsSL --retry 3 -o ${geoipDir}/$db.mmdb.tmp \
              "https://ipinfo.io/data/free/$db.mmdb?token=$token"
            mv ${geoipDir}/$db.mmdb.tmp ${geoipDir}/$db.mmdb
            chmod 644 ${geoipDir}/$db.mmdb
          done
          echo "geoip databases updated"
        '';
      };
    }
    (lib.genAttrs (map (n: "podman-${n}") containerNames) (_: {
      after = [
        "init-akvorado-network.service"
        "akvorado-prepare.service"
      ];
      requires = [
        "init-akvorado-network.service"
        "akvorado-prepare.service"
      ];
    }))
    {
      podman-akvorado-inlet.serviceConfig.ExecStartPost = [
        "-${pkgs.conntrack-tools}/bin/conntrack -D -p udp --dport 2055"
        "-${pkgs.conntrack-tools}/bin/conntrack -D -p udp --dport 4739"
        "-${pkgs.conntrack-tools}/bin/conntrack -D -p udp --dport 6343"
      ];
    }
  ];

  systemd.tmpfiles.rules = [ "d ${geoipDir} 0755 root root - -" ];

  systemd.timers.akvorado-geoip-update = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "daily";
      Persistent = true;
      OnBootSec = "5min";
    };
  };

  networking.firewall.trustedInterfaces = [ "podman1" ];
}
