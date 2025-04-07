{ config, lib, pkgs, modulesPath, ... }: {
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

  boot.loader.grub.enable = false;

  # i love running unstable filesystems <3
  boot.extraModulePackages = with config.boot.kernelPackages; [ zfs_unstable ];
  boot.zfs.package = pkgs.zfs_unstable;
  boot.kernelParams = [ "zfs..zfs_arc_sys_free=40221225472" ];

  boot.supportedFilesystems = [ "zfs" ];
  boot.zfs.extraPools = [ "pool" ];
  networking.hostId = "00ba1105";

  boot.initrd.availableKernelModules = [ "ahci" "ehci_pci" "usbhid" "sd_mod" ];
  boot.initrd.kernelModules = [
    "kvm-intel"

    # is my sas controller fucked??? takes mintues to init but it's easier than
    # waiting in userspace
    "mpt3sas"
  ];
  boot.kernelModules = [ ];

  fileSystems = {
    "/mnt/cache" = {
      device = "/dev/disk/by-uuid/bcd790b4-e025-47a6-9271-285c7cea4489";
    };
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
  #networking.interfaces.enp4s0.useDHCP = true;
  # networking.interfaces.eno1.useDHCP = lib.mkDefault true;
  # networking.interfaces.eno2.useDHCP = lib.mkDefault true;
  # networking.interfaces.eno3.useDHCP = lib.mkDefault true;
  # networking.interfaces.eno4.useDHCP = lib.mkDefault true;

  services.resolved.enable = true;
  services.resolved.llmnr = "false";
  services.resolved.extraConfig = ''
    MulticastDNS=no
  '';

  networking.useNetworkd = true;
  systemd.network.enable = true;
  systemd.network.networks."10-wan" = {
    matchConfig.Name = "enp4s0";
    networkConfig.DHCP = "yes";
    networkConfig.IPv6AcceptRA = true;
    linkConfig.RequiredForOnline = "routable";
  };
  systemd.network.networks."10-wg" = {
    matchConfig.Name = "wg0";
    networkConfig = {
      Address = "10.100.0.10/24";
      DHCP = "no";
      #Gateway = "10.100.0.1";
      #DNS = "10.100.0.1";
    };
    linkConfig.RequiredForOnline = "no";
  };

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
