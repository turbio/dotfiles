{ config, pkgs, lib, ... }: {
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.firewall.enable = true;
  networking.firewall.allowedTCPPorts = [ 80 443 ];

  #security.acme.defaults.email = "letsencrypt@turb.io";
  #security.acme.acceptTerms = true;

  services.nginx.appendHttpConfig = ''
    error_log stderr;
    access_log syslog:server=unix:/dev/log combined;
  '';
  services.nginx.enable = true;

  users.groups.grafana.members = [ "nginx" ]; # so nginx can poke grafan's socket
  services.grafana = {
    enable = true;

    settings.server = {
      socket = "/run/grafana/grafana.sock";
      root_url = "https://graf.turb.io/";
      domain = "graf.turb.io";
      protocol = "socket";
    };
  };

  virtualisation.oci-containers = {
    backend = "podman";
    containers.homeassistant = {
      volumes = [ "home-assistant:/config" ];
      environment.TZ = "America/Chicago";
      image = "ghcr.io/home-assistant/home-assistant:stable"; # Warning: if the tag does not change, the image will not be updated
      extraOptions = [ 
        "--network=host" 
      ];
    };
  };

  services.matter-server = {
    #enable = true;
  };

  services.nginx.virtualHosts = {
    "graf.turb.io" = {
      #addSSL = true;
      #enableACME = true;

      locations."/" = {
        proxyPass = "http://unix:/${config.services.grafana.settings.server.socket}";
        extraConfig = ''
          proxy_set_header Host $host;
        '';
      };

      locations."/api/live/" = {
        proxyPass = "http://unix:/${config.services.grafana.settings.server.socket}";
        extraConfig = ''
          proxy_http_version 1.1;
          proxy_set_header Upgrade $http_upgrade;
          proxy_set_header Connection $connection_upgrade;
          proxy_set_header Host $host;
        '';
      };
    };
  };

  nixpkgs.overlays = [
    (final: { lib, buildGoModule, fetchFromGitHub, nixosTests, ... }: {
      prometheus-idrac-exporter = buildGoModule rec {
          pname = "idrac_exporter";
          version = "unstable-2023-06-29";

          src = fetchFromGitHub {
            owner = "mrlhansen";
            repo = "idrac_exporter";
            rev = "3b311e0e6d602fb0938267287f425f341fbf11da";
            sha256 = "sha256-N8wSjQE25TCXg/+JTsvQk3fjTBgfXTiSGHwZWFDmFKc=";
          };

          vendorHash = "sha256-iNV4VrdQONq7LXwAc6AaUROHy8TmmloUAL8EmuPtF/o=";

          patches = [ ./idrac-exporter/config-from-environment.patch ];

          ldflags = [ "-s" "-w" ];

          doCheck = true;

          passthru.tests = { inherit (nixosTests.prometheus-exporters) idrac; };

          meta = with lib; {
            inherit (src.meta) homepage;
            description = "Simple iDRAC exporter for Prometheus";
            mainProgram = "idrac_exporter";
            license = licenses.mit;
            maintainers = with maintainers; [ codec ];
          };
        };
    })

    /*
    (final: prev: {
      python-matter-server = prev.python-matter-server.overrideAttrs (finalAttrs: prevAttrs: {
        version = "5.0.3";
        src = prev.fetchFromGitHub {
          owner = "home-assistant-libs";
          repo = "python-matter-server";
          rev = "refs/tags/5.0.3";
          hash = "sha256-bR6AVoy9f02RKZ57dnHTDAv5LTCcd/qBbzMDRKsGbfM=";
        };
        patches = null;
        postPatch = ''
          substituteInPlace pyproject.toml \
            --replace 'version = "0.0.0"' 'version = "5.0.3"'
        '';
      });
    })
    */

    (final: prev: {
      freeipmi = prev.freeipmi.overrideAttrs (finalAttrs: prevAttrs: {
        configureFlags = prevAttrs.configureFlags ++ [ "ac_dont_check_for_root=yes" ];
      });
    })

    (final: { buildGoModule, fetchFromGitHub, ... }: {
      prometheus-comed-exporter = buildGoModule {
        pname = "comed_exporter";
        version = "1.0";
        src = fetchFromGitHub {
          owner = "kklipsch";
          repo = "comed_exporter";
          rev = "1a90f09ceb0ebdfe09c2b307b4080d81b7d8de5f";
          hash = "sha256-oDvOp7SGz7RTWW3b74I1V3WhiNsHvO3hv01Gr4UkyiY=";
        };

        vendorHash = null;

        doCheck = false;
      };
    })

    (final: { buildGoModule, fetchFromGitHub, ... }: {
      lvm-exporter = buildGoModule rec {
        pname = "prometheus-lvm-exporter";
        version = "v0.3.3";

        src = fetchFromGitHub {
          owner = "hansmi";
          repo = pname;
          rev = version;
          hash = "sha256-mA84Bnq5JF0BGfqHhcCzTef5nDotLgQuiyg3/zOPqTE=";
        };
        vendorHash = "sha256-vqxsg70ShMo4OVdzhqYDj/HT3RTpCUBGHze/EkbBJig=";
        doCheck = false;
      };
    })
  ];

  systemd.services.prometheus-comed-exporter = {
    enable = true;
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.prometheus-comed-exporter}/bin/comed_exporter --address :9010";
    };
  };

  systemd.services.prometheus-lvm-exporter = {
    enable = true;
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.lvm-exporter}/bin/prometheus-lvm-exporter --web.listen-address 127.0.0.1:9012 --command=${pkgs.lvm2.bin}/bin/lvm";
    };
  };

  services.apcupsd = {
    enable = true;
  };

  services.nginx.statusPage = true;

  services.prometheus = {
    enable = true;
    port = 9090;
    listenAddress = "127.0.0.1";
    retentionTime = "1y";

    globalConfig = {
      scrape_interval = "10s";
    };

    scrapeConfigs = [
      {
        job_name = "comed_json";
        metrics_path = "/probe";
        params = {
          module = ["comed"];
        };
        static_configs = [
          { targets = [ "https://hourlypricing.comed.com/api?type=currenthouraverage" ]; }
        ];
        relabel_configs = [
          { source_labels = [ "__address__" ]; target_label = "__param_target"; }
          { source_labels = [ "__param_target" ]; target_label = "instance"; }
          { target_label = "__address__"; replacement = "127.0.0.1:${toString config.services.prometheus.exporters.json.port}"; }
        ];
      }
      {
        job_name = "comed";
        static_configs = [
          { targets = [ "127.0.0.1:9010" ]; }
        ];
      }
      {
        job_name = "lvm";
        static_configs = [
          { targets = [ "127.0.0.1:9012" ]; }
        ];
      }
      {
        job_name = "ipmi";
        static_configs = [
          { targets = [ "127.0.0.1:${toString config.services.prometheus.exporters.ipmi.port}" ]; }
        ];
      }
      {
        job_name = "nodexporter";
        static_configs = [
          { targets = [ "127.0.0.1:${toString config.services.prometheus.exporters.node.port}" ]; }
        ];
      }
      {
        job_name = "apcupsd";
        static_configs = [
          { targets = [ "127.0.0.1:${toString config.services.prometheus.exporters.apcupsd.port}" ]; }
        ];
      }
      {
        job_name = "idrac";
        scrape_timeout = "1m";
        scrape_interval = "2m";
        static_configs = [{
          # F
          targets = [ "idrac-6970JH2.local" ];
          #targets = [ "192.168.3.203" ];
        }];
        relabel_configs = [
          { source_labels = [ "__address__" ]; target_label = "__param_target"; }
          { source_labels = [ "__param_target" ]; target_label = "instance"; }
          { target_label = "__address__"; replacement = "127.0.0.1:${toString config.services.prometheus.exporters.idrac.port}"; }
        ];
      }
      {
        job_name = "smartctl";
        static_configs = [
          { targets = [ "127.0.0.1:${toString config.services.prometheus.exporters.smartctl.port}" ]; }
        ];
      }
      {
        job_name = "nginx";
        static_configs = [
          { targets = [ "127.0.0.1:${toString config.services.prometheus.exporters.nginx.port}" ]; }
        ];
      }
    ];

    exporters = {
      nginx = {
        enable = true;
      };
      smartctl = {
        enable = true;
      };
      json = {
        enable = true;
        configFile = pkgs.writeText "json-exporter-config" ''
          modules:
            comed:
              metrics:
              - name: comed
                type: object
                path: '{ [*] }'
                values:
                  price_per_kwh: '{ .price }'
                  millis_utc: '{ .millisUTC }'
        '';
      };
      ipmi = {
        enable = true;
        configFile = pkgs.writeText "ipmi-exporter-config" ''
          modules:
            default:
              collectors:
                - ipmi
                - dcmi
        '';
      };
      node = {
        enable = true;
        enabledCollectors = [ "systemd" ];
        listenAddress = "127.0.0.1";
        port = 9092;
      };
      apcupsd = {
        enable = true;
      };
      idrac = {
        enable = true;
        configuration = {
          timeout = 60;
          listenAddress = "127.0.0.1";
          port = 9348;
          hosts = {
            "idrac-6970JH2.local" = {
              username = "root";
              password = "calvin";
            };
          };
          metrics = {
            system = true;
            sensors = true;
            power = true;
            storage = true;
            memory = true;
            network = true;
            sel = true;
          };
        };
      };
    };
  };

  systemd.services.prometheus-ipmi-exporter.serviceConfig = {
    PrivateDevices = false;
  };

  services.udev.extraRules = ''
    KERNEL=="ipmi*", MODE="660", GROUP="${config.services.prometheus.exporters.ipmi.group}"
  '';

  fileSystems."/mnt" = {
    device = "/dev/group/five";
    fsType = "ext4";
    options = [ "nofail" "user" ];
  };

  #boot.loader.systemd-boot.enable = true;
  #boot.loader.efi.efiSysMountPoint = "/efi";

  #boot.uki.settings.UKI.Cmdline = "init=${config.system.build.toplevel}/init ${toString config.boot.kernelParams}";
  #boot.loader.external = let arch = pkgs.stdenv.hostPlatform.efiArch; in {
  #  enable = true;
  #  installHook = pkgs.writeScript "install-bootloader" ''
  #    cp ${pkgs.systemd}/lib/systemd/boot/efi/systemd-boot${arch}.efi /efi/EFI/BOOT/BOOT${lib.toUpper arch}.EFI


  #  ''

  #    #echo ${config.system.build.uki}
  #    #cp ${config.system.build.uki}/${config.system.boot.loader.ukiFile} /efi/EFI/Linux/${config.system.boot.loader.ukiFile}
  #  ;
  #};


  # Use the GRUB 2 boot loader.
  #boot.loader.grub.enable = true;
  #boot.loader.grub.version = 2;
  # boot.loader.grub.efiSupport = true;
  # boot.loader.grub.efiInstallAsRemovable = true;
  # Define on which hard drive you want to install Grub.
  # boot.loader.grub.device = "/dev/sda"; # or "nodev" for efi only

  # networking.hostName = "nixos"; # Define your hostname.
  # Pick only one of the below networking options.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.
  # networking.networkmanager.enable = true;  # Easiest to use and most distros use this by default.

  # Set your time zone.
  # time.timeZone = "Europe/Amsterdam";

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Select internationalisation properties.
  # i18n.defaultLocale = "en_US.UTF-8";
  # console = {
  #   font = "Lat2-Terminus16";
  #   keyMap = "us";
  #   useXkbConfig = true; # use xkbOptions in tty.
  # };

  # Enable the X11 windowing system.
  # services.xserver.enable = true;




  # Configure keymap in X11
  # services.xserver.layout = "us";
  # services.xserver.xkbOptions = {
  #   "eurosign:e";
  #   "caps:escape" # map caps to escape.
  # };

  # Enable CUPS to print documents.
  # services.printing.enable = true;

  # Enable sound.
  # sound.enable = true;
  # hardware.pulseaudio.enable = true;

  # Enable touchpad support (enabled default in most desktopManager).
  # services.xserver.libinput.enable = true;

  # Define a user account. Don't forget to set a password with ‘passwd’.
  # users.users.alice = {
  #   isNormalUser = true;
  #   extraGroups = [ "wheel" ]; # Enable ‘sudo’ for the user.
  #   packages = with pkgs; [
  #     firefox
  #     thunderbird
  #   ];
  # };

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  # environment.systemPackages = with pkgs; [
  #   vim # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
  #   wget
  # ];

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  # services.openssh.enable = true;

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  # Copy the NixOS configuration file and link it from the resulting system
  # (/run/current-system/configuration.nix). This is useful in case you
  # accidentally delete configuration.nix.
  # system.copySystemConfiguration = true;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
}
