{ config, ... }:
{
  imports = [ ../../modules/ipmi-exporter.nix ];

  services.prometheus.scrapeConfigs = [
    {
      job_name = "ipmi";
      scrape_interval = "10s";
      scrape_timeout = "8s";
      static_configs = [
        {
          targets = [ "127.0.0.1:${toString config.services.prometheus.exporters.ipmi.port}" ];
          labels.host = "ballos";
        }
        {
          targets = [ "zote.int.turb.io:${toString config.services.prometheus.exporters.ipmi.port}" ];
          labels.host = "zote";
        }
        {
          targets = [ "joast.int.turb.io:${toString config.services.prometheus.exporters.ipmi.port}" ];
          labels.host = "joast";
        }
        {
          targets = [ "j2.int.turb.io:${toString config.services.prometheus.exporters.ipmi.port}" ];
          labels.host = "j2";
        }
      ];
    }
  ];
}
