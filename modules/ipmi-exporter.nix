{ pkgs, ... }:
{
  nixpkgs.overlays = [
    (final: prev: {
      freeipmi = prev.freeipmi.overrideAttrs (
        finalAttrs: prevAttrs: {
          configureFlags = prevAttrs.configureFlags ++ [ "ac_dont_check_for_root=yes" ];
        }
      );
    })
  ];

  systemd.services.prometheus-ipmi-exporter.serviceConfig = {
    PrivateDevices = false;
    DynamicUser = false;
  };

  users.groups.ipmi-exporter = { };
  users.users.ipmi-exporter = {
    isSystemUser = true;
    group = "ipmi-exporter";
  };
  services.udev.extraRules = ''
    KERNEL=="ipmi*", MODE="660", GROUP="ipmi-exporter"
  '';

  services.prometheus.exporters.ipmi = {
    enable = true;
    user = "ipmi-exporter";
    group = "ipmi-exporter";
    configFile = pkgs.writeText "ipmi-exporter-config" ''
      modules:
        default:
          collectors:
            - ipmi
            - dcmi
          custom_args:
            ipmi:
              - "--bridge-sensors"
    '';
  };
}
