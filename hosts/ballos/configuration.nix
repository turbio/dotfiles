{ pkgs, ... }:
{
  users.users.turbio = {
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPaSIYZYHcTVrctash3bTrayw2D4psofDHsbGZH3BxLP iphone" # TODO(turbio): key management
    ];
  };

  vmhost.enable = true;
  intDns.enable = true;

  services.tailscale.extraSetFlags = [ "--accept-dns=false" ];

  environment.enableAllTerminfo = true;

  networking.nat = {
    enable = true;
    internalInterfaces = [
      "ve-*"

      # tailscale0 needs masquerade for peers using ballos as an exit node
      "tailscale0"
    ];
    externalInterface = "bond0";
    enableIPv6 = true;
  };

  networking.wireguard.enable = true;
  networking.wireguard.interfaces = { };

  nix.settings.system-features = [
    "gccarch-armv7-a"
  ];
  boot.binfmt.emulatedSystems = [
    "aarch64-linux"
    "armv7l-linux"
    "i686-linux"
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.firewall.enable = true;

  networking.nftables = {
    enable = true;
    ruleset = "";
  };

  networking.firewall.allowedUDPPorts = [
    111
    2049
    10809
    5201
  ];
  networking.firewall.allowedTCPPorts = [
    111
    2049
    10809
    5201
  ];

  # services.syncthing = {
  #   enable = true;
  #
  #   configDir = "/tank/enc/misc/config";
  #   dataDir = "/tank/enc/misc";
  #   settings.folders = {
  #     "photos" = {
  #       enable = true;
  #       path = "/tank/enc/photos";
  #     };
  #     "code" = {
  #       enable = true;
  #       path = "/tank/enc/code";
  #     };
  #     "notes" = {
  #       enable = true;
  #       path = "/tank/enc/misc/notes";
  #     };
  #     "ios_photos" = {
  #       enable = true;
  #       path = "/tank/enc/misc/ios_photos";
  #     };
  #     "clips" = {
  #       enable = true;
  #       path = "/tank/enc/misc/clips";
  #     };
  #     "webcamlog" = {
  #       enable = true;
  #       path = config.zfs.pools.tank.datasets."enc/webcamlog".mountpoint;
  #     };
  #   };
  # };

  nixpkgs.overlays = [
    (
      final:
      {
        lib,
        buildGoModule,
        fetchFromGitHub,
        nixosTests,
        ...
      }:
      {
        prometheus-idrac-exporter = buildGoModule rec {
          pname = "idrac_exporter";
          version = "unstable-2023-06-29";

          src = fetchFromGitHub {
            owner = "mrlhansen";
            repo = "idrac_exporter";
            rev = "3b311e0e6d602fb0938267287f425f341fbf11da";
            sha256 = "sha256-N8wSjQE25TCXg/+JTsvQk3fjTBgfXTiSGHwZWFDmFKc=";
          };

          vendorHash = "sha256-iNV4VrdQONq7LXwAc6AaUROHy8TmmloUAL8EmuPtF/o=";

          patches = [ ./idrac-exporter/config-from-environment.patch ];

          ldflags = [
            "-s"
            "-w"
          ];

          doCheck = true;

          passthru.tests = { inherit (nixosTests.prometheus-exporters) idrac; };

          meta = with lib; {
            inherit (src.meta) homepage;
            description = "Simple iDRAC exporter for Prometheus";
            mainProgram = "idrac_exporter";
            license = licenses.mit;
            maintainers = with maintainers; [ codec ];
          };
        };
      }
    )

    /*
      (
        final:
        { buildGoModule, fetchFromGitHub, ... }:
        {
          prometheus-comed-exporter = buildGoModule {
            pname = "comed_exporter";
            version = "1.0";
            src = fetchFromGitHub {
              owner = "kklipsch";
              repo = "comed_exporter";
              rev = "1a90f09ceb0ebdfe09c2b307b4080d81b7d8de5f";
              hash = "sha256-oDvOp7SGz7RTWW3b74I1V3WhiNsHvO3hv01Gr4UkyiY=";
            };

            vendorHash = null;

            doCheck = false;
          };
        }
      )
    */
  ];

  systemd.services.fanspeed = {
    enable = true;
    wantedBy = [ "multi-user.target" ];
    path = [
      pkgs.ipmitool
      pkgs.bc
      pkgs.bash
      pkgs.lm_sensors
      pkgs.gawk
    ];
    serviceConfig = {
      User = "root";
      ExecStart = "${pkgs.bash}/bin/bash ${./fan_speed.sh} --disengage-temp 80 --target-temp 60 --verbose-log";
    };
  };

}
