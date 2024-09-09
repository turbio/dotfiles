{ config, pkgs, ... }: {
  isDesktop = true;

  # boot.kernelPackages = pkgs.linuxPackages_5_14;
  #services.octoprint.enable = true;

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.interfaces.enp0s31f6.useDHCP = true;
  networking.firewall.enable = false;

  swapDevices = [
    {
      device = "/swapfile";
      size = 32 * 1024;
    }
  ];
  boot.resumeDevice = "/swapfile";
  boot.kernelParams = [ "resume_offset=63858427" ];

  fileSystems."/nfs/exports/photography" = {
    device = "/run/media/turbio/c3f0e164-fbc8-42c0-8127-ee16943f6ae3/photography/";
    options = [ "bind" ];
  };
  services.nfs.server = {
    enable = true;
  };
  services.nfs.server.exports = ''
    /nfs/exports 192.168.86.0/24(rw,fsid=0,no_subtree_check,crossmnt) 10.100.0.0/24(rw,fsid=0,no_subtree_check,crossmnt)
    /nfs/exports/photography 192.168.86.0/24(rw,nohide,insecure,no_subtree_check,crossmnt) 10.100.0.0/24(rw,nohide,insecure,no_subtree_check,crossmnt)
  '';

  /*
  services.home-assistant = {
    enable = true;
    config = {
      http.server_port = 8123;
      http.server_host = ["0.0.0.0"];
      homeassistant.unit_system = "imperial";
      homeassistant.temperature_unit = "F";
      homeassistant.name = "Potomac";
    };
  };
  */
}
