{ pkgs, ... }:
let
  # blurred-screenshot locker; runtime deps are baked into the script
  lock = pkgs.callPackage ../../packages/lock.nix { };
in
{
  # logind's uaccess tagging (via 60-steam-input.rules) sets ACLs on /dev/uinput
  # that strip group permissions, breaking kanata's DynamicUser group-based access.
  # Fix the ACL right before kanata starts.
  systemd.services.kanata-internal.serviceConfig.ExecStartPre =
    "+${pkgs.acl}/bin/setfacl -m g:uinput:rw /dev/uinput";

  nix.settings.extra-platforms = [ "armv7l-linux" ];
  boot.binfmt.emulatedSystems = [ "armv7l-linux" ];

  services.cachefilesd.enable = true;

  virtualisation.virtualbox.host.enable = true;

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
      "photos" = {
        enable = true;
        path = "~/Pictures/photos";
      };
    };
  };

  networking.networkmanager.enable = true;

  isDesktop = true;

  fileSystems =
    let
      nfsopts = {
        fsType = "nfs";
        neededForBoot = false;
        options = [
          "fsc" # use cachefilesd
          "rw"
          "noatime"
          "nofail"
          "nconnect=8"
          "rsize=1048576"
          "wsize=1048576"
          "proto=tcp"
          "actimeo=60"
          "nocto"
          "hard"
          "softreval"
          "x-systemd.automount"
          "x-systemd.mount-timeout=5s"
          "x-systemd.idle-timeout=10m"
        ];
      };
    in
    {
      "tank/photos" = nfsopts // {
        device = "joast:/tank/enc/photos";
      };
      "tank/backups" = nfsopts // {
        device = "joast:/tank/enc/backups";
      };
    };

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

  programs.hyprlock.enable = true;

  security.pam.services.swaylock = { };

  environment.systemPackages = [
    pkgs.swaylock
    lock
  ];

  systemd.user.services.swayidle = {
    description = "Idle & sleep locker";
    after = [ "graphical-session.target" ];
    wantedBy = [ "graphical-session.target" ];

    serviceConfig = {
      # -w holds the sleep inhibitor until lock returns, so we never suspend
      # ahead of the lock actually being up. 'lock' picks up
      # loginctl lock-session too.
      ExecStart = ''
        ${pkgs.swayidle}/bin/swayidle -w \
          timeout 600 '${lock}/bin/lock' \
          before-sleep '${lock}/bin/lock' \
          lock '${lock}/bin/lock'
      '';
      # the watcher dying is itself a way to end up never locking
      Restart = "always";
      RestartSec = 1;
    };
  };
}
