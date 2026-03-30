{
  modulesPath,
  ...
}:
{
  netboot.macAddresses = [ "f0:de:f1:fc:33:aa" ];
  netboot.storeImageFormat = "erofs";

  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

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
