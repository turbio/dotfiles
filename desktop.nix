{ config, lib, pkgs, ... }: {
  options.isDesktop = lib.mkOption {
    type = lib.types.bool;
    default = false;
  };

  config = lib.mkIf config.isDesktop {

    environment.systemPackages = (pkgs.callPackage ./packages.nix { }).desktop;

    services.xserver.enable = true;
    services.xserver.displayManager.startx.enable = true;
    programs.steam.enable = true;

    hardware.opengl.enable = true;
    hardware.opengl.driSupport = true;

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

    security.rtkit.enable = true;
    services.pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
      jack.enable = true;

      media-session.enable = true;
    };

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
        wlr.enable = true;

        extraPortals = with pkgs; [
          xdg-desktop-portal-gtk
        ];
      };
    };

    virtualisation.docker.enable = true;
  };
}
