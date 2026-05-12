{
  config,
  lib,
  pkgs,
  modulesPath,
  ...
}:
{
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

  boot.loader.grub.enable = false;

  boot.kernelParams = [ "zfs.zfs_arc_sys_free=8589934592" ];

  boot.supportedFilesystems = [ "zfs" ];
  boot.zfs.extraPools = [ "tank" ];
  networking.hostId = "00ba1105";

  boot.initrd.availableKernelModules = [
    "ahci"
    "ehci_pci"
    "usbhid"
    "sd_mod"
  ];
  boot.initrd.kernelModules = [
    "kvm-intel"

    # is my sas controller fucked??? takes mintues to init but userspace gets
    # fucked up without it so we'll let initrd do the waiting
    "mpt3sas"
  ];
  boot.kernelModules = [ ];

  networking.useNetworkd = true;

  networking.bonds.bond0 = {
    interfaces = [
      "enp4s0f0"
      "enp4s0f1"
    ];
    driverOptions = {
      mode = "802.3ad";
      miimon = "100";
      lacp_rate = "fast";
      xmit_hash_policy = "layer3+4";
    };
  };
  networking.interfaces.bond0.useDHCP = true;

  systemd.network.networks."40-bond0".dhcpV4Config.RouteMetric = 100;
  systemd.network.networks."50-eno1" = {
    matchConfig.Name = "eno1";
    networkConfig.DHCP = "yes";
    dhcpV4Config.RouteMetric = 2000;
  };

  services.resolved.enable = true;
  services.resolved.llmnr = "false";
  services.resolved.extraConfig = ''
    MulticastDNS=no
  '';

  disko.devices.disk.main = {
    type = "disk";
    content = {
      type = "gpt";
      partitions = {
        ESP = {
          type = "EF00";
          size = "500M";
          content = {
            type = "filesystem";
            format = "vfat";
            mountpoint = "/boot";
            mountOptions = [ "umask=0077" ];
          };
        };
        root = {
          size = "100%";
          content = {
            type = "filesystem";
            format = "ext4";
            mountpoint = "/";
          };
        };
        swap = {
          size = "256G";
          content = {
            type = "swap";
            resumeDevice = true;
          };
        };
      };
    };
  };

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
