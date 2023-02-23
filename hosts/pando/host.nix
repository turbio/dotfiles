{ config, pkgs, ... }: {
  environment.systemPackages = with pkgs; [
    libraspberrypi
    bluez
  ];

  services.openssh.enable = true;

  networking = {
    hostName = "pando";
    networkmanager = {
      enable = true;
    };
  };

  hardware.bluetooth.enable = true;

  networking.firewall.enable = false;

  users.groups.gpio = {};

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
          targets = [ "127.0.0.1:3000" ];
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
  services.grafana = {
    enable = true;
    socket = "/run/grafana/grafana.sock";
    domain = "graph.turb.io";
    protocol = "socket";
    rootUrl = "http://graph.turb.io/";
  };

  security.acme.email = "letsencrypt@turb.io";
  security.acme.acceptTerms = true;

  services.nginx.enable = true;
  services.nginx.virtualHosts = {
    "graph.turb.io" = {
      addSSL = true;
      enableACME = true;
      locations."/" = {
        proxyPass = "http://unix:/${config.services.grafana.socket}";
        extraConfig = ''
          proxy_set_header Host $host;
        '';

      };
    };
  };
  services.nginx.virtualHosts = {
    "ctrl.turb.io" = {
      addSSL = true;
      enableACME = true;

      locations."/" = {
        proxyPass = "http://127.0.0.1:3000";
      };

      locations."/ws" = {
        proxyPass = "http://127.0.0.1:3000";
        extraConfig = ''
          proxy_set_header Host $host;
          proxy_http_version 1.1;
          proxy_set_header Upgrade $http_upgrade;
          proxy_set_header Connection "upgrade";
          proxy_read_timeout 86400;
        '';
      };

    };
  };


  # bluetooth
  services.udev.extraRules = ''
    # /lib/udev/rules.d/90-pi-bluetooth.rules
    # Copied from https://github.com/RPi-Distro/pi-bluetooth/blob/master/lib/udev/rules.d/90-pi-bluetooth.rules
    ACTION=="add", SUBSYSTEM=="bluetooth", KERNEL=="hci[0-9]", TAG+="systemd", ENV{SYSTEMD_WANTS}+="bthelper@%k.service"

    # /etc/udev/rules.d/99-serial.rules
    # Copied from Raspbian's 99-com.rules

    KERNEL=="ttyAMA0", PROGRAM="${pkgs.bash}/bin/sh -c '\
        ALIASES=/proc/device-tree/aliases; \
        if ${pkgs.diffutils}/bin/cmp -s $$ALIASES/uart0 $$ALIASES/serial0; then \
            echo 0;\
        elif ${pkgs.diffutils}/bin/cmp -s $$ALIASES/uart0 $$ALIASES/serial1; then \
            echo 1; \
        else \
            exit 1; \
        fi\
    '", SYMLINK+="serial%c"

    KERNEL=="ttyAMA1", PROGRAM="${pkgs.bash}/bin/sh -c '\
        ALIASES=/proc/device-tree/aliases; \
        if [ -e /dev/ttyAMA0 ]; then \
            exit 1; \
        elif ${pkgs.diffutils}/bin/cmp -s $$ALIASES/uart0 $$ALIASES/serial0; then \
            echo 0;\
        elif ${pkgs.diffutils}/bin/cmp -s $$ALIASES/uart0 $$ALIASES/serial1; then \
            echo 1; \
        else \
            exit 1; \
        fi\
    '", SYMLINK+="serial%c"

    KERNEL=="ttyS0", PROGRAM="${pkgs.bash}/bin/sh -c '\
        ALIASES=/proc/device-tree/aliases; \
        if ${pkgs.diffutils}/bin/cmp -s $$ALIASES/uart1 $$ALIASES/serial0; then \
            echo 0; \
        elif ${pkgs.diffutils}/bin/cmp -s $$ALIASES/uart1 $$ALIASES/serial1; then \
            echo 1; \
        else \
            exit 1; \
        fi \
    '", SYMLINK+="serial%c"
  '';

  systemd.services = {
    hciuart = {
      after = [ "dev-serial1.device" ];
      wantedBy = [ "dev-serial1.device" ];
      serviceConfig = {
        ExecStart = "${pkgs.writeShellScriptBin "btuart" ''
          # taken right out of the raspbian image

          HCIATTACH=${pkgs.bluez}/bin/hciattach
          if ${pkgs.gnugrep}/bin/grep -q "raspberrypi,4" /proc/device-tree/compatible; then
            BDADDR=
          else
            SERIAL=`cat /proc/device-tree/serial-number | cut -c9-`
            B1=`echo $SERIAL | cut -c3-4`
            B2=`echo $SERIAL | cut -c5-6`
            B3=`echo $SERIAL | cut -c7-8`
            BDADDR=`printf b8:27:eb:%02x:%02x:%02x $((0x$B1 ^ 0xaa)) $((0x$B2 ^ 0xaa)) $((0x$B3 ^ 0xaa))`
          fi

          # Bail out if the kernel is managing the Bluetooth modem initialisation
          if ( ${pkgs.util-linux}/bin/dmesg | ${pkgs.gnugrep}/bin/grep -q -E "hci[0-9]+: BCM: chip" ); then
            # On-board bluetooth is already enabled
            exit 0
          fi

          uart0="`cat /proc/device-tree/aliases/uart0`"
          serial1="`cat /proc/device-tree/aliases/serial1`"

          if [ "$uart0" = "$serial1" ] ; then
              uart0_pins="`wc -c /proc/device-tree/soc/gpio@7e200000/uart0_pins/brcm\,pins | cut -f 1 -d ' '`"
              if [ "$uart0_pins" = "16" ] ; then
                  $HCIATTACH /dev/serial1 bcm43xx 3000000 flow - $BDADDR
              else
                  $HCIATTACH /dev/serial1 bcm43xx 921600 noflow - $BDADDR
              fi
          else
              $HCIATTACH /dev/serial1 bcm43xx 460800 noflow - $BDADDR
          fi
        ''}/bin/btuart";
      };
    };
  };
}

