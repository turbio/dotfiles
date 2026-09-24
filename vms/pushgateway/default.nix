{ ... }:
{
  services.prometheus.pushgateway = {
    enable = true;
    web.listen-address = "0.0.0.0:9091";
  };
}
