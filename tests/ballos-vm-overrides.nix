# VM-boot overrides for ballos. Layered on top of the full ballos module list
# so the test exercises the real configuration as closely as possible. Only
# the things that physically cannot work in a VM are patched here:
#
#   - hardware-configuration's real disks/ZFS-root are replaced with qemu
#     virtio disks; an extra empty disk is attached and used to host a fresh
#     `tank` zpool created on first boot (downstream services see the same
#     pool layout as on bare metal).
#   - age secrets are stubbed with plaintext (the VM has no host key that
#     `secrets.nix` knows about).
#   - ACME-issued certs are replaced with self-signed material so nginx
#     vhosts marked `useACMEHost = "..."` can actually load a cert.
#
# Things we intentionally *don't* patch (let them fail if they must):
#   - tailscale (not load-bearing for the forgejo/buildbot test)
#   - IPMI kernel modules (hardware-only; service fails harmlessly)
#   - netboot host service (external, doesn't block the critical path)
{
  config,
  lib,
  pkgs,
  modulesPath,
  ...
}:
let
  # All domains used by ballos vhosts so we can generate a self-signed cert
  # once per domain and point `security.acme.certs.<domain>` at it.
  acmeDomains = [
    "turb.io"
    "turbi.ooo"
    "masonclayton.com"
    "nice.meme"
    "molters.xyz"
  ];

  selfSignedCert =
    domain:
    pkgs.runCommand "self-signed-${domain}"
      {
        nativeBuildInputs = [ pkgs.openssl ];
      }
      ''
        mkdir -p $out
        openssl req -x509 -nodes -newkey rsa:2048 \
          -keyout $out/key.pem -out $out/cert.pem \
          -days 3650 -subj "/CN=${domain}" \
          -addext "subjectAltName = DNS:${domain},DNS:*.${domain}" \
          2>/dev/null
        cp $out/cert.pem $out/fullchain.pem
        cat $out/cert.pem $out/key.pem > $out/full.pem
      '';
