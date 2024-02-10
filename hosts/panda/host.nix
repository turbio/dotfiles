{ config, pkgs, ... }:
let
  slurpgps = pkgs.runCommandCC "surpgps"
    {
      buildInputs = [ pkgs.rustc ];
    } ''
    rustc ${./slurpgps/slurpgps.rs} -o slurpgps
    mkdir -p $out/bin/
    cp slurpgps $out/bin/
  '';

  vanio_prom_addr = "127.0.0.1:9093";
  vanio = pkgs.runCommandCC "vanio"
    {
      buildInputs = [ pkgs.rustc ];
    } ''
    rustc ${./vanio/vanio.rs} -o vanio
    mkdir -p $out/bin/
    cp vanio $out/bin/
  '';
  arduino_addr = "/dev/serial/by-id/usb-Arduino_LLC_Arduino_Leonardo-if00";
in
{
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.interfaces.wlan0.useDHCP = true;

  networking.networkmanager.enable = true;
  networking.firewall.enable = false;

  environment.systemPackages = with pkgs; [
    arduino
    arduino-cli
    ino
  ];

  systemd.services.slurpgps = {
    description = "slurp up that data from pepwave";
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      ExecStart = "${slurpgps}/bin/slurpgps";
    };
  };

  systemd.services.vanio = {
    description = "vanio";
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      ExecStart = pkgs.writeShellScript "run-vanio" ''
        ${pkgs.busybox}/bin/stty -F ${arduino_addr} 115200 raw -clocal -echo;
        ${vanio}/bin/vanio --prom-addr ${vanio_prom_addr} --adruino-tty ${arduino_addr}
      '';
      Restart = "on-failure";
      RestartSec = "5s";
    };
  };

  services.prometheus = {
    enable = true;
    port = 9090;
    listenAddress = "127.0.0.1";
    retentionTime = "1y";

    scrapeConfigs = [
      {
        job_name = "vanio";
        scrape_interval = "1s";
        static_configs = [{
          targets = [ vanio_prom_addr ];
        }];
      }
      {
        job_name = "nodexporter";
        static_configs = [{
          targets = [ "127.0.0.1:${toString config.services.prometheus.exporters.node.port}" ];
        }];
      }
    ];

    exporters = {
      node = {
        enable = true;
        enabledCollectors = [ "systemd" ];
        listenAddress = "127.0.0.1";
        port = 9092;
      };
    };
  };

  users.groups.grafana.members = [ "nginx" ]; # so nginx can poke grafan's socket
  services.grafana.settings.server = {
    enable = true;
    socket = "/run/grafana/grafana.sock";
    domain = "graph.turb.io";
    protocol = "socket";
    root_url = "http://graph.turb.io/";
  };

  services.nginx.enable = true;
  services.nginx.virtualHosts = {
    "graph.turb.io" = {
      locations."/" = {
        proxyPass = "http://unix:/${config.services.grafana.settings.server.socket}";
      };
    };
  };
}
