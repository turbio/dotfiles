{ lib, hostname, localpkgs, pkgs, ... }:
let
  packageset = pkgs.callPackage ./packages.nix { inherit localpkgs; };
in
{
  services.fwupd.enable = true;

  nixpkgs.overlays = [
    (final: prev: {
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

  networking.hosts = { # TODO: ewww
    "10.100.0.10" = [
      "int.turb.io"
      "bt.int.turb.io"
      "jelly.int.turb.io"
      "ollama.int.turb.io"
      "sync.int.turb.io"
      "home.int.turb.io"
      "nixcache.turb.io"
    ];
  };


  nixpkgs.config.allowUnfree = true;

  nix = {
    #autoOptimiseStore = true;

    settings = {
      trusted-users = [ "turbio" ];

    };
    package = pkgs.nixVersions.latest;
    extraOptions = ''
      experimental-features = nix-command flakes pipe-operators ca-derivations
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

  programs.mosh.enable = true;

  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = false;
  };

  services.chrony.enable = true;

  programs.htop.enable = true;
  programs.htop.settings = {
    hide_kernel_threads = false;
    hide_running_in_container = false;
    hide_userland_threads = true;
    show_program_path = false;
  };

  # services.wgvpn = {
  #   enable = true;
  #   networks.yep = {
  #     subnet = "10.38.0.0/24"; # choose something unlikely to conflict
  #     forwardPorts = [
  #       {
  #         destinationHost = "ballos";
  #         destinationPort = 80;
  #         sourceHost = "balrog";
  #         sourcePort = 80;
  #         proto = "tcp";
  #       }
  #       {
  #         destinationHost = "ballos";
  #         destinationPort = 443;
  #         sourceHost = "balrog";
  #         sourcePort = 443;
  #         proto = "tcp";
  #       }
  #     ];
  #     hosts = [
  #       {
  #         hostname = "balrog";
  #         ip = "10.100.0.1";
  #         pubkey = "z8vFtmrdwBEFTe49UykBbz9sQS8XvoDBGcsf/7dZ9R8=";
  #         endpoint = "gateway.turb.io";
  #         router = true;
  #       }
  #       {
  #         hostname = "gero";
  #         ip = "10.100.0.3";
  #         pubkey = "6QkyXbJ4orCVjGlw03Aa0R1GeUiEoalVdWCAxQH6Qkw=";
  #       }
  #       {
  #         hostname = "itoh";
  #         ip = "10.100.0.4";
  #         pubkey = "nl9gri7OsWGYWj+LbbtUBv8dKxFVOz4wlunm7dUhAgk=";
  #       }
  #       {
  #         hostname = "star";
  #         ip = "10.100.0.5";
  #         pubkey = "lfUVvROJvEyOHlzBxWsEpp7rWvY0Pt9J7cTKsPra92w=";
  #       }
  #       {
  #         hostname = "pando";
  #         ip = "10.100.0.6";
  #         pubkey = "Y9TKTr/fVYVxogi9vYYKo/xFjUk2Z5XFRuEdkSDN7yI=";
  #       }
  #       {
  #         hostname = "ios";
  #         pubkey = "8RPnvY0Vy641THmmnkGiz37oN65VGKplEZkOKuUqly8=";
  #         ip = "10.100.0.11";
  #       }
  #       {
  #         hostname = "ballos";
  #         ip = "10.100.0.10";
  #         pubkey = "7u9v3uGkvTY0fAZwz1ACMHSHyD+ocPXFrccDSuPPzUQ=";
  #         endpoint = "ballos.lan";
  #       }
  #     ];
  #   };
  # };

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "21.05"; # Did you read the comment?
}
