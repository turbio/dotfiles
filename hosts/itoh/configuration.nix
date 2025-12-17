{ ... }:
{
  isDesktop = true;

  boot.binfmt.emulatedSystems = [
    "aarch64-linux"
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.interfaces.enp23s0.useDHCP = true;

  systemd.services.NetworkManager-wait-online.enable = false;

  hardware.bluetooth.enable = true;

  swapDevices = [
    {
      device = "/swapfile";
      size = 32 * 1024;
    }
  ];

  services.syncthing = {
    enable = true;
    user = "turbio";
    group = "users";
    configDir = "/home/turbio/.config/syncthing";
    dataDir = "/home/turbio";
    settings.folders."code" = {
      enable = true;
      path = "~/src";
    };
    settings.folders."clips" = {
      enable = true;
      path = "~/Pictures/clip";
    };
    settings.folders."webcamlog" = {
      enable = true;
      path = "~/Pictures/webcamlog";
    };
    settings.folders."notes" = {
      enable = true;
      path = "~/notes";
    };
  };

  services.ollama.enable = true;
  services.ollama.acceleration = "rocm";
  services.ollama.rocmOverrideGfx = "11.0.0";

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
            #mountpoint = "/persist";
            mountpoint = "/";
            mountOptions = [
              "defaults"
            ];
          };
        };
        swap = {
          size = "32G";
          content = {
            type = "swap";
            resumeDevice = true;
          };
        };
      };
    };
  };
}
