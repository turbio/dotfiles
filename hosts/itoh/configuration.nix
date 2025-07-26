{ ... }:
{
  isDesktop = true;

  boot.binfmt.emulatedSystems = [ "aarch64-linux" ];

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
  #boot.resumeDevice = "/swapfile";
  #boot.kernelParams = [ "resume_offset=63858427" ];

  fileSystems."/sync" = {
    device = "ballos:/mnt/sync";
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
    settings.folders."code" = {
      enable = true;
      path = "~/code";
    };
    settings.folders."clips" = {
      enable = true;
      path = "~/Pictures/clip";
    };
    settings.folders."webcamlog" = {
      enable = true;
      path = "~/Pictures/webcamlog";
    };
  };

  services.ollama.enable = true;
  services.ollama.acceleration = "rocm";
  services.ollama.rocmOverrideGfx = "11.0.0";
}
