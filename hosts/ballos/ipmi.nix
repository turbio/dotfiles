{ config, pkgs, ... }: {
  nixpkgs.overlays = [
    (final: prev: {
      freeipmi = prev.freeipmi.overrideAttrs (finalAttrs: prevAttrs: {
        configureFlags = prevAttrs.configureFlags ++ [ "ac_dont_check_for_root=yes" ];
      });
    })
  ];

  systemd.services.prometheus-ipmi-exporter.serviceConfig = {
    PrivateDevices = false;
    DynamicUser = false;
  };

  users.groups.ipmi-exporter = {};
  users.users.ipmi-exporter = { isSystemUser = true; group = "ipmi-exporter"; };
  services.udev.extraRules = ''
    KERNEL=="ipmi*", MODE="660", GROUP="ipmi-exporter"
  '';

  services.prometheus = {
    scrapeConfigs = [
      {
        job_name = "ipmi";
        scrape_interval = "10s";
        static_configs = [
          { targets = [ "127.0.0.1:${toString config.services.prometheus.exporters.ipmi.port}" ]; }
        ];
      }
    ];
    exporters = {
      ipmi = {
        enable = true;
        user = "ipmi-exporter";
        group = "ipmi-exporter";
        configFile = pkgs.writeText "ipmi-exporter-config" ''
          modules:
            default:
              collectors:
                - ipmi
                - dcmi
        '';
      };
    };
  };
}
