{ modulesPath, ... }:
{
  imports = [ (modulesPath + "/profiles/qemu-guest.nix") ];
  boot.loader.grub.device = "/dev/xvda";
  boot.initrd.availableKernelModules = [ "ata_piix" "uhci_hcd" "xen_blkfront" "vmw_pvscsi" ];
  boot.initrd.kernelModules = [ "nvme" ];
  fileSystems."/" = { device = "/dev/xvda1"; fsType = "ext4"; };

}
