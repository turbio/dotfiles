{ pkgs, localpkgs, fetchurl, ... }:
{
  desktop = with pkgs; [
    discord
    nixpkgs-fmt
    firefox-wayland
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
    pulseaudioLight

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

    (appimageTools.wrapType2 {
      name = "openra";
      src = fetchurl
        {
          url = "https://github.com/OpenRA/OpenRA/releases/download/release-20210321/OpenRA-Red-Alert-x86_64.AppImage";
          sha256 = "sha256-toJ416/V0tHWtEA0ONrw+JyU+ssVHFzM6M8SEJPIwj0=";
        };
    })

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
    linuxPackages.perf
    iptables

    entr

    man-pages
    man-pages-posix

    tmux
  ];
}
