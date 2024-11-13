# Do not modify this file!  It was generated by ‘nixos-generate-config’
# and may be overwritten by future invocations.  Please make changes
# to /etc/nixos/configuration.nix instead.
{ config, lib, pkgs, modulesPath, ... }:

{

  boot.binfmt.emulatedSystems = [ "aarch64-linux" ];

  imports =
    [
      (modulesPath + "/installer/scan/not-detected.nix")
    ];

  boot.initrd.availableKernelModules = [ "xhci_pci" "nvme" "usb_storage" "sd_mod" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-intel" ];
  boot.extraModulePackages = [ ];

  fileSystems."/" =
    {
      device = "/dev/disk/by-uuid/1ad0b8db-5c9b-46c1-8dad-17adec51b4ba";
      fsType = "btrfs";
    };

  fileSystems."/boot" =
    {
      device = "/dev/disk/by-uuid/A463-D3F3";
      fsType = "vfat";
    };

  swapDevices =
    [{ device = "/dev/disk/by-uuid/9c4220c0-e8a3-4f5c-8f3e-1122b7d62623"; }];

  boot.kernelParams = [
    "rtc_cmos.use_acpi_alarm=1"
    "acpi.ec_no_wakeup=1"
  ];

  powerManagement.cpuFreqGovernor = lib.mkDefault "powersave";
  services.power-profiles-daemon = {
    enable = true;
  };
}
