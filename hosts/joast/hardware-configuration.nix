{ modulesPath, ... }:
{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
    ../../modules/netbootable_scratch.nix
  ];

  netboot.macAddresses = [
    "b8:83:03:8a:10:ac"
    "b8:83:03:8a:10:ad"
    "54:80:28:54:ac:f8"
  ];
  netboot.storeImageFormat = "erofs";

  boot.initrd.availableKernelModules = [
    "ehci_pci"
    "ahci"
    "usb_storage"
    "sd_mod"
    "sdhci_pci"
  ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-intel" ];
  boot.extraModulePackages = [ ];

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
  systemd.network.networks."50-eno1" = {
    matchConfig.Name = "eno1";
    networkConfig.DHCP = "yes";
    dhcpV4Config.RouteMetric = 2000;
  };

  # avoid arp flux
  boot.kernel.sysctl = {
    "net.ipv4.conf.all.arp_ignore" = 1;
    "net.ipv4.conf.all.arp_announce" = 2;
    "net.ipv4.conf.default.arp_ignore" = 1;
    "net.ipv4.conf.default.arp_announce" = 2;
  };
}
