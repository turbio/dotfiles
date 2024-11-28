{ config, lib, pkgs, modulesPath, ... }: {
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

  boot.loader.grub.enable = false;

  boot.initrd.availableKernelModules = [ "ahci" "ehci_pci" "usbhid" "sd_mod" ];
  boot.initrd.kernelModules = [
    "dm-snapshot"
    "dm-raid"
    "dm-cache"
    "raid5"
    "dm-cache-default"
    "kvm-intel"

    # is my sas controller fucked??? takes mintues to init but it's easier than
    # waiting in userspace
    "mpt3sas"
  ];
  boot.kernelModules = [ ];
  boot.extraModulePackages = [ ];

  fileSystems = {
    "/" = {
      device = "/dev/disk/by-label/nixos";
    };
    "/boot" = {
      device = "/dev/disk/by-label/boot";
      fsType = "vfat";
      options = [ "fmask=0022" "dmask=0022" ];
    };
  };

  swapDevices = [
    { device = "/dev/disk/by-label/swap"; }
  ];

  /*
  fileSystems = {
    "/" = {
      device = "tmproot";
      fsType = "tmpfs";
      options = [ "defaults" "mode=755" "size=50%" ];
    };
    "/nix/store" = {
      device = "/dev/disk/by-label/nix-store";
    };
    "/boot" = {
      device = "/dev/disk/by-label/BOOT";
    };
  };

  swapDevices = [ ];
  */

  # Enables DHCP on each ethernet and wireless interface. In case of scripted networking
  # (the default) this is the recommended approach. When using systemd-networkd it's
  # still possible to use this option, but it's recommended to use it in conjunction
  # with explicit per-interface declarations with `networking.interfaces.<interface>.useDHCP`.
  networking.useDHCP = true;
  # networking.interfaces.eno1.useDHCP = lib.mkDefault true;
  # networking.interfaces.eno2.useDHCP = lib.mkDefault true;
  # networking.interfaces.eno3.useDHCP = lib.mkDefault true;
  # networking.interfaces.eno4.useDHCP = lib.mkDefault true;

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
