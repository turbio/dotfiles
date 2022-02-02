{ pkgs, ... }: {
  isDesktop = true;

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.interfaces.enp0s31f6.useDHCP = true;
  networking.interfaces.wlp0s20f3.useDHCP = true;

  hardware.bluetooth.enable = true;
  services.blueman.enable = true;

  programs.light.enable = true;

  systemd.services.keyboard-backlight = {
    description = "i just want my keys to glow";
    script = ''
      echo 2 | tee /sys/class/leds/tpacpi::kbd_backlight/brightness
    '';

    after = [
      "suspend.target"
      "hibernate.target"
      "hybrid-sleep.target"
      "suspend-then-hibernate.target"
    ];

    wantedBy = [
      "multi-user.target"

      "suspend.target"
      "hibernate.target"
      "hybrid-sleep.target"
      "suspend-then-hibernate.target"
    ];
  };
}
