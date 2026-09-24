{ pkgs, ... }:
let
  upstreamSnmpYml = pkgs.fetchurl {
    url = "https://raw.githubusercontent.com/prometheus/snmp_exporter/1178915b46b49eb80a976eaadd6d7b3f921283d5/snmp.yml";
    hash = "sha256-yztr+9T0wLXr/ZM9pXShbIfiGdNmgD8IbunvfAxicSQ=";
  };

  # creates a special if_bw_fast to pull only the inoctets/outoctets since a full export is pretty slow on some of my devices
  patched = pkgs.applyPatches {
    name = "snmp.yml";
    src = pkgs.runCommand "snmp.yml-src" { } ''
      mkdir $out
      cp ${upstreamSnmpYml} $out/snmp.yml
    '';
    patches = [ ./if_bw_fast.patch ];
  };
  snmpYml = pkgs.runCommand "snmp.yml" { } "ln -s ${patched}/snmp.yml $out";
in
{
  services.prometheus.exporters.snmp = {
    enable = true;
    listenAddress = "0.0.0.0";
    configurationPath = snmpYml;
  };
}
