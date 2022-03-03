{ config, pkgs, ... }: {
  isDesktop = true;

  # boot.kernelPackages = pkgs.linuxPackages_5_14;

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.interfaces.enp0s31f6.useDHCP = true;
}
