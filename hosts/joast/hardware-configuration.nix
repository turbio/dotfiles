{ modulesPath, ... }:
{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  boot.loader.grub.enable = false;
  boot.kernelParams = [ "zfs.zfs_arc_sys_free=8589934592" ];
  boot.supportedFilesystems = [ "zfs" ];
  boot.zfs.extraPools = [ "tank" ];
  networking.hostId = "00ba1105";

  # whole store lives on zfs and gets bind mounted over /nix/store in initrd, so
  # nothing but kernel+initrd has to be on the root ssd. that means tank imports
  # and tank/enc unlocks in initrd, which is where the key prompt shows up.
  # the ext4 /nix/store under the bind stays as a fallback for pre-zfs gens
  #
  # tank and tank/enc get mounted in initrd too, otherwise stage 2's zfs mount -a
  # drops tank over /tank and buries the nixstore mount underneath it
  fileSystems."/tank" = {
    device = "tank";
    fsType = "zfs";
    options = [ "zfsutil" ];
    neededForBoot = true;
  };
  fileSystems."/tank/enc" = {
    device = "tank/enc";
    fsType = "zfs";
    options = [ "zfsutil" ];
    neededForBoot = true;
  };
  fileSystems."/tank/enc/nixstore" = {
    device = "tank/enc/nixstore";
    fsType = "zfs";
    options = [ "zfsutil" ];
    neededForBoot = true;
  };
  fileSystems."/nix/store" = {
    device = "/tank/enc/nixstore";
    fsType = "none";
    options = [ "bind" ];
    depends = [ "/tank/enc/nixstore" ];
  };

  # the zfs.pools ensure unit runs far too late to create the dataset for boot
  # (it was created by hand), but it still owns the properties: virtiofsd
  # exports the store to the microvms with --posix-acl, and without posixacl the
  # host answers the guest's acl lookup with EOPNOTSUPP, which the guest kernel
  # turns into exec failures for every non-root service.
  zfs.pools.tank.datasets."enc/nixstore".properties = {
    acltype = "posixacl";
    xattr = "sa";
  };

  # sandbox build dirs on zfs (sync=disabled) instead of the root disk. after
  # zfs-mount so this and zfs mount -a don't race for the same dataset
  fileSystems."/tank/enc/nixbuilds" = {
    device = "tank/enc/nixbuilds";
    fsType = "zfs";
    options = [
      "zfsutil"
      "x-systemd.after=zfs-mount.service"
    ];
  };
  fileSystems."/nix/var/nix/builds" = {
    device = "/tank/enc/nixbuilds";
    fsType = "none";
    options = [ "bind" ];
    depends = [ "/tank/enc/nixbuilds" ];
  };

  boot.initrd.availableKernelModules = [
    "ehci_pci"
    "ahci"
    "usb_storage"
    "sd_mod"
    "sdhci_pci"

    # for the hpe gen10 sas controller
    "smartpqi"
  ];
  boot.initrd.kernelModules = [
    "kvm-intel"

    # is my sas controller fucked??? takes mintues to init but userspace gets
    # fucked up without it so we'll let initrd do the waiting
    "mpt3sas"
  ];

  networking.useNetworkd = true;

  networking.bonds.bond0 = {
    interfaces = [
      "eno5np0"
      "eno6np1"
    ];
    driverOptions = {
      mode = "802.3ad";
      miimon = "100";
      lacp_rate = "fast";
      xmit_hash_policy = "layer3+4";
    };
  };
  networking.interfaces.bond0.useDHCP = true;

  systemd.network.networks."40-bond0".dhcpV4Config.RouteMetric = 100;
  systemd.network.networks."40-bond0".ipv6AcceptRAConfig.RouteMetric = 100;
  networking.interfaces.bond0.macAddress = "b8:83:03:8a:10:ac";
  systemd.network.networks."50-eno1" = {
    matchConfig.Name = "eno1";
    networkConfig.DHCP = "yes";
    dhcpV4Config.RouteMetric = 2000;
    ipv6AcceptRAConfig.RouteMetric = 2000;
  };

  boot.initrd.systemd = {
    enable = true;
    emergencyAccess = true;
  };

  # avoid arp flux
  boot.kernel.sysctl = {
    "net.ipv4.conf.all.arp_ignore" = 1;
    "net.ipv4.conf.all.arp_announce" = 2;
    "net.ipv4.conf.default.arp_ignore" = 1;
    "net.ipv4.conf.default.arp_announce" = 2;
  };

  disko.devices.disk.main = {
    type = "disk";
    content = {
      type = "gpt";
      partitions = {
        ESP = {
          type = "EF00";
          size = "500M";
          content = {
            type = "filesystem";
            format = "vfat";
            mountpoint = "/boot";
            mountOptions = [ "umask=0077" ];
          };
        };
        root = {
          size = "100%";
          content = {
            type = "filesystem";
            format = "ext4";
            mountpoint = "/";
          };
        };
        swap = {
          size = "128G";
          content = {
            type = "swap";
          };
        };
      };
    };
  };
}
