{ pkgs, ... }:
{
  systemd.network.wait-online.enable = false;

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.timeout = 0;

  hardware.bluetooth.enable = true;
  programs.light.enable = true;

  services.syncthing = {
    enable = true;
    configDir = "/home/turbio/.config/syncthing";
    settings.folders = {
      "code" = {
        enable = true;
        path = "~/src";
      };
      "notes" = {
        enable = true;
        path = "~/notes";
      };
      "clips" = {
        enable = true;
        path = "~/Pictures/clip";
      };
      "webcamlog" = {
        enable = true;
        path = "~/Pictures/webcamlog";
      };
    };
  };

  networking.networkmanager.enable = true;

  isDesktop = true;

  fileSystems."/sync" = {
    device = "ballos:/mnt/sync";
    fsType = "nfs";
    neededForBoot = false;
    options = [
      "rw"
      "noatime"
      "x-systemd.automount"
      "x-systemd.mount-timeout=5s"
    ];
  };

  /*
    TODO
    fileSystems = {
      "/" = {
        neededForBoot = true;
        fsType = "tmpfs";
      };
      "/nix" = {
        device = "/persist/nix";
        options = [ "bind" ];
      };
      "/home" = {
        device = "/persist/home";
        options = [ "bind" ];
      };
      "/etc/machine-id" = {
        device = "/persist/machine-id";
        options = [ "bind" ];
      };
      "/var" = {
        device = "/persist/var";
        options = [ "bind" ];
      };
    };
  */

  # clobber it right over your disk:
  # $ sudo nix run 'github:nix-community/disko/latest#disko-install' -- --write-efi-boot-entries --flake '.#<host>' --disk main /dev/<disk>

  disko.devices.disk.main = {
    type = "disk";
    content = {
      type = "gpt";
      partitions = {
        ESP = {
          type = "EF00";
          size = "500M";
          content = {
            type = "filesystem";
            format = "vfat";
            mountpoint = "/boot";
            mountOptions = [ "umask=0077" ];
          };
        };
        # root = {
        #   size = "100%";
        #   content = {
        #     type = "filesystem";
        #     format = "ext4";
        #     mountpoint = "/";
        #   };
        # };
        persist = {
          size = "100%";
          content = {
            type = "luks";
            name = "crypted";
            initrdUnlock = true;
            # holy shit dude nasty hacks dependent on lack of escaping
            # aaaaaand they verify the path starts with a '/' lmao
            # https://github.com/nix-community/disko/blob/76c0a6dba345490508f36c1aa3c7ba5b6b460989/lib/types/luks.nix#L29
            passwordFile = "/<(echo -n password)";
            content = {
              type = "lvm_pv";
              vg = "pool";
            };
          };
        };
      };
    };
  };

  disko.devices.lvm_vg = {
    pool = {
      type = "lvm_vg";
      lvs = {
        root = {
          size = "100%";
          content = {
            type = "filesystem";
            format = "ext4";
            #mountpoint = "/persist";
            mountpoint = "/";
            mountOptions = [
              "defaults"
            ];
          };
        };
        swap = {
          size = "1G"; # TODO: this needs to be grow
          content = {
            type = "swap";
            resumeDevice = true;
          };
        };
      };
    };
  };

  services.logind.settings.Login = {
    HandleLidSwitch = "suspend-then-hibernate";
    HandleHibernateKey = "hibernate";
    HandlePowerKey = "suspend-then-hibernate";
    HandleSuspendKey = "suspend-then-hibernate";
  };

  systemd.sleep.extraConfig = ''
    HibernateDelaySec=1h
  '';

  security.pam.services.swaylock = { };

  environment.systemPackages = with pkgs; [
    swaylock
  ];

  systemd.user.services.swayidle = {
    description = "Idle & sleep locker";
    after = [ "graphical-session.target" ];
    wantedBy = [ "graphical-session.target" ];

    # Make sure these binaries are in PATH for the service
    path = with pkgs; [
      swaylock
      niri
    ];

    serviceConfig = {
      ExecStart = ''
        ${pkgs.swayidle}/bin/swayidle -w \
          timeout 600 'swaylock -f' \
          before-sleep 'swaylock -f'
      '';
      Restart = "on-failure";
    };
  };

  # services.homed.enable = true;
}
