{ pkgs, localpkgs, ... }:
{
  desktop = with pkgs; [
    #urbit

    uhubctl
    fwupd

    discord
    nixpkgs-fmt
    #firefox-wayland
    firefox
    chromium
    alacritty
    pavucontrol
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
    xdg-utils
    gnome.dconf-editor
    swaylock
    swayidle
    # need pactl for sway stuff
    pulseaudio

    wineWowPackages.staging

    # waybar stuff
    (waybar.override { withMediaPlayer = true; })
    playerctl
    libappindicator

    polkit
    polkit_gnome

    # gdbus
    glib

    docker-compose
    vagrant
    ansible

    gnome.nautilus
    gnome.file-roller

    qemu

    obs-studio-plugins.wlrobs
    obs-studio
    linuxPackages.v4l2loopback
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

    mars-mips

    prusa-slicer

    arduino

    wireshark

    openra
  ];

  core = with pkgs; [
    wget
    git
    htop
    busybox
    zsh
    fish
    silver-searcher

    gnumake
    gdb

    jq

    cloc

    ncdu

    bind.dnsutils
    linuxPackages.perf
    iptables

    entr

    man-pages
    man-pages-posix

    tmux
    wireguard-tools
  ];
}
