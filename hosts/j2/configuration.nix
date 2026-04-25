{ pkgs, lib, ... }:
{
  imports = [
    ../../modules/nix-remote-builder.nix
  ];

  networking.firewall.enable = false;

  networking.hosts = {
    # TODO: ewww VPN FIXE THIS
    "192.168.86.114" = [
      "nixcache.turb.io"
      "int.turb.io"
      "bt.int.turb.io"
      "jelly.int.turb.io"
      "ollama.int.turb.io"
      "sync.int.turb.io"
      "home.int.turb.io"
    ];
  };

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
