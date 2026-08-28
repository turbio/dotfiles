# immich — stage-1, deliberately fresh: its own library (module-default
# /var/lib/immich on the persistVar dataset), its own postgres + redis
# in-vm, running side by side with the host instance while it proves out.
# the two instances share NOTHING — two immiches must never write one
# library. upload test photos here; the host at ballos:2283 stays the real
# one until cutover.
#
# this vm debuts the storage policy's database rule: postgres lives on a
# virtio-blk volume (ext4 image in the vm's dataset), not virtiofs —
# bench 2026-07-28: blk ~5.3k fsync/s vs virtiofs ~3.6k, and postgres is
# fsync-bound.
#
# cutover notes (turbio's ledger):
#   - DONE 2026-07-31: db pg_dump/restored (57570 assets verified both
#     sides), library reflink-cloned into the persistVar dataset + chowned
#     to the guest's immich uid, immich's own automatic media-location
#     migration rewrote the stored paths, host instance removed. point
#     apps at http://immich.int.turb.io (port 80).
#   - remove later: tank/enc/immich (old library; blocks are reflink-
#     shared with the vm's copy, destroying frees little until they
#     diverge), the `immich` db in ballos postgres, and the
#     tank/enc/vms/immich snapshots from the migration window (they pin
#     the aborted rsync's non-cloned blocks)
{ inventory, vm, ... }:
{
  services.immich = {
    enable = true;
    host = "0.0.0.0";
    # plain http://immich.int.turb.io, no port fiddling in the app
    port = 80;
    # mediaLocation stays the module default /var/lib/immich -> persistVar
  };
  # the module's hardened unit (PrivateUsers) strips ambient capabilities,
  # so CAP_NET_BIND_SERVICE can't work — instead make :80 unprivileged.
  # fine posture for a single-service vm: the whole guest is immich's.
  boot.kernel.sysctl."net.ipv4.ip_unprivileged_port_start" = 80;

  # postgres on virtio-blk per storage policy; 20G sparse (db is ~1G today)
  microvm.volumes = [
    {
      image = "${inventory.storage.vmsPath}/${vm.name}/postgres.img";
      mountPoint = "/var/lib/postgresql";
      size = 20480;
    }
  ];
}
