{
  config,
  pkgs,
  modulesPath,
  ...
}:
{
  swapDevices = [
    {
      label = "swap";
      options = [ "nofail" ];
    }
  ];

  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
    ../../modules/netbootable_nfs.nix
  ];

  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-intel" ];
  boot.extraModulePackages = [ ];

  # new ddr4? in this economy?
  boot.kernelParams = [
    "memmap=32M$0x468000000"
    "memmap=16M$0x2f0000000"
    "memmap=16M$0x454000000"
  ];

  services.xserver.videoDrivers = [ "nvidia" ];

  nixpkgs.config.allowUnfree = true;

  hardware.graphics = {
    enable = true;
    enable32Bit = true;

    extraPackages = with pkgs; [
      nvidia-vaapi-driver
      mesa
      libva
      libvdpau-va-gl
    ];
  };

  hardware.nvidia = {
    open = false;
    modesetting.enable = true;
    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.stable;
  };

  nixpkgs.config.nvidia.acceptLicense = true;
  nixpkgs.config.cudaSupport = true;

  boot.initrd.availableKernelModules = [
    "ehci_pci"
    "ahci"
    "usb_storage"
    "sd_mod"
    "sdhci_pci"

    "nvidia_drm"
    "nvidia_modeset"
    "nvidia"
    "nvidia_uvm"
  ];

}
