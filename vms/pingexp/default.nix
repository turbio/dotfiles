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
