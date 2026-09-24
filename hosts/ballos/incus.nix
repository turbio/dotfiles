{ config, pkgs, ... }:
let
  internalIp = (import ../../assignments.nix).vpn.internal;
  proxyCertDir = "/var/lib/incus-nginx-proxy";
in
{
  virtualisation.incus = {
    enable = true;
    ui.enable = true;
    preseed = {
      config."core.https_address" = ":8443";
      networks = [
        {
          name = "incusbr0";
          type = "bridge";
          config = {
            "ipv4.address" = "10.77.0.1/24";
            "ipv4.nat" = "true";
            "ipv6.address" = "none";
          };
        }
      ];
      storage_pools = [
        {
          name = "default";
          driver = "dir";
        }
      ];
      profiles = [
        {
          name = "default";
          devices = {
            eth0 = {
              name = "eth0";
              network = "incusbr0";
              type = "nic";
            };
            root = {
              path = "/";
              pool = "default";
              type = "disk";
            };
          };
        }
      ];
    };
  };

  users.users.turbio.extraGroups = [ "incus-admin" ];

  networking.firewall.trustedInterfaces = [ "incusbr0" ];

  networking.firewall.extraInputRules = ''
    ip saddr ${internalIp} tcp dport 8443 accept
  '';

  services.nginx.virtualHosts."incus.turb.io" = {
    forceSSL = true;
    useACMEHost = "turb.io";
    extraConfig = ''
      allow ${internalIp};
      allow 192.168.0.0/16;
      deny all;
    '';
    locations."/" = {
      proxyPass = "https://127.0.0.1:8443";
      proxyWebsockets = true;
      extraConfig = ''
        proxy_ssl_certificate ${proxyCertDir}/client.crt;
        proxy_ssl_certificate_key ${proxyCertDir}/client.key;
        proxy_buffering off;
        proxy_read_timeout 86400;
      '';
    };
  };

  systemd.services.incus-nginx-proxy-cert = {
    wantedBy = [
      "multi-user.target"
      "nginx.service"
    ];
    after = [ "incus.service" ];
    requires = [ "incus.service" ];
    before = [ "nginx.service" ];
    path = [
      pkgs.openssl
      config.virtualisation.incus.package
    ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      mkdir -p ${proxyCertDir}
      if [ ! -f ${proxyCertDir}/client.crt ]; then
        openssl req -x509 -newkey rsa:2048 -sha256 -days 3650 -nodes \
          -keyout ${proxyCertDir}/client.key -out ${proxyCertDir}/client.crt \
          -subj "/CN=nginx-incus-proxy"
        chown -R root:nginx ${proxyCertDir}
        chmod 750 ${proxyCertDir}
        chmod 640 ${proxyCertDir}/client.key
      fi
      if ! incus config trust list --format csv | grep -q nginx-incus-proxy; then
        incus config trust add-certificate ${proxyCertDir}/client.crt \
          --name nginx-incus-proxy
      fi
    '';
  };
}
