{ pkgs, ... }: {
  isDesktop = true;

  services.fwupd.enable = true;

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.interfaces.wlp1s0.useDHCP = true;

  hardware.bluetooth.enable = true;
  services.blueman.enable = true;

  programs.light.enable = true;

  boot.initrd.kernelModules = [ "amdgpu" ];

  #hardware.opengl.extraPackages = with pkgs; [
    #rocmPackages.clr.icd
  #];

  services.logind = {
    lidSwitch = "suspend";
    extraConfig = ''
      HandlePowerKey=ignore
      HandleSuspendKey=ignore
      HandleHibernateKey=ignore
    '';
  };

  /*
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
  */
}
