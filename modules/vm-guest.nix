# base profile for every vm guest. addressing, routes, ssh, and firewall all
# derive from the inventory entry passed in as `vm` (see modules/vm-host.nix).
# guests are untrusted: they get their /32+/128, the anycast gateway, and
# whatever their expose list opens — everything else is the host's nftables
# policy's problem.
{
  config,
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
        # in-kernel virtio processing instead of qemu userspace round trips:
        # better throughput and shaves per-packet latency
        tap.vhost = true;
      }
    ];

    # read-only host store via virtiofs; stateful guests additionally get
    # their tank dataset as /var — StateDirectory-style services persist
    # with zero per-service config, journal survives, and zfs snapshots/
    # sanoid apply to guest state like everything else on the pool
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
      # the var/ subdir, not the dataset root: the per-vm dataset also holds
      # other artifacts (full disk images, eventually)
      source = "${inventory.storage.vmsPath}/${vm.name}/var";
      mountPoint = "/var";
    }
    # inventory-declared dataset mounts (mounts."<guestPath>".dataset)
    ++ lib.mapAttrsToList (guestPath: m: {
      proto = "virtiofs";
      tag = "mnt${lib.replaceStrings [ "/" ] [ "-" ] guestPath}";
      source = inventory.storage.datasetPath m.dataset;
      mountPoint = guestPath;
    }) (vm.mounts or { })
    # host-delivered secrets (inventory `secrets` list): the hypervisor —
    # already a recipient of every age secret, and owner of this guest's
    # memory anyway — decrypts them onto tmpfs and shares them in read-only;
    # guests never hold keys and need no enrollment (modules/vm-host.nix)
    ++ lib.optional ((vm.secrets or [ ]) != [ ]) {
      proto = "virtiofs";
      tag = "host-secrets";
      source = "/run/vm-secrets/${vm.name}";
      mountPoint = "/run/host-secrets";
    };
  };

  # readOnly mounts: enforced guest-side (the share itself is rw at the
  # virtiofs layer; this is a seatbelt against accidental writes, not a
  # security boundary — the dataset's own perms are that)
  fileSystems = lib.mapAttrs' (guestPath: _: lib.nameValuePair guestPath { options = [ "ro" ]; }) (
    lib.filterAttrs (_: m: m.readOnly or false) (vm.mounts or { })
  );

  networking.useDHCP = false;
  networking.useNetworkd = true;
  # the internal resolver answers on the anycast gateway; recursion for vms
  # is deliberate — a gapped vm can still resolve names without egress
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

  # guest-side firewall mirrors the expose list (per protocol); defense in
  # depth behind the host's vmpolicy table
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
  # stateful guests keep their host keys on /var so rebuilds don't churn
  # known_hosts; stateless guests regenerate per boot (accepted)
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

  # kvm-clock tracks the (chrony-synced) host; guest ntp would just re-derive
  # host time over a network it isn't allowed to use. if drift ever shows up,
  # the fix is chrony + the ptp_kvm refclock, not network ntp
  services.timesyncd.enable = false;

  # guests are built by their host; no nix inside
  nix.enable = false;
  documentation.enable = false;

  system.stateVersion = "25.11";
}
