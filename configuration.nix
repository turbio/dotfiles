#lib.fakeSha256;

{ config, pkgs, lib, ... }:
let
  hostname = import ./hostname.nix;
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
    arc-theme
    lxappearance
    gtk_engines
    gtk-engine-murrine
    gsettings-desktop-schemas
    lsb-release

    # wayland
    wdisplays

    # waybar stuff
    waybar
    playerctl
    python38
    python38Packages.pygobject3
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
  ];
  homemanager = builtins.fetchTarball {
    url = "https://github.com/nix-community/home-manager/archive/release-21.05.tar.gz";
  };
in
{
  imports = [
    ./common.nix
    (./hosts + "/${hostname}" + /hardware-configuration.nix)
    (./hosts + "/${hostname}" + /host.nix)
    (import "${homemanager}/nixos")
  ];

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
    extraGroups = [ "wheel" "networkmanager" "docker" "audio" ];
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
    home.packages = [ ];
    xdg.configFile = {
      "alacritty/alacritty.yml".source = ./config/alacritty/alacritty.yml;
      "dunstrc".source = ./config/dunstrc;
      "mako/config".source = ./config/mako/config;
      "sway/config".source = ./config/sway/config;
      "tmux/tmux.conf".source = ./config/tmux/tmux.conf;
      "bspwm/bspwmrc".source = ./config/bspwm/bspwmrc;
      "sxhkd/sxhkdrc".source = ./config/sxhkd/sxhkdrc;

      "waybar/config".source = ./config/waybar/config;
      "waybar/mediaplayer.py".source = ./config/waybar/mediaplayer.py;
      "waybar/style.css".source = ./config/waybar/style.css;

      "nvim/tmp/undo/.keep".text = "";
      "nvim/tmp/backup/.keep".text = "";
      "nvim/tmp/swap/.keep".text = "";
    };

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
    };

    imports = [ ./vim.nix ];

    programs.nix-index.enable = true;

    programs.git = {
      enable = true;
      userEmail = "git@turb.io";
      userName = "turbio";
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
  };

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "21.05"; # Did you read the comment?
}
