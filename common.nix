{ config, lib, pkgs, ... }: {
  options.isDesktop = lib.mkOption {
    type = lib.types.bool;
    default = false;
  };

  config = lib.mkIf config.isDesktop {
    nixpkgs.config.pulseaudio = true;
    hardware.pulseaudio.enable = true;

    networking.networkmanager.enable = true;

    virtualisation.virtualbox.host.enable = true;
    #virtualisation.virtualbox.host.enableExtensionPack = true;
    users.extraGroups.vboxusers.members = [ "turbio" ];

    services.yubikey-agent.enable = true;
    services.pcscd.enable = true;

    fonts.fonts = with pkgs; [
      terminus_font
      terminus_font_ttf
      font-awesome
      noto-fonts
      noto-fonts-emoji
      roboto
    ];

    programs.sway = {
      enable = true;
      wrapperFeatures.gtk = true;
    };

    services.pipewire.enable = true;

    programs.gnupg.agent.pinentryFlavor = "gnome3";

    environment.variables.GTK_USE_PORTAL = "1";
    environment.variables.GDK_BACKEND = "wayland";

    systemd.user.services.xdg-desktop-portal.wantedBy = [ "default.target" ];
    systemd.user.services.xdg-desktop-portal-wlr.wantedBy = [ "default.target" ];

    systemd.user.services.xdg-desktop-portal.environment = {
      XDG_DESKTOP_PORTAL_DIR = config.environment.variables.XDG_DESKTOP_PORTAL_DIR;
    };

    xdg = {
      portal = {
        enable = true;
        gtkUsePortal = true;
        extraPortals = with pkgs; [
          xdg-desktop-portal-wlr
          xdg-desktop-portal-gtk
        ];
      };
    };
    virtualisation.docker.enable = true;
  };
}
