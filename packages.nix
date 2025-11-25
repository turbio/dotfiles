{ pkgs, ... }:
rec {
  extra = with pkgs; [
    obs-studio-plugins.wlrobs
    obs-studio
    zoom-us
    chromium
    aseprite
    cubicsdr
    darktable

    #saleae-logic-2
    qemu

    clang
    gcc
    go
    rust-analyzer

    vagrant
    steam

    openscad
    mars-mips

    wineWowPackages.staging

    prusa-slicer
    orca-slicer

    element-desktop
    discord

    arduino

    inkscape

    wf-recorder

    spotify

    obsidian
  ];

  desktop =
    with pkgs;
    [
      urbit

      _1password-gui
      _1password-cli

      uhubctl
      fwupd

      nix-output-monitor

      nixpkgs-fmt
      kitty
      neovide
      pavucontrol
      blueberry
      pass
      gtk_engines
      gtk-engine-murrine
      gsettings-desktop-schemas
      lsb-release

      arc-theme

      # wayland
      wdisplays
      flashfocus
      xdg-utils
      dconf-editor
      swaylock
      syncthingtray

      # network manager tray
      networkmanagerapplet

      # need pactl for sway stuff
      pulseaudio

      # waybar stuff
      waybar-mpris
      playerctl
      libappindicator

      polkit
      polkit_gnome

      # gdbus
      glib

      docker-compose

      nautilus
      file-roller

      linuxPackages.v4l2loopback
      gimp

      niri
      ghostty
      mako
      alacritty
      fuzzel
      waybar

      slurp
      grim
      wl-clipboard

      eog
      mpv

      wev
      xorg.xev
      xdotool

      ocl-icd

      ffmpeg
      gnome-power-manager
      gparted
      gnupg
      imagemagick
      lan-mouse
      logisim
    ]
    ++ extra;

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

    iperf
    iotop
    nethogs
    nmap
    progress
    nixos-firewall-tool

    comma

    shellcheck
  ];
}
