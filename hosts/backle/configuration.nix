{
  imports = [
    ../../modules/acme-dns.nix
    ../../modules/bind.nix
    ../../modules/edge-router.nix
  ];

  nix.settings.system-features = [ "gccarch-armv7-a" ];
  nix.settings.extra-platforms = [ "armv7l-linux" ];

  services.prometheus.exporters.node = {
    enable = true;
    enabledCollectors = [ "systemd" ];
    listenAddress = "0.0.0.0";
    port = 9100;
  };
  # Only allow node_exporter access from Tailscale network
  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ 9100 ];
}
