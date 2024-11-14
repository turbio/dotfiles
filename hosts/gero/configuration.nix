{ pkgs, ... }: {
  isDesktop = true;

  services.fwupd.enable = true;

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.timeout = 0;

  boot.plymouth.enable = true;
  boot.plymouth.themePackages = [ pkgs.catppuccin-plymouth ];
  boot.plymouth.theme = "catppuccin-macchiato";
  boot.plymouth.font = "${pkgs.terminus_font}/share/fonts/terminus/ter-u18n.otb";
  boot.plymouth.extraConfig = ''
    DeviceScale=1
  '';
  boot.initrd.verbose = false;
  boot.initrd.systemd.enable = true;
  boot.consoleLogLevel = 0;

  networking.interfaces.wlp1s0.useDHCP = true;

  hardware.bluetooth.enable = true;
  services.blueman.enable = true;

  programs.light.enable = true;

  boot.initrd.kernelModules = [ ];

  services.logind = {
    lidSwitch = "hibernate";
    extraConfig = ''
      HandlePowerKey=hibernate
      HandleSuspendKey=hibernate
      HandleHibernateKey=hibernate
    '';
  };

  services.syncthing = {
    enable = true;
    configDir = "/home/turbio/.config/syncthing";
    dataDir = "/home/turbio";
    settings.folders = {
      "photos" = { enable = true; path = "~/photos"; };
      "code" = { enable = true; path = "~/code"; };
    };
  };
}
