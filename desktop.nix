{ config, lib, localpkgs, pkgs, ... }:
let
  webcam_log = pkgs.writeScriptBin "webcam-log" ''
    log_to="$HOME/Pictures/webcam_log"
    mkdir -p "$log_to"
    out_file="$log_to/$(date "+%Y_%m_%d_%H:%M:%S").jpg"

    ${pkgs.fswebcam}/bin/fswebcam -r 640x480 --jpeg 85 -D 1 --no-banner "$out_file"
  '';
in
{
  options.isDesktop = lib.mkOption {
    type = lib.types.bool;
    default = false;
  };

  config = lib.mkIf config.isDesktop {
    systemd.timers."webcam-log" = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = "1m";
        OnUnitActiveSec = "1m";
        Unit = "webcam-log.service";
      };
    };

    systemd.services."webcam-log" = {
      script = "${webcam_log}/bin/webcam-log";
      serviceConfig = {
        Type = "oneshot";
        User = "turbio";
      };
    };


    services.journald.extraConfig = ''
      MaxRetentionSec=1week
    '';

    programs.browserpass.enable = true;

    environment.systemPackages = (pkgs.callPackage ./packages.nix { inherit localpkgs; }).desktop;

    programs.steam.enable = true;

    services.xserver.enable = true;
    services.xserver.displayManager.gdm.enable = true;
    services.xserver.desktopManager.gnome.enable = true;
    services.udev.packages = with pkgs; [ gnome.gnome-settings-daemon ];
    programs.dconf.enable = true;

    hardware.pulseaudio.enable = false;

    hardware.opengl.enable = true;
    hardware.opengl.driSupport = true;

    networking.networkmanager.enable = true;

    virtualisation.virtualbox.host.enable = true;
    virtualisation.virtualbox.host.enableExtensionPack = true;
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

    programs.adb.enable = true;
    users.users.turbio.extraGroups = [ "adbusers" ];

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
    };

    programs.gnupg.agent.pinentryFlavor = "gnome3";

    #environment.variables.GTK_USE_PORTAL = "1";
    #environment.variables.GDK_BACKEND = "wayland";

    #systemd.user.services.xdg-desktop-portal.wantedBy = [ "default.target" ];
    #systemd.user.services.xdg-desktop-portal-wlr.wantedBy = [ "default.target" ];

    #systemd.user.services.xdg-desktop-portal.environment = {
    #  XDG_DESKTOP_PORTAL_DIR = config.environment.variables.XDG_DESKTOP_PORTAL_DIR;
    #};

    #xdg = {
    #  portal = {
    #    enable = true;
    #    gtkUsePortal = true;
    #    #wlr.enable = true;

    #    extraPortals = with pkgs; [
    #      xdg-desktop-portal-wlr
    #      xdg-desktop-portal-gtk
    #    ];
    #  };
    #};

    virtualisation.docker.enable = true;
  };
}
