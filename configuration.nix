{
  hostname,
  localpkgs,
  pkgs,
  lib,
  ...
}:
let
  packageset = pkgs.callPackage ./packages.nix { inherit localpkgs; };
in
{
  documentation.man.generateCaches = false; # building the cache takes forver and I don't use it

  services.fwupd.enable = true;

  nixpkgs.overlays = [
    (final: prev: {
    })
  ];

  networking.hosts = {
    # TODO: ewww VPN FIXE THIS
    "100.100.57.46" = [
      "int.turb.io"
      "bt.int.turb.io"
      "jelly.int.turb.io"
      "ollama.int.turb.io"
      "sync.int.turb.io"
      "home.int.turb.io"
    ];
  };

  nix = {
    #autoOptimiseStore = true;

    gc = lib.mkIf (hostname != "ballos") {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 30d";
    };

    settings = {
      trusted-users = [ "turbio" ];

      # todo(turbio): lol
      substituters =
        if (hostname != "ballos" && hostname != "zote") then
          [
            "https://nixcache.turb.io"
          ]
        else
          [ ];
      trusted-public-keys = [
        "nixcache.turb.io:FFCylJ0fphGs8IdYdpZBczLpUM9QRDzlN1oIUf2VxHI=" # TODO(turbio): key management
      ];
    };

    #package = pkgs.nixVersions.latest;
    extraOptions = ''
      experimental-features = nix-command flakes pipe-operators auto-allocate-uids no-url-literals
      builders-use-substitutes = true
    '';
  };

  nixpkgs.config.allowUnfree = true; # welp

  networking.hostName = hostname;

  environment.systemPackages = packageset.core;

  users.mutableUsers = false;
  security.sudo.wheelNeedsPassword = false;
  users.users.turbio = {
    home = "/home/turbio";
    isNormalUser = true;
    extraGroups = [
      "wheel"
      "networkmanager"
      "audio"
      "video"
      "wireshark"
      "dialout" # /dev/tty stuff
      "rfkill" # gotta poke some devices
      "input" # spooky haxxxx for push to talk
      "media"

      # raspi stuff
      "gpio"
      "i2c"
    ];
    uid = 1000;

    # probably a bad idea lmao
    hashedPassword = "$6$UnnB5IybU$cBw9zHoM7xTdwyXnAAbeXOGoqQQtzbYsuPqTDjpGF3J3H3WaarzAEtoBxXOImZlmmzY2amSqSgwUbEP0.ma3w0"; # TODO(turbio): key management

    shell = pkgs.zsh;
    #shell = pkgs.fish;
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIONmQgB3t8sb7r+LJ/HeaAY9Nz2aPS1XszXTub8A1y4n turbio" # TODO(turbio): key management
    ];
  };

  programs.ssh.extraConfig = ''
    ControlMaster auto
    Host *
      StrictHostKeyChecking accept-new
  '';

  programs.fish.enable = true;
  programs.zsh.enable = true;

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
    column_meters_0 = [
      "LeftCPUs2"
      "Memory"
      "Swap"
      "DiskIO"
      "NetworkIO"
    ];
    column_meter_modes_0 = [
      1
      1
      1
      2
      2
    ];
    column_meters_1 = [
      "RightCPUs2"
      "Tasks"
      "LoadAverage"
      "Uptime"
    ];
    column_meter_modes_1 = [
      1
      2
      2
      2
    ];
  };

  /*
    services.wgvpn = {
      enable = true;
      networks.yep = {
        subnet = "10.38.0.0/24"; # choose something unlikely to conflict
        generatePrivateKeyFile = true;
        privateKeyFile = "/tmp/TODO";
        listenPort = 51820;
        mtu = 1420;

        forwardPorts = [
          {
            destinationHost = "ballos";
            destinationPort = 80;
            sourceHost = "balrog";
            sourcePort = 80;
            proto = "tcp";
          }
          {
            destinationHost = "ballos";
            destinationPort = 443;
            sourceHost = "balrog";
            sourcePort = 443;
            proto = "tcp";
          }
        ];

        hosts = [
          {
            hostname = "balrog";
            ip = "10.100.0.1";
            pubkey = "z8vFtmrdwBEFTe49UykBbz9sQS8XvoDBGcsf/7dZ9R8=";
            endpoint = "gateway.turb.io";
            router = true;
          }
          {
            hostname = "gero";
            ip = "10.100.0.3";
            pubkey = "6QkyXbJ4orCVjGlw03Aa0R1GeUiEoalVdWCAxQH6Qkw=";
          }
          {
            hostname = "itoh";
            ip = "10.100.0.4";
            pubkey = "nl9gri7OsWGYWj+LbbtUBv8dKxFVOz4wlunm7dUhAgk=";
          }
          {
            hostname = "star";
            ip = "10.100.0.5";
            pubkey = "lfUVvROJvEyOHlzBxWsEpp7rWvY0Pt9J7cTKsPra92w=";
          }
          {
            hostname = "pando";
            ip = "10.100.0.6";
            pubkey = "Y9TKTr/fVYVxogi9vYYKo/xFjUk2Z5XFRuEdkSDN7yI=";
          }
          {
            hostname = "ios";
            pubkey = "8RPnvY0Vy641THmmnkGiz37oN65VGKplEZkOKuUqly8=";
            ip = "10.100.0.11";
          }
          {
            hostname = "ballos";
            ip = "10.100.0.10";
            pubkey = "7u9v3uGkvTY0fAZwz1ACMHSHyD+ocPXFrccDSuPPzUQ=";
            endpoint = "ballos.lan";
          }
        ];
      };
    };
  */

  # TODO(turbio):
  services.tailscale.enable = lib.mkIf (hostname != "zote") true;
  services.tailscale.useRoutingFeatures = "both";
  networking.nameservers = [
    "100.100.100.100"
    "8.8.8.8"
    "1.1.1.1"
  ];
  networking.nftables = {
    enable = true;
  };

  networking.useNetworkd = true;
  services.resolved.enable = true;

  boot.supportedFilesystems = [ "nfs" ];

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "21.05"; # Did you read the comment?
}
