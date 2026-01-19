{
  imports = [
    ../../modules/acme-dns.nix
    ../../modules/bind.nix
    ../../modules/edge-router.nix
  ];

  services.prometheus.exporters.node = {
    enable = true;
    enabledCollectors = [ "systemd" ];
    listenAddress = "0.0.0.0";
    port = 9100;
  };
  # Only allow node_exporter access from Tailscale network
  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ 9100 ];
}
