{ ... }:
{
  services.prometheus.exporters.snmp = {
    enable = true;
    listenAddress = "0.0.0.0";
    configurationPath = ./snmp.yml;
  };
}
