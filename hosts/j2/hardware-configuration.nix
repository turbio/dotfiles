{ modulesPath, ... }:
{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
    ../../modules/netbootable_scratch.nix
  ];

  netboot.macAddresses = [
    "b8:83:03:7f:01:54"
    "b8:83:03:7f:01:54"
  ];
  netboot.storeImageFormat = "erofs";

  boot.initrd.availableKernelModules = [
    "ehci_pci"
    "ahci"
    "usb_storage"
    "sd_mod"
    "sdhci_pci"
  ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-intel" ];
  boot.extraModulePackages = [ ];
}
