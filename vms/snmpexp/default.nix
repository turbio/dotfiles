{ pkgs, ... }:
let
  upstreamSnmpYml = pkgs.fetchurl {
    url = "https://raw.githubusercontent.com/prometheus/snmp_exporter/1178915b46b49eb80a976eaadd6d7b3f921283d5/snmp.yml";
    hash = "sha256-yztr+9T0wLXr/ZM9pXShbIfiGdNmgD8IbunvfAxicSQ=";
  };
  patched = pkgs.applyPatches {
    name = "snmp.yml";
    src = pkgs.runCommand "snmp.yml-src" { } ''
      mkdir $out
      cp ${upstreamSnmpYml} $out/snmp.yml
    '';
    patches = [ ./if_bw_fast.patch ];
  };
  # top-level store path: the exporter module warns (fatal under
  # abort-on-warn) on anything lib.isStorePath rejects, including
  # subpaths of store paths like "${patched}/snmp.yml"
  snmpYml = pkgs.runCommand "snmp.yml" { } "ln -s ${patched}/snmp.yml $out";
in
{
  services.prometheus.exporters.snmp = {
    enable = true;
    listenAddress = "0.0.0.0";
    configurationPath = snmpYml;
  };
}
