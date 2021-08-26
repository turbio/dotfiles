#lib.fakeSha256;

{ config, pkgs, lib, ... }:
let
  hostname = import ./hostname.nix;
  stdenv = pkgs.stdenv;
  desktopPackages = with pkgs; [
    nixpkgs-fmt
    firefox-wayland
    chromium
    alacritty
    pavucontrol
    discord
    blueberry
    spotify
    mako
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
  ];
  homemanager = builtins.fetchTarball {
    url = "https://github.com/nix-community/home-manager/archive/release-21.05.tar.gz";
    sha256 = "0xw1vgwfdn75rgamcsi5j1iqfl0j06x8xp92k24wr9hayfr5m400";
  };
  wallpaperbin = stdenv.mkDerivation {
    name = "wallpaper";
    src = pkgs.fetchFromGitHub {
      owner = "turbio";
      repo = "live_wallpaper";
      rev = "nixfix";
      sha256 = "01m3gbzgb5vvipmcp0l3z7hg827yds4sz6vhqs5s262wkcr48qy3";
    };
    buildInputs = with pkgs; [ SDL2 SDL2_gfx pkg-config clang xxd ];
    buildPhase = "cd build && make";
    installPhase = ''
      mkdir -p $out/bin
      cp walp $out/bin
      cp -r mods $out
    '';
  };
  wallpaper = stdenv.mkDerivation {
    name = "wallpaper-render";
    phases = [ "buildPhase" "installPhase" ];

    buildPhase = ''
      ${wallpaperbin}/bin/walp \
        -p ${wallpaperbin}/mods/cave_story_island.so \
        --width 2560 \
        --height 1440 \
        --bmp out.bmp \
        --once
    '';

    installPhase = ''
      cp out.bmp $out
    '';
  };
