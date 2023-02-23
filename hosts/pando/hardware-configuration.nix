{ config, lib, pkgs, modulesPath, ... }: {
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

  boot.kernelModules = [ ];
  boot.extraModulePackages = [ ];

  boot = {
    kernelPackages = pkgs.linuxPackages_rpi4;
    tmpOnTmpfs = true;
    initrd.availableKernelModules = [ "usbhid" "usb_storage" ];
    kernelParams = [
      "iomem=relaxed"

      "8250.nr_uarts=1"
      "console=ttyAMA0,115200"
      "console=tty1"
      # A lot GUI programs need this, nearly all wayland applications
      "cma=128M"
    ];
  };

  boot.loader.raspberryPi = {
    enable = true;
    version = 4;
    firmwareConfig = ''
      # For more options and information see
      # http://rpf.io/configtxt
      # Some settings may impact device functionality. See link above for details

      # uncomment if you get no picture on HDMI for a default "safe" mode
      #hdmi_safe=1

      # uncomment the following to adjust overscan. Use positive numbers if console
      # goes off screen, and negative if there is too much border
      #overscan_left=16
      #overscan_right=16
      #overscan_top=16
      #overscan_bottom=16

      # uncomment to force a console size. By default it will be display's size minus
      # overscan.
      #framebuffer_width=1280
      #framebuffer_height=720

      # uncomment if hdmi display is not detected and composite is being output
      #hdmi_force_hotplug=1

      # uncomment to force a specific HDMI mode (this will force VGA)
      #hdmi_group=1
      #hdmi_mode=1

      # uncomment to force a HDMI mode rather than DVI. This can make audio work in
      # DMT (computer monitor) modes
      #hdmi_drive=2

      # uncomment to increase signal to HDMI, if you have interference, blanking, or
      # no display
      #config_hdmi_boost=4

      # uncomment for composite PAL
      #sdtv_mode=2

      #uncomment to overclock the arm. 700 MHz is the default.
      #arm_freq=800

      # Uncomment some or all of these to enable the optional hardware interfaces
      #dtparam=i2c_arm=on
      #dtparam=i2s=on
      #dtparam=spi=on

      # Uncomment this to enable infrared communication.
      #dtoverlay=gpio-ir,gpio_pin=17
      #dtoverlay=gpio-ir-tx,gpio_pin=18

      # Additional overlays and parameters are documented /boot/overlays/README

      # Enable audio (loads snd_bcm2835)
              dtparam=audio=on

      # Automatically load overlays for detected cameras
              camera_auto_detect=1

      # Automatically load overlays for detected DSI displays
              display_auto_detect=1

      # Enable DRM VC4 V3D driver
              dtoverlay=vc4-kms-v3d
              max_framebuffers=2

      # Run in 64-bit mode
              arm_64bit=1

      # Disable compensation for displays with overscan
              disable_overscan=1

              [cm4]
      # Enable host mode on the 2711 built-in XHCI USB controller.
      # This line should be removed if the legacy DWC2 controller is required
      # (e.g. for USB device mode) or if USB support is not required.
              otg_mode=1

              [all]

              [pi4]
      # Run as fast as firmware / board allows
              arm_boost=1

              [all]
    '';
  };

  #boot.loader.generic-extlinux-compatible.enable = true;
  boot.loader.grub.enable = false;

  #hardware.raspberry-pi."4".i2c1.enable = true;

  hardware = {
    i2c.enable = true;
  };

  # defined in sd-image module
  # fileSystems."/" = {
  #   device = "/dev/disk/by-uuid/44444444-4444-4444-8888-888888888888";
  #   fsType = "ext4";
  # };
  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/2178-694E";
    fsType = "vfat";
  };

  swapDevices = [ ];

  hardware.enableRedistributableFirmware = true;


  networking.useDHCP = lib.mkDefault true;

  powerManagement.cpuFreqGovernor = lib.mkDefault "ondemand";

  services.udev.extraRules = ''
    SUBSYSTEM=="bcm2835-gpiomem", KERNEL=="gpiomem", GROUP="gpio",MODE="0660"
    SUBSYSTEM=="gpio", KERNEL=="gpiochip*", ACTION=="add", RUN+="${pkgs.bash}/bin/bash -c 'chown root:gpio  /sys/class/gpio/export /sys/class/gpio/unexport ; chmod 220 /sys/class/gpio/export /sys/class/gpio/unexport'"
    SUBSYSTEM=="gpio", KERNEL=="gpio*", ACTION=="add",RUN+="${pkgs.bash}/bin/bash -c 'chown root:gpio /sys%p/active_low /sys%p/direction /sys%p/edge /sys%p/value ; chmod 660 /sys%p/active_low /sys%p/direction /sys%p/edge /sys%p/value'"
  '';
}
