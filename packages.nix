{ pkgs, fetchurl, ... }:
let
  mars-ide =
    pkgs.callPackage
      ({ lib, stdenvNoCC, fetchurl, makeWrapper, copyDesktopItems, makeDesktopItem, unzip, imagemagick, jre }:

        stdenvNoCC.mkDerivation rec {
          pname = "mars-mips";
          version = "4.5";

          src = fetchurl {
            url = "https://courses.missouristate.edu/KenVollmar/MARS/MARS_${lib.replaceStrings ["."] ["_"] version}_Aug2014/Mars${lib.replaceStrings ["."] ["_"] version}.jar";
            sha256 = "15kh1fahkkbbf4wvb6ijzny4fi5dh4pycxyzp5325dm2ddkhnd5c";
          };

          dontUnpack = true;

          nativeBuildInputs = [ makeWrapper copyDesktopItems unzip imagemagick ];

          desktopItems = [
            (makeDesktopItem {
              name = pname;
              desktopName = "MARS";
              exec = "mars-mips";
              icon = "mars-mips";
              comment = "An IDE for programming in MIPS assembly language";
              categories = "Development;IDE;";
            })
          ];

          installPhase = ''
            runHook preInstall
            export JAR=$out/share/java/${pname}/${pname}.jar
            install -D $src $JAR
            makeWrapper ${jre}/bin/java $out/bin/${pname} \
              --add-flags "-jar $JAR"
            unzip ${src} images/MarsThumbnail.gif
            mkdir -p $out/share/pixmaps
            convert images/MarsThumbnail.gif $out/share/pixmaps/mars-mips.png
            runHook postInstall
          '';

          meta = with lib; {
            description = "An IDE for programming in MIPS assembly language intended for educational-level use";
            homepage = "https://courses.missouristate.edu/KenVollmar/MARS/";
            license = licenses.mit;
            maintainers = with maintainers; [ angustrau ];
            platforms = platforms.all;
          };
        })
      { };
in
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

    mars-ide

    prusa-slicer
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
  ];
}
