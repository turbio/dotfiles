{ config, lib, localpkgs, pkgs, ... }:
let
  # bash script to let dbus know about important env variables and
  # propagate them to relevent services run at the end of sway config
  # see
  # https://github.com/emersion/xdg-desktop-portal-wlr/wiki/"It-doesn't-work"-Troubleshooting-Checklist
  # note: this is pretty much the same as  /etc/sway/config.d/nixos.conf but also restarts  
  # some user services to make sure they have the correct environment variables
  dbus-sway-environment = pkgs.writeTextFile {
    name = "dbus-sway-environment";
    destination = "/bin/dbus-sway-environment";
    executable = true;

    text = ''
      dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP=sway
      systemctl --user restart pipewire wireplumber xdg-desktop-portal xdg-desktop-portal-wlr
    '';
  };
  webcam_log = pkgs.writeScriptBin "webcam-log" ''
    log_to="$HOME/Pictures/webcam_log"
    mkdir -p "$log_to"
    out_file="$log_to/$(date "+%Y_%m_%d_%H:%M:%S").jpg"

    ${pkgs.fswebcam}/bin/fswebcam -r 640x480 --jpeg 85 -D 1 --no-banner "$out_file"
  '';
  # currently, there is some friction between sway and gtk:
  # https://github.com/swaywm/sway/wiki/GTK-3-settings-on-Wayland
  # the suggested way to set gtk settings is with gsettings
  # for gsettings to work, we need to tell it where the schemas are
  # using the XDG_DATA_DIR environment variable
  # run at the end of sway config
  configure-gtk = pkgs.writeTextFile {
    name = "configure-gtk";
    destination = "/bin/configure-gtk";
    executable = true;
    text =
      let
        schema = pkgs.gsettings-desktop-schemas;
        datadir = "${schema}/share/gsettings-schemas/${schema.name}";
      in
      ''
        export XDG_DATA_DIRS=${datadir}:$XDG_DATA_DIRS
        gnome_schema=org.gnome.desktop.interface
        gsettings set $gnome_schema gtk-theme 'Dracula'
      '';
  };
in
{
  options.isDesktop = lib.mkOption {
    type = lib.types.bool;
    default = false;
  };

  config = lib.mkIf config.isDesktop {
    services.automatic-timezoned.enable = true;

    # automount attached storage
    services.gvfs.enable = true;
    services.udisks2.enable = true;
    services.devmon.enable = true;

    hardware.saleae-logic.enable = true;

    services.tzupdate.enable = true;

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

    environment.systemPackages = (pkgs.callPackage ./packages.nix { inherit localpkgs; }).desktop ++ [
      dbus-sway-environment
      configure-gtk
    ];

    programs.steam.enable = true;

    #services.xserver.enable = true;
    #services.xserver.displayManager.gdm.enable = true;
    #services.xserver.desktopManager.gnome.enable = true;
    #services.udev.packages = with pkgs; [ gnome.gnome-settings-daemon ];

    programs.dconf.enable = true;

    hardware.pulseaudio.enable = false;

    hardware.opengl.enable = true;
    hardware.opengl.driSupport = true;

    networking.networkmanager.enable = true;

    #virtualisation.virtualbox.host.enable = true;
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

    #programs.gnupg.agent.pinentryFlavor = "gnome3";

    #environment.variables.GTK_USE_PORTAL = "1";
    #environment.variables.GDK_BACKEND = "wayland";

    #systemd.user.services.xdg-desktop-portal.wantedBy = [ "default.target" ];
    #systemd.user.services.xdg-desktop-portal-wlr.wantedBy = [ "default.target" ];

    #systemd.user.services.xdg-desktop-portal.environment = {
    #  XDG_DESKTOP_PORTAL_DIR = config.environment.variables.XDG_DESKTOP_PORTAL_DIR;
    #};

    security.polkit.enable = true;

    services.dbus.enable = true;
    xdg = {
      portal = {
        enable = true;
        #wlr.enable = true;

        #gtkUsePortal = true;

        extraPortals = with pkgs; [
          #xdg-desktop-portal-wlr
          xdg-desktop-portal-gtk
        ];
      };
    };

    # services.xserver = {
    #   enable = true;
    #   displayManager.gdm.enable = true;
    #   displayManager.gdm.wayland = false;
    #   desktopManager.gnome.enable = true;
    # };


    #virtualisation.docker.enable = true;
  };
}
