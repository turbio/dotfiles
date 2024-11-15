{ pkgs, ... }: {
  isDesktop = true;

  services.fwupd.enable = true;

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.timeout = 0;

  boot.initrd.verbose = false;
  boot.initrd.systemd.enable = true;
  boot.consoleLogLevel = 0;

  boot.plymouth = {
    enable = true;
    themePackages = [ pkgs.catppuccin-plymouth ];
    theme = "catppuccin-macchiato";
    font = "${pkgs.terminus_font}/share/fonts/terminus/ter-u18n.otb";
    extraConfig = ''
      DeviceScale=1
    '';
  };

  networking.interfaces.wlp1s0.useDHCP = true;

  hardware.bluetooth.enable = true;
  services.blueman.enable = true;

  programs.light.enable = true;

  boot.initrd.kernelModules = [ ];

  programs.hyprland.enable = true;

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