in
{
  imports = [
    ./common.nix
    (./hosts + "/${hostname}" + /hardware-configuration.nix)
    (./hosts + "/${hostname}" + /host.nix)
    (import "${homemanager}/nixos")
  ];

  nix = {
    package = pkgs.nixUnstable;
    #extraOptions = ''
    #  experimental-features = nix-command flakes
    #'';
  };

  nixpkgs.config.allowUnfree = true; # we live in a society

  networking.hostName = hostname;

  time.timeZone = "America/Los_Angeles";

  i18n.defaultLocale = "en_US.UTF-8";

  environment.systemPackages = with pkgs; [
    wget
    git
    htop
    busybox
    zsh
    ag

    gnumake
    clang
    gcc
    go
    nodejs
    gdb

    jq

    cloc
    cargo
    rustc
    rustup
  ] ++ (if config.isDesktop then desktopPackages else [ ]);

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
      "dialout" # /dev/tty stuff
    ];
    uid = 1000;

    # probably a bad idea lmao
    hashedPassword = "$6$UnnB5IybU$cBw9zHoM7xTdwyXnAAbeXOGoqQQtzbYsuPqTDjpGF3J3H3WaarzAEtoBxXOImZlmmzY2amSqSgwUbEP0.ma3w0";

    shell = pkgs.zsh;
    openssh.authorizedKeys.keys = [ "sk-ecdsa-sha2-nistp256@openssh.com AAAAInNrLWVjZHNhLXNoYTItbmlzdHAyNTZAb3BlbnNzaC5jb20AAAAIbmlzdHAyNTYAAABBBBa1RGmSWCA4xvw+sBZglCwjMbJ7QtYszwR3agccvse+VMq+tCOcPFUCNi5Wt36IJa9dBNbRHihE1KbaX5pGptwAAAAEc3NoOg== turbio@turb.io" ];
  };

  programs.mtr.enable = true;

  programs.gnupg.agent = {
    enable = true;
    enableSSHSupport = true;
  };

  services.openssh = {
    enable = true;
    passwordAuthentication = false;
  };

  services.ntp.enable = true;

  home-manager.users.turbio = { pkgs, ... }: {
    home.packages = with pkgs; [

      swaylock
      swayidle
      wl-clipboard
      mako # notification daemon
      alacritty # Alacritty is the default terminal in the config
      dmenu # Dmenu is the default in the config but i recommend wofi since its wayland native
    ];

    xdg.configFile = lib.mkMerge [
      {
        "tmux/tmux.conf".source = ./config/tmux/tmux.conf;


        "nvim/tmp/undo/.keep".text = "";
        "nvim/tmp/backup/.keep".text = "";
        "nvim/tmp/swap/.keep".text = "";
      }
      (lib.mkIf config.isDesktop {
        "bspwm/bspwmrc".source = ./config/bspwm/bspwmrc;
        "sxhkd/sxhkdrc".source = ./config/sxhkd/sxhkdrc;

        "alacritty/alacritty.yml".source = ./config/alacritty/alacritty.yml;
        "dunstrc".source = ./config/dunstrc;
        "mako/config".source = ./config/mako/config;
        "sway/config".text = (
          builtins.replaceStrings
            [ "NIX_REPLACE_WALLPAPER" ]
            [ (builtins.toString wallpaper) ]
            (builtins.readFile ./config/sway/config)
        );
        "waybar/config".text =
          builtins.replaceStrings
            [ "NIX_WAYBAR_YUBI_EXEC" "NIX_WAYBAR_YUBI_ONCLICK" ]
            [
              (builtins.toString (pkgs.writeShellScript "yubi-waybar-status"
                ''
                  last=xxxxxx
                  ${pkgs.systemd}/bin/udevadm monitor \
                    --udev \
                    --subsystem-match=usb \
                    --tag-match=security-device \
                    | while read l; do
                      if [[ "$l" == *"add"* ]]; then
                        ykout="$(${pkgs.yubikey-manager}/bin/ykman list)";
                        if [[ "$ykout" != "" ]]; then
                          last="$(echo $l | awk '{print $4}')";
                          text=$(echo -n "$ykout" | sed 's/^\(.\+\) (.* \([0-9]\+\)$/\1 \2/')
                          echo '{"text": "'"$text"'", "alt": "key"}';
                        fi
                      elif [[ "$l" == *"remove"* ]] && [[ "$l" == *"$last"* ]]; then
                        echo;
                      fi
                    done
                ''
              ))

              (builtins.toString (pkgs.writeShellScript "yubi-waybar-click"
                ''
                  ${pkgs.alacritty}/bin/alacritty \
                    --title 'Yubikey Oath Codes' \
                    --command sh -c " \
                      echo Yubikey Oath Codes; \
                      printf %80s |tr ' ' '-'; \
                      echo -en 'Loading codoes...\r'; \
                      ${pkgs.yubikey-manager}/bin/ykman oath accounts code; \
                      read";
                ''
              ))
            ]
            (builtins.readFile ./config/waybar/config)
        ;
        "waybar/mediaplayer.py".source = ./config/waybar/mediaplayer.py;
        "waybar/style.css".source = ./config/waybar/style.css;
      })
    ];

    programs.zsh = {
      enable = true;
      enableAutosuggestions = true;
      plugins = [
        {
          name = "zsh-syntax-highlighting";
          src = pkgs.fetchFromGitHub {
            owner = "zsh-users";
            repo = "zsh-syntax-highlighting";
            rev = "dffe304";
            sha256 = "0dwgcfbi5390idvldnf54a2jg2r1dagc1rk7b9v3lqdawgm9qvnw";
          };
        }
        {
          name = "zsh-history-substring-search";
          src = pkgs.fetchFromGitHub {
            owner = "zsh-users";
            repo = "zsh-history-substring-search";
            rev = "master";
            sha256 = "0y8va5kc2ram38hbk2cibkk64ffrabfv1sh4xm7pjspsba9n5p1y";
          };
        }
      ];
      initExtra = (builtins.readFile ./config/zsh/zshrc);
    };

    home.sessionVariables = {
      EDITOR = "vim";
      MOZ_ENABLE_WAYLAND = "1";
      XDG_CURRENT_DESKTOP = "sway";
      CLUTTER_BACKEND = "wayland";
      _JAVA_AWT_WM_NONREPARENTING = "1";
    };

    imports = [ ./vim.nix ];

    programs.nix-index.enable = true;

    programs.git = {
      enable = true;
      userEmail = "git@turb.io";
      userName = "turbio";
      extraConfig = {
        pull = { ff = "only"; };
      };
    };

    programs.firefox = {
      enable = true;
      profiles."lbgu1zmc.default".userChrome = ''
        /* Hide tab bar in FF Quantum */
        #TabsToolbar {
          visibility: collapse !important;
          margin-bottom: 21px !important;
        }

        #sidebar-box[sidebarcommand="treestyletab_piro_sakura_ne_jp-sidebar-action"] #sidebar-header {
          visibility: collapse !important;
        }
      '';
    };

    gtk = lib.mkIf config.isDesktop {
      enable = true;
      font.package = pkgs.terminus_font;
      font.name = "Terminus";
      font.size = 9;

      theme.package = pkgs.arc-theme;
      theme.name = "Arc-Dark";
    };

    home.sessionPath = [
      "${./bin}"
    ];
  };

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "21.05"; # Did you read the comment?
}
