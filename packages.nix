{ pkgs, ... }: {
  desktop = with pkgs; [
    nixpkgs-fmt
    firefox-wayland
    chromium
    alacritty
    pavucontrol
    discord
    blueberry
    spotify
    mako # notification daemon
    pass
    yubikey-manager
    yubikey-agent
    yubioath-desktop

    lxappearance
    gtk_engines
    gtk-engine-murrine
    gsettings-desktop-schemas
    lsb-release

    arc-theme

    # wayland
    wdisplays
    flashfocus
    xdg-desktop-portal-wlr
    xdg-utils
    gnome.dconf-editor
    swaylock
    swayidle

    wineWowPackages.staging

    # waybar stuff
    (waybar.override { withMediaPlayer = true; })
    playerctl
    libappindicator

    # gdbus
    glib

    docker-compose
    vagrant
    ansible

    gnome.nautilus
    gnome.file-roller

    qemu

    obs-studio
    obs-wlrobs
    obs-v4l2sink
    zoom-us
    gimp

    slurp
    grim
    wl-clipboard

    aseprite
    gnome.eog
    mpv

    steam
    bspwm
    sxhkd

    openscad

    cargo
    rustc
    rustup
    nodejs

    clang
    gcc
    go

    wev
    xorg.xev
    xdotool
  ];

  core = with pkgs; [
    wget
    git
    htop
    busybox
    zsh
    ag

    gnumake
    gdb

    jq

    cloc

    ncdu

    bind.dnsutils
  ];
}
