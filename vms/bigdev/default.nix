{ lib, pkgs, ... }:
{
  microvm.balloon = true;

  # root is persistent so the overlay can just sit on it
  microvm.writableStoreOverlay = "/nix/.rw-store";

  services.fstrim.enable = true;

  nix.enable = lib.mkForce true;
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
    "pipe-operators"
  ];
  nix.settings.trusted-users = [ "turbio" ];

  nix.settings.substituters = [
    "https://nixcache.int.turb.io"
    "https://nix-community.cachix.org"
    "https://cache.nixos.org/"
  ];
  nix.settings.trusted-public-keys = [
    "nixcache.turb.io:FFCylJ0fphGs8IdYdpZBczLpUM9QRDzlN1oIUf2VxHI="
    "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
  ];

  environment.systemPackages = [ pkgs.git ];

  users.users.turbio = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKgLEls1igehuR4NNp4Yoh8k2kO+bO9rCoZDkLuE8qiB turbio@bigdev"
    ];
  };
  security.sudo.wheelNeedsPassword = false;
}
