# forge.turb.io — vhost only; forgejo itself lives in vms/forgejo (cut over
# 2026-07-30, data migrated same day). public ssh clones ride the edge dnat
# :22 -> the vm's :2222 (modules/edge-router.nix).
#
# left behind on purpose:
#   - /tank/enc/forgejo: the pre-cutover host state, kept as fallback until
#     turbio zfs-destroys it (dataset declaration dropped — data untouched)
#   - buildbot's api token at /var/lib/forgejo-bootstrap/api-token: still
#     valid against the migrated db; the bootstrap unit that minted it moves
#     into the vm with agenix-in-guest (see vms/forgejo ledger) — until
#     then rotation machinery is dormant, everything issued keeps working
{
  inventory,
  ...
}:
{
  services.nginx.virtualHosts."forge.turb.io" = {
    forceSSL = true;
    useACMEHost = "turb.io";
    http2 = true;

    locations."/" = {
      proxyPass = "http://${inventory.vms.forgejo.addr.ip4}:3300";
      extraConfig = ''
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        client_max_body_size 512M;
      '';
    };
  };
}
