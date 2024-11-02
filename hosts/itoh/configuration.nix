{ config, pkgs, ... }: {
  isDesktop = true;

  # boot.kernelPackages = pkgs.linuxPackages_5_14;
  #services.octoprint.enable = true;

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.interfaces.enp23s0.useDHCP = true;
  networking.firewall.enable = true;

  systemd.services.NetworkManager-wait-online.enable = false;

  swapDevices = [
    {
      device = "/swapfile";
      size = 32 * 1024;
    }
  ];
  boot.resumeDevice = "/swapfile";
  boot.kernelParams = [ "resume_offset=63858427" ];

  fileSystems."/sync" = {
    device = "192.168.86.113:/mnt/sync";
    fsType = "nfs";
    options = [
      "rw"
      "noatime"
    ];
  };

  services.syncthing = {
    enable = true;
    user = "turbio";
    group = "users";
    configDir = "/home/turbio/.config/syncthing";
    dataDir = "/home/turbio";
    settings.folders."code" = { enable = true; path = "~/code"; };
  };
}
