{ pkgs, ... }:
{
  isDesktop = true;

  services.upower.enable = true;

  services.fwupd.enable = true;

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.timeout = 0;

  boot.initrd.verbose = false;
  boot.initrd.systemd.enable = true;
  boot.consoleLogLevel = 0;

  networking.interfaces.wlp1s0.useDHCP = true;
  networking.firewall.enable = false;

  hardware.bluetooth.enable = true;
  services.blueman.enable = true;

  programs.light.enable = true;

  boot.initrd.kernelModules = [ ];

  services.syncthing = {
    enable = true;
    configDir = "/home/turbio/.config/syncthing";
    dataDir = "/home/turbio";
    settings.folders = {
      "photos" = {
        enable = true;
        path = "~/photos";
      };
      "code" = {
        enable = true;
        path = "~/code";
      };
      "notes" = {
        enable = true;
        path = "~/notes";
      };
    };
  };

  #boot.kernelParams = [ "modprobe.blacklist=dvb_usb_rtl28xxu" ];
  services.udev.packages = [ pkgs.rtl-sdr ];
  hardware.rtl-sdr.enable = true;
  users.users.turbio.extraGroups = [ "plugdev" ];
  environment.systemPackages = with pkgs; [ rtl-sdr ];

  fileSystems."/sync" = {
    device = "10.100.0.10:/mnt/sync";
    fsType = "nfs";
    options = [
      "rw"
      "noatime"
    ];
  };

  boot.kernelParams = [
    #"quiet" "udev.log_level=0"
  ];

  services.logind = {
    lidSwitch = "hibernate";
    extraConfig = ''
      HandlePowerKey=hibernate
    '';
  };

  services.physlock.enable = true;
  services.physlock.lockOn.hibernate = false;
  services.physlock.lockOn.suspend = false;
  services.physlock.muteKernelMessages = false;
  services.physlock.disableSysRq = true;
}
