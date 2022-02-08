{ config, pkgs, ... }: {
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.interfaces.wlan0.useDHCP = true;

  networking.networkmanager.enable = true;
}
