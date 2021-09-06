{ hostname, config, pkgs, ... }:
let
  packageset = pkgs.callPackage ./packages.nix { };
in
{
  imports = [
    ./desktop.nix
    (./hosts + "/${hostname}" + /hardware-configuration.nix)
    (./hosts + "/${hostname}" + /host.nix)
  ];

  nixpkgs.config.allowUnfree = true; # we live in a society

  nix.autoOptimiseStore = true;
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };

  nix = {
    package = pkgs.nixUnstable;
    extraOptions = ''
      experimental-features = nix-command flakes
    '';
  };

  networking.hostName = hostname;

  time.timeZone = "America/Los_Angeles";

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
      "dialout" # /dev/tty stuff
      "rfkill" # gotta poke some devices
      "input" # spooky haxxxx for push to talk
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

  home-manager.users.turbio = pkgs.callPackage ./home.nix { };

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "21.05"; # Did you read the comment?
}
