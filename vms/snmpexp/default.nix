# snmp exporter — probes the network gear (ccr, switches, pepwave-side) over
# snmp; needed the cidr: policy selector for the 192.168.50.x target.
{ ... }:
{
  services.prometheus.exporters.snmp = {
    enable = true;
    listenAddress = "0.0.0.0";
    configurationPath = ./snmp.yml;
  };
}
