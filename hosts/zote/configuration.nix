{ pkgs, lib, ... }:
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

  # molters user + group (matching ballos UIDs)
  users.users.molters = {
    isNormalUser = true;
    uid = 1100;
    group = "molters";
    home = "/home/molters";
    shell = pkgs.zsh;
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIONmQgB3t8sb7r+LJ/HeaAY9Nz2aPS1XszXTub8A1y4n turbio"
    ];
  };
  users.groups.molters = {
    gid = 1100;
  };

  # NFS mount for molters home
  fileSystems."/home/molters" = {
    device = "ballos.lan:/tank/enc/molters";
    fsType = "nfs";
    options = [
      "rw"
      "noatime"
      "nfsvers=4"
      "x-systemd.automount"
      "x-systemd.idle-timeout=600"
      "_netdev"
    ];
  };

  # Lower unprivileged port start so nginx can bind port 80
  boot.kernel.sysctl."net.ipv4.ip_unprivileged_port_start" = 80;

  # signal-cli daemon
  systemd.services.signal-cli = {
    description = "signal-cli JSON-RPC daemon";
    after = [ "network-online.target" "home-molters.mount" ];
    wants = [ "network-online.target" "home-molters.mount" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      User = "molters";
      Group = "molters";
      ExecStart = "${pkgs.signal-cli}/bin/signal-cli --config /home/molters/.local/share/signal-cli daemon --http --receive-mode=manual localhost:8080";
      Restart = "always";
      RestartSec = 5;
    };
  };

  # nginx reverse proxy on port 80
  services.nginx = {
    enable = true;
    appendHttpConfig = ''
      map $http_upgrade $connection_upgrade {
        default upgrade;
        "" close;
      }
    '';
    virtualHosts."_" = {
      listen = [{ addr = "0.0.0.0"; port = 80; }];
      locations."/voice/" = {
        proxyPass = "http://127.0.0.1:3334";
        proxyWebsockets = true;
        extraConfig = ''
          proxy_set_header Host $host;
          proxy_set_header X-Real-IP $remote_addr;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          proxy_set_header X-Forwarded-Proto https;
          proxy_read_timeout 86400s;
          proxy_send_timeout 86400s;
        '';
      };
      locations."/" = {
        proxyPass = "http://127.0.0.1:18789";
        proxyWebsockets = true;
        extraConfig = ''
          proxy_set_header Host $host;
          proxy_set_header X-Real-IP $remote_addr;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          proxy_set_header X-Forwarded-Proto https;
          proxy_read_timeout 86400s;
          proxy_send_timeout 86400s;
        '';
      };
    };
  };

  # openclaw gateway (installed via npm in molters home)
  systemd.services.openclaw = {
    description = "OpenClaw Gateway";
    after = [ "network-online.target" "home-molters.mount" "signal-cli.service" "xvfb.service" ];
    wants = [ "network-online.target" "home-molters.mount" ];
    requires = [ "signal-cli.service" "xvfb.service" ];
    wantedBy = [ "multi-user.target" ];
    environment = {
      HOME = "/home/molters";
      DISPLAY = ":99";
      PATH = lib.mkForce "/home/molters/.npm-global/bin:/home/molters/.nix-profile/bin:${lib.makeBinPath (with pkgs; [ claude-code chromium nodejs coreutils ])}:/run/current-system/sw/bin";
    };
    serviceConfig = {
      User = "molters";
      Group = "molters";
      WorkingDirectory = "/home/molters";
      ExecStart = "/home/molters/.npm-global/bin/openclaw gateway";
      Restart = "always";
      RestartSec = 5;
    };
  };

  # Xvfb virtual display for non-headless browser
  systemd.services.xvfb = {
    description = "Xvfb virtual display";
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.xorg.xorgserver}/bin/Xvfb :99 -screen 0 1920x1080x24";
      Restart = "always";
    };
  };

  environment.systemPackages = with pkgs; [
    signal-cli
    claude-code
    chromium
    nodejs
    scrot
  ];
}
