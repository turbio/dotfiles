{ ... }:
{
  networking.firewall.enable = false;

  boot.binfmt.emulatedSystems = [ "aarch64-linux" ];

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
