{ pkgs, lib, ... }:
{
  imports = [
    ../../modules/nix-remote-builder.nix
  ];

  networking.firewall.enable = false;

  nix.settings.system-features = [
    "gccarch-armv7-a"
  ];
  boot.binfmt.emulatedSystems = [
    "aarch64-linux"
    "armv7l-linux"
    "i686-linux"
  ];

  services.prometheus.exporters.node = {
    enable = true;
    enabledCollectors = [ "systemd" ];
    listenAddress = "0.0.0.0";
    port = 9100;
  };

  nix.settings = {
    build-dir = "/scratch/nix-build"; # TODO
  };
}
