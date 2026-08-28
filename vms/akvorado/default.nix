# akvorado — stage-1, fresh data, side by side with the untouched host
# stack. same podman compose as services/akvorado.nix but in-guest: kafka
# and the geoip dir ride the persistVar dataset, clickhouse gets a
# virtio-blk volume per storage policy (it's the fsync/merge-heavy one).
# the ccr dual-exports flows to both instances during stage-1
# (appliances/ccr2004.nix akvorado_vm target), so this sees real traffic
# without touching the host's feed. flow history is NOT migrated — it's
# time-series; at cutover either accept the gap or copy the clickhouse
# dataset then.
#
# turbio's ledger:
#   - cutover DONE 2026-07-31 (host stack removed, ccr single-targets the
#     vm). fresh clickhouse — host flow history not migrated (turbio:
#     don't care about old data).
#   - ipinfo token is now secrets/ipinfo-token.age (host-delivered at
#     /run/host-secrets/ipinfo-token); the old out-of-band token FILES are
#     deletable: host /var/lib/akvorado-geoip/ and
#     /tank/enc/vms/akvorado/var/lib/akvorado-geoip/token
#   - deletable when confident: tank/enc/akvorado-clickhouse (7.1G old
#     flow history) + tank/enc/akvorado-kafka
#   - console is direct http://akvorado.int.turb.io:8080 (anonymous, no
#     auth headers); a proper name (flow.int) waits on the vhost-int-names
#     DNS decision (PLAN)
{
  pkgs,
  lib,
  inventory,
  vm,
  ...
}:
let
  net = "akvorado";
  image = "quay.io/akvorado/akvorado:2.4.0";

  # blk volume (fsync-heavy clickhouse); kafka + geoip on persistVar /var
  clickhouseData = "/var/lib/akvorado-clickhouse";
  kafkaData = "/var/lib/akvorado-kafka";
  geoipDir = "/var/lib/akvorado-geoip";

  # Container uids baked into the upstream images (no matching users).
  clickhouseUid = "101";
  kafkaUid = "1000";

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

  akvoradoConfig = pkgs.writeText "akvorado.yaml" ''
    kafka:
      topic: flows
      brokers:
        - kafka:9092
      topic-configuration:
        num-partitions: 4
        replication-factor: 1
        config-entries:
          segment.bytes: 1073741824
          retention.ms: 86400000 # 1 day buffer for clickhouse
          cleanup.policy: delete
          compression.type: producer

    clickhousedb:
      servers:
        - clickhouse:9000

    clickhouse:
      orchestrator-url: http://akvorado-orchestrator:8080
      prometheus-endpoint: /metrics
      networks:
        192.168.88.0/24: { name: lan, role: internal }
        192.168.50.0/24: { name: lan-iot, role: internal }
        10.100.0.0/24: { name: vpn, role: internal }
        100.64.0.0/10: { name: tailscale, role: internal }

    geoip:
      optional: true
      asn-database:
        - /usr/share/GeoIP/asn.mmdb
      geo-database:
        - /usr/share/GeoIP/country.mmdb

    inlet:
      flow:
        inputs:
          - { type: udp, decoder: netflow, listen: ":2055", workers: 4, receive-buffer: 212992 }
          - { type: udp, decoder: netflow, listen: ":4739", workers: 4, receive-buffer: 212992 }
          - { type: udp, decoder: sflow,   listen: ":6343", workers: 4, receive-buffer: 212992 }

    outlet:
      core:
        # MikroTik Traffic Flow exports unsampled (1:1) and sends no
        # sampling-rate options template; 1 = each flow counts as-is.
        default-sampling-rate: 1
        # In/OutIfBoundary by interface name (the router's SNMP interface
        # descriptions are empty). First matching Classify* wins.
        interface-classifiers:
          - |
            Interface.Name matches "^(ether1|ether2|sfp-sfpplus1)$" && ClassifyExternal()
          - ClassifyInternal()
      metadata:
        providers:
          - type: snmp
            credentials:
              ::/0:
                communities: public

    console:
      http:
        cache:
          type: redis
          server: redis:6379
  '';

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
      # direct console access at <vm>:8080 (expose admits lan/tailscale);
      # no nginx in front at stage-1 -> anonymous console user.
      # war story (2026-07-31): first-boot restart churn (containers dying
      # while images pulled / deps settled) left netavark with ORPHANED
      # hostport DNAT rules pointing at dead container ips, shadowing the
      # live one — symptom: container serves fine by its own ip, publish
      # gives 000. fix: delete the stale `to:<dead-ip>` rules from
      # NETAVARK-DN-* (or reboot the vm; rules are runtime state). clean
      # systemd-driven restarts tear down properly — only unclean deaths
      # orphan.
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

      # chown bind-mount targets to the container uids after mounts are up
      # (the blk volume and virtiofs var both land via local-fs.target)
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
        # timer-only: wantedBy=multi-user re-ran the download on every
        # switch and 429'd the token (see the old host file's war story)
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
      # the router's export stream is one long-lived conntrack flow; a
      # restarted inlet gets a new container ip and the stale DNAT entry
      # blackholes everything until flushed (see host file's war story)
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

  # containers' DNS to aardvark-dns on the podman bridge
  networking.firewall.trustedInterfaces = [ "podman1" ];
}
