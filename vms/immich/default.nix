{ inventory, vm, ... }:
{
  services.immich = {
    enable = true;
    host = "0.0.0.0";
    port = 80;
  };

  boot.kernel.sysctl."net.ipv4.ip_unprivileged_port_start" = 80;

  microvm.volumes = [
    {
      image = "${inventory.storage.vmsPath}/${vm.name}/postgres.img"; # TODO: should probably be in inventory
      mountPoint = "/var/lib/postgresql";
      size = 20480;
    }
  ];
}
