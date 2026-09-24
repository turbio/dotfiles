# base profile for every vm guest. addressing, routes, ssh, and firewall all
# derive from the inventory entry passed in as `vm` (see modules/vm-host.nix).
# guests are untrusted: they get their /32+/128, the anycast gateway, and
# whatever their expose list opens — everything else is the host's nftables
# policy's problem.
{
  lib,
  inventory,
  assignments,
  vm,
  ...
}:
{
  microvm = {
    hypervisor = "qemu";
    vcpu = lib.mkDefault (vm.vcpu or 1);
    mem = lib.mkDefault (vm.mem or 512);

    interfaces = [
      {
        type = "tap";
        id = "vm-${vm.name}";
        mac = vm.addr.mac;
        tap.vhost = true;
      }
    ];

    shares = [
      {
        proto = "virtiofs";
        tag = "ro-store";
        source = "/nix/store";
        mountPoint = "/nix/.ro-store";
      }
    ]
    ++ lib.optional (vm.persistVar or false) {
      proto = "virtiofs";
      tag = "state";
      source = "${inventory.storage.vmsPath}/${vm.name}/var";
      mountPoint = "/var";
    }
    ++ lib.mapAttrsToList (guestPath: m: {
      proto = "virtiofs";
      tag = "mnt${lib.replaceStrings [ "/" ] [ "-" ] guestPath}";
      source = inventory.storage.datasetPath m.dataset;
      mountPoint = guestPath;
    }) (vm.mounts or { })
    ++ lib.optional ((vm.secrets or [ ]) != [ ]) {
      proto = "virtiofs";
      tag = "host-secrets";
      source = "/run/vm-secrets/${vm.name}";
      mountPoint = "/run/host-secrets";
    };
  };

  fileSystems = lib.mapAttrs' (guestPath: _: lib.nameValuePair guestPath { options = [ "ro" ]; }) (
    lib.filterAttrs (_: m: m.readOnly or false) (vm.mounts or { })
  );

  networking.useDHCP = false;
  networking.useNetworkd = true;
  networking.nameservers = [ inventory.net.vm.gateway4 ];
  systemd.network.networks."10-lan" = {
    matchConfig.MACAddress = vm.addr.mac;
    address = [
      "${vm.addr.ip4}/32"
      "${vm.addr.ip6}/128"
    ];
    routes = [
      {
        Destination = "0.0.0.0/0";
        Gateway = inventory.net.vm.gateway4;
        GatewayOnLink = true;
      }
      {
        Destination = "::/0";
        Gateway = "fe80::1";
      }
    ];
  };

  networking.firewall.enable = true;
  networking.firewall.allowedTCPPorts = [
    22
  ]
  ++ map (e: e.port) (lib.filter (e: (e.proto or "tcp") == "tcp") (vm.expose or [ ]));
  networking.firewall.allowedUDPPorts = map (e: e.port) (
    lib.filter (e: (e.proto or "tcp") == "udp") (vm.expose or [ ])
  );

  services.openssh.enable = true;
  services.openssh.settings.PermitRootLogin = "prohibit-password";
  services.openssh.hostKeys = lib.mkIf (vm.persistVar or false) [
    {
      path = "/var/lib/ssh/ssh_host_ed25519_key";
      type = "ed25519";
    }
  ];
  systemd.tmpfiles.rules = lib.mkIf (vm.persistVar or false) [ "d /var/lib/ssh 0755 root root -" ];
  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPaSIYZYHcTVrctash3bTrayw2D4psofDHsbGZH3BxLP iphone"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIONmQgB3t8sb7r+LJ/HeaAY9Nz2aPS1XszXTub8A1y4n turbio@itoh"
  ]
  ++ lib.attrValues assignments.sshkeys;

  services.timesyncd.enable = false;

  nix.enable = false;
  documentation.enable = false;

  system.stateVersion = "25.11";
}
