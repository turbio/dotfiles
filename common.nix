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
    ];

    programs.sway = {
      enable = true;
      wrapperFeatures.gtk = true;
    };

    services.pipewire.enable = true;

    programs.gnupg.agent.pinentryFlavor = "gnome3";

    xdg = {
      portal = {
        enable = true;
        extraPortals = with pkgs; [
          xdg-desktop-portal-wlr
        ];
        gtkUsePortal = true;
      };
    };
    virtualisation.docker.enable = true;
  };
}