in
{
  imports = [
    "${modulesPath}/virtualisation/qemu-vm.nix"
  ];

  # ---------------------------------------------------------------
  # Virtualisation
  # ---------------------------------------------------------------
  virtualisation = {
    memorySize = 4096;
    cores = 4;
    diskSize = 16384;
    graphics = false;
    # One extra blank disk that becomes /dev/vdb and backs the `tank`
    # zpool. Size in MiB.
    emptyDiskImages = [ 4096 ];
  };

  # Disable wrappers that expect host hardware.
  hardware.enableAllFirmware = lib.mkForce false;
  hardware.enableRedistributableFirmware = lib.mkForce false;

  # The real hardware-configuration targets a SAS controller + ZFS root.
  # qemu-vm.nix sets up its own root on /dev/vda, but its contributions to
  # fileSystems/kernelModules need to coexist with the prod ones without
  # anyone getting mkForce-clobbered. Append the virtio modules and drop the
  # hardware-only ones.
  boot.initrd.kernelModules = lib.mkForce [ ]; # drop mpt3sas, kvm-intel
  boot.initrd.availableKernelModules = [
    "virtio_pci"
    "virtio_blk"
    "virtio_scsi"
    "virtio_net"
    "sr_mod"
  ];
  boot.supportedFilesystems.ext4 = true;
  boot.supportedFilesystems.vfat = true;
  swapDevices = lib.mkForce [ ];

  # ---------------------------------------------------------------
  # ZFS: create/import a `tank` pool on the attached empty disk
  # ---------------------------------------------------------------
  boot.zfs.extraPools = lib.mkForce [ ];
  boot.zfs.forceImportAll = lib.mkForce false;
  boot.zfs.forceImportRoot = lib.mkForce false;
  networking.hostId = lib.mkForce "deadbeef";

  # systemd.services is built as a single mkMerge so both our
  # zfs-import-tank override and the acme-<domain> disables coexist.

  # ---------------------------------------------------------------
  # Age secrets: the VM has no host key matching secrets.nix recipients, so
  # decryption would fail. Replace agenix's activation with one that just
  # drops plaintext stubs at /run/agenix/<name> — config.age.secrets.X.path
  # still points there, so downstream modules consume them transparently.
  # ---------------------------------------------------------------
  system.activationScripts.agenixInstall.text =
    let
      stage = name: content: ''
        ${pkgs.coreutils}/bin/install -m 0400 -o 0 -g 0 \
          ${pkgs.writeText "stub-${name}" content} \
          /run/agenix/${name}
      '';
    in
    lib.mkForce ''
      ${pkgs.coreutils}/bin/mkdir -p /run/agenix
      ${pkgs.coreutils}/bin/chmod 0751 /run/agenix
      ${stage "forgejo-oauth-secret" "test-oauth-secret"}
      ${stage "forgejo-webhook-secret" "test-webhook-secret"}
      ${stage "userpassword" "testpassword"}
      ${stage "rfc2136-acme" ''
        key "stub" { algorithm hmac-sha256; secret "c3R1Yg=="; };
      ''}
    '';
  system.activationScripts.agenixChown.text = lib.mkForce "";
  system.activationScripts.agenixNewGeneration.text = lib.mkForce "";
  system.activationScripts.agenixRemoveOldGenerations.text = lib.mkForce "";

  # ---------------------------------------------------------------
  # ACME: don't try to talk to Let's Encrypt. Stage a self-signed cert in
  # /var/lib/acme/<domain>/ for every vhost that references useACMEHost.
  # ---------------------------------------------------------------
  security.acme.acceptTerms = lib.mkForce true;
  security.acme.defaults.email = lib.mkForce "test@localhost";
  # Disable the acme-<domain>.service renewal units + install the
  # zfs-import-tank replacement.
  systemd.services = lib.mkMerge (
    [
      {
        "zfs-import-tank" = {
          description = "Create/import ZFS pool 'tank' (VM boot)";
          wantedBy = [ "zfs-import.target" ];
          before = [
            "zfs-import.target"
            "zfs-mount.service"
          ];
          path = [
            config.boot.zfs.package
            pkgs.coreutils
            pkgs.util-linux
          ];
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
            DefaultDependencies = "no";
          };
          unitConfig = {
            DefaultDependencies = "no";
          };
          script = ''
            set -eu
            if ! zpool list tank >/dev/null 2>&1; then
              if ! zpool import -f tank 2>/dev/null; then
                zpool create -f -o ashift=12 -O mountpoint=none tank /dev/vdb
              fi
            fi
            # Ballos's services all declare leaf datasets like `enc/forgejo`
            # under a shared `tank/enc` parent that exists outside the nix
            # config on real hardware. Create it here so the per-dataset
            # zfs-ensure services can `zfs create tank/enc/<child>`.
            if ! zfs list -H -o name tank/enc >/dev/null 2>&1; then
              zfs create -o mountpoint=none tank/enc
            fi
          '';
        };
      }
    ]
    ++ map (domain: {
      "acme-${domain}" = lib.mkForce {
        enable = false;
        wantedBy = lib.mkForce [ ];
      };
    }) acmeDomains
  );
  systemd.tmpfiles.rules = lib.concatMap (domain: [
    "d /var/lib/acme/${domain} 0755 acme acme -"
    "C+ /var/lib/acme/${domain}/cert.pem      0644 acme acme - ${selfSignedCert domain}/cert.pem"
    "C+ /var/lib/acme/${domain}/key.pem       0644 acme acme - ${selfSignedCert domain}/key.pem"
    "C+ /var/lib/acme/${domain}/fullchain.pem 0644 acme acme - ${selfSignedCert domain}/fullchain.pem"
    # chain.pem is the intermediate-only bundle; a self-signed cert has no
    # intermediate, so it's the same file.
    "C+ /var/lib/acme/${domain}/chain.pem     0644 acme acme - ${selfSignedCert domain}/cert.pem"
    "C+ /var/lib/acme/${domain}/full.pem      0644 acme acme - ${selfSignedCert domain}/full.pem"
  ]) acmeDomains
  # The acme user exists by activation time; reset ownership on the stub
  # rfc2136 secret so downstream services don't fail with EPERM.
  ++ [
    "z /run/agenix/rfc2136-acme 0400 acme acme -"
  ];

  # ---------------------------------------------------------------
  # Networking / hostname stubs
  # ---------------------------------------------------------------
  networking.firewall.enable = lib.mkForce false;
  # Tailscale is not critical; let it fail if it can't reach the control
  # plane — the test doesn't depend on it.
  services.tailscale.authKeyFile = lib.mkForce null;

  # Map the domain names the test talks to back at this VM.
  networking.extraHosts = ''
    127.0.0.1 forge.turb.io
    127.0.0.1 buildbot.turb.io
    127.0.0.1 git.turb.io
    127.0.0.1 cl.turb.io
  '';

  # The prod config binds nginx to specific tailscale/LAN IPs which don't
  # exist in the VM. Listen on loopback + wildcard instead.
  services.nginx.defaultListenAddresses = lib.mkForce [
    "0.0.0.0"
    "[::]"
  ];

  # sqlite CLI for the test script's assertions.
  environment.systemPackages = [ pkgs.sqlite ];
}
