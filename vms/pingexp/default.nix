{ inventory, ... }:
{
  services.prometheus.exporters.ping = {
    enable = true;
    listenAddress = "0.0.0.0";
    settings.targets = inventory.probeTargets;
  };
}
