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

  boot.initrd.luks.devices.cryptroot.device =
    "/dev/disk/by-uuid/83d4da9b-3225-40ff-952c-df0d923afbb5";

  fileSystems."/" =
    {
      device = "/dev/disk/by-uuid/00baf949-644f-428e-a30d-494ef0421864";
      fsType = "btrfs";
    };

  fileSystems."/boot" =
    {
      device = "/dev/disk/by-uuid/A463-D3F3";
      fsType = "vfat";
    };

  swapDevices = [
    { device = "/dev/disk/by-uuid/fcdae7e9-775c-4acc-9915-ec9ece203474"; }
  ];

  boot.kernelParams = [
    "quiet" "udev.log_level=0" 
    "plymouth.use-simpledrm"
  ];

  services.logind = {
    lidSwitch = "hibernate";
    extraConfig = ''
      HandlePowerKey=hibernate
    '';
  };
}
