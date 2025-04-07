{ ... }: {
  isDesktop = true;

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.interfaces.enp0s25.useDHCP = true;
  networking.interfaces.wlp3s0.useDHCP = true;

  fileSystems."/sync" = {
    device = "192.168.86.113:/mnt/sync";
    fsType = "nfs";
    options = [
      "rw"
      "noatime"
    ];
  };
}
