{ lib, ... }:
{
  isDesktop = true;

  boot.loader.efi.canTouchEfiVariables = true;
  networking.useDHCP = lib.mkForce true;

  netboot.formatFirstAvailableDisk = true;
}
