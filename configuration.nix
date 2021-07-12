#lib.fakeSha256;

{ config, pkgs, lib, ... }:
let
  hostname = import ./hostname.nix;
in
{
  imports = [
    (./hosts + "/${hostname}" + /hardware-configuration.nix)
    <home-manager/nixos>
  ];

  nixpkgs.config.allowUnfree = true; # we live in a society

  nixpkgs.config.pulseaudio = true;
  hardware.pulseaudio.enable = true;


  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = hostname;

  time.timeZone = "America/Los_Angeles";

  networking.interfaces.enp0s31f6.useDHCP = true;
  networking.interfaces.wlp0s20f3.useDHCP = true;

  networking.networkmanager.enable = true;

  i18n.defaultLocale = "en_US.UTF-8";

  environment.systemPackages = with pkgs; [
    nixpkgs-fmt
    wget
    firefox-wayland
    chromium
    alacritty
    git
    htop
    busybox
    zsh
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
    gnumake
    clang
    gcc
    go

    lxappearance
    gtk_engines
    gtk-engine-murrine
    gsettings-desktop-schemas

    lsb-release

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

    cloc
    nodejs

    cargo
    rustc
    rustup
    wasm-pack

    qemu
  ];

  xdg = {
    portal = {
      enable = true;
      extraPortals = with pkgs; [
        xdg-desktop-portal-wlr
      ];
      gtkUsePortal = true;
    };
  };

  programs.light.enable = true;

  virtualisation.virtualbox.host.enable = true;
  #virtualisation.virtualbox.host.enableExtensionPack = true;
  users.extraGroups.vboxusers.members = [ "turbio" ];

  services.yubikey-agent.enable = true;
  services.pcscd.enable = true;

  fonts.fonts = with pkgs; [
    terminus_font
    terminus_font_ttf
    font-awesome
    noto-fonts
    noto-fonts-emoji
  ];

  programs.sway = {
    enable = true;
    wrapperFeatures.gtk = true;
  };

  services.pipewire.enable = true;

  users.users.turbio = {
    home = "/home/turbio";
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" "docker" "audio" ];
    uid = 1000;
    hashedPassword = "$6$UnnB5IybU$cBw9zHoM7xTdwyXnAAbeXOGoqQQtzbYsuPqTDjpGF3J3H3WaarzAEtoBxXOImZlmmzY2amSqSgwUbEP0.ma3w0";
    shell = pkgs.zsh;
  };
  users.mutableUsers = false;

  programs.mtr.enable = true;

  programs.gnupg.agent = {
    enable = true;
    enableSSHSupport = true;
    pinentryFlavor = "gnome3";
  };

  services.openssh.enable = true;

  home-manager.users.turbio = { pkgs, ... }: {
    home.packages = [ pkgs.atool pkgs.httpie ];
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
  };

  security.sudo.wheelNeedsPassword = false;

  virtualisation.docker.enable = true;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "21.05"; # Did you read the comment?
}
