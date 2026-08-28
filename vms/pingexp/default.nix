# ping exporter — stage-1 duplicate running ALONGSIDE the host instance with
# identical targets, so prometheus can measure vm-tier vs host-tier probe
# latency side by side before any cutover. first egress=true vm.
{ ... }:
{
  services.prometheus.exporters.ping = {
    enable = true;
    listenAddress = "0.0.0.0";
    settings = {
      targets = [
        "8.8.8.8"
        "1.1.1.1"

        "192.168.100.1"
        "192.168.100.2"

        "192.168.101.1"
        "192.168.101.2"

        "192.168.102.1"
        "192.168.102.2"
      ];
    };
  };
}
