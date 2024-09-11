{ hostname, config, localpkgs, pkgs, unstablepkgs, ... }:
let
  packageset = pkgs.callPackage ./packages.nix { inherit localpkgs; };
in
{
  nixpkgs.overlays = [
    (final: prev: {
      #openra = unstablepkgs.openra;
      #bambu-studio = unstablepkgs.bambu-studio;
      #orca-slicer = unstablepkgs.orca-slicer;
    })

    (final: prev: {
      #saleae-logic-2 = prev.saleae-logic-2.overrideAttrs (old: {
      #src = pkgs.fetchurl {
      #url = "https://downloads.saleae.com/logic2/Logic-2.4.10-linux-x64.AppImage";
      #hash = "sha256-aKD1va9ODPWtTBI3vuqjCSne+Y4DWicMkNBlcb6OJyk=";
      #};
      #});

      saleae-logic-2 =
        let
          name = "saleae-logic-2";
          version = "2.4.10";
          src = pkgs.fetchurl {
            url = "https://downloads.saleae.com/logic2/Logic-${version}-linux-x64.AppImage";
            hash = "sha256-aKD1va9ODPWtTBI3vuqjCSne+Y4DWicMkNBlcb6OJyk=";
          };
          desktopItem = pkgs.makeDesktopItem {
            inherit name;
            exec = name;
            icon = "Logic";
            comment = "Software for Saleae logic analyzers";
            desktopName = "Saleae Logic";
            genericName = "Logic analyzer";
            categories = [ "Development" ];
          };
        in
        pkgs.appimageTools.wrapType2 {
          inherit name src;

          extraInstallCommands =
            let
              appimageContents = pkgs.appimageTools.extractType2 { inherit name src; };
            in
            ''
              mkdir -p $out/etc/udev/rules.d
              cp ${appimageContents}/resources/linux-x64/99-SaleaeLogic.rules $out/etc/udev/rules.d/
              mkdir -p $out/share/pixmaps
              ln -s ${desktopItem}/share/applications $out/share/
              cp ${appimageContents}/usr/share/icons/hicolor/256x256/apps/Logic.png $out/share/pixmaps/Logic.png
            '';

          extraPkgs = pkgs: with pkgs; [
            wget
            unzip
            glib
            xorg.libX11
            xorg.libxcb
            xorg.libXcomposite
            xorg.libXcursor
            xorg.libXdamage
            xorg.libXext
            xorg.libXfixes
            xorg.libXi
            xorg.libXrender
            xorg.libXtst
            nss
            nspr
            dbus
            gdk-pixbuf
            gtk3
            pango
            atk
            cairo
            expat
            xorg.libXrandr
            xorg.libXScrnSaver
            alsa-lib
            at-spi2-core
            cups
            libxcrypt-legacy
          ];

          meta = with pkgs.lib; {
            homepage = "https://www.saleae.com/";
            description = "Software for Saleae logic analyzers";
            license = licenses.unfree;
            platforms = [ "x86_64-linux" ];
            maintainers = with maintainers; [ j-hui newam ];
          };
        };
    })
  ];

  #nix.autoOptimiseStore = true;

  nixpkgs.config.allowUnfree = true;

  nix = {
    package = pkgs.nixVersions.latest;
    extraOptions = ''
      experimental-features = nix-command flakes
    '';
  };

  networking.hostName = hostname;

  i18n.defaultLocale = "en_US.UTF-8";

  environment.systemPackages = packageset.core;

  users.mutableUsers = false;
  security.sudo.wheelNeedsPassword = false;
  users.users.turbio = {
    home = "/home/turbio";
    isNormalUser = true;
    extraGroups = [
      "wheel"
      "networkmanager"
      "docker"
      "audio"
      "video"
      "wireshark"
      "dialout" # /dev/tty stuff
      "rfkill" # gotta poke some devices
      "input" # spooky haxxxx for push to talk

      # raspi stuff
      "gpio"
      "i2c"
    ];
    uid = 1000;

    # probably a bad idea lmao
    hashedPassword = "$6$UnnB5IybU$cBw9zHoM7xTdwyXnAAbeXOGoqQQtzbYsuPqTDjpGF3J3H3WaarzAEtoBxXOImZlmmzY2amSqSgwUbEP0.ma3w0";

    #shell = pkgs.zsh;
    shell = pkgs.fish;
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIONmQgB3t8sb7r+LJ/HeaAY9Nz2aPS1XszXTub8A1y4n turbio"
    ];
  };

  programs.fish = {
    enable = true;
  };

  programs.mtr.enable = true;

  #programs.gnupg.agent = {
  #enable = true;
  #enableSSHSupport = true;
  #};

  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = false;
  };

  services.chrony.enable = true;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "21.05"; # Did you read the comment?
}
