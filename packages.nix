{ pkgs, ... }:
{
  desktop = with pkgs; [
    #urbit

    _1password-gui
    _1password-cli

    uhubctl
    fwupd

    discord
    element-desktop

    nixpkgs-fmt
    chromium
    alacritty
    pavucontrol
    blueberry
    spotify
    pass
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
    mako
    swaybg
    xwayland-satellite # x under niri
    syncthingtray
    wf-recorder

    # bluetooth tray

    # network manager tray
    networkmanagerapplet

    # need pactl for sway stuff
    pulseaudio

    wineWowPackages.staging

    # waybar stuff
    (waybar.override { withMediaPlayer = true; })
    playerctl
    libappindicator
    wofi

    polkit
    polkit_gnome

    # gdbus
    glib

    docker-compose
    vagrant

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
    rust-analyzer

    wev
    xorg.xev
    xdotool

    mars-mips

    prusa-slicer
    orca-slicer

    arduino

    saleae-logic-2

    darktable
    kdenlive
    ocl-icd

    cubicsdr
    ffmpeg
    gnome-power-manager
    gparted
    gnupg
    inkscape
    imagemagick
    lan-mouse
    logisim
  ];

  core = with pkgs; [
    wget
    git
    htop
    busybox
    zsh
    fish
    silver-searcher
    pv

    gnumake
    gdb

    jq

    cloc

    ncdu
    dfc

    bind.dnsutils
    linuxPackages.perf
    iptables
    nftables

    entr

    man-pages
    man-pages-posix

    tmux
    wireguard-tools

    # should all my machines really have nix tooling???
    nil
    nixfmt-rfc-style

    iperf
    iotop
    nethogs
    nmap
    progress
  ];
}
