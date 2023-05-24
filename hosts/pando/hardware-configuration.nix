{ lib, repos, pkgs, ... }: {
  imports = [
    repos.raspberry-pi-nix.nixosModules.raspberry-pi
  ];

  nixpkgs.overlays = [
    # (final: prev: {
    #   rpi-kernels.v5_15_92 = {
    #     kernel = prev.linux_rpi4;
    #     firmware = prev.raspberrypifw;
    #     wireless-firmware = prev.rpi-kernels.latest.wireless-fw;
    #   };
    # })
  ];

  boot.kernelModules = [ "xhci_pci" "usb_storage" "usbhid" "sd_mod" ];

  # overrides the kernel set in raspberry-pi-nix but still use firmware
  # from `rpi-kernels.latest`. sure hope this isn't gonna bite me.
  #
  # upstream seems to work find and holy fuck do I not want to compile a kernel.
  boot.kernelPackages = lib.mkForce (pkgs.linuxPackagesFor pkgs.linux_rpi4);

  hardware = {
    i2c.enable = true;

    raspberry-pi = {
      i2c.enable = true;
      config = {
        all = {
          base-dt-params = {
            # enable autoprobing of bluetooth driver
            # https://github.com/raspberrypi/linux/blob/c8c99191e1419062ac8b668956d19e788865912a/arch/arm/boot/dts/overlays/README#L222-L224
            krnbt = {
              enable = true;
              value = "on";
            };
            spi = {
              enable = true;
              value = "on";
            };
          };
        };
        pi4 = {
          options = {
            arm_boost = {
              enable = true;
              value = true;
            };
          };
        };
      };
    };

    bluetooth.enable = true;
  };

  environment.systemPackages = with pkgs; [ bluez bluez-tools ];
}
