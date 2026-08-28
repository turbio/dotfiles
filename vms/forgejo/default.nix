# forgejo — stage-1 duplicate of the host instance, empty state (the host
# owns tank/enc/forgejo until cutover; sqlite-on-virtiofs is proven by
# grafana's db on the same share type). state lives on the persistVar
# dataset at the module-default /var/lib/forgejo. prod identity (domain,
# ssh port 22 advertisement) configured from the start, like grafana —
# stage-1 verification goes over http://<vm>:3300 and ssh -p 2222 directly.
#
# deliberately not in stage-1 (moves at cutover):
#   - the forgejo-bootstrap unit (admin user + buildbot oauth + api token):
#     needs age secrets inside the guest — guest host keys are persisted in
#     /var/lib/ssh, so agenix can target them; wire that up at cutover. the
#     migrated db carries the existing admin/oauth rows anyway.
#
# cutover notes (turbio's ledger):
#   - data: DONE 2026-07-30 (rsync /tank/enc/forgejo -> the persistVar
#     dataset + in-guest chown -R forgejo:forgejo — forgejo's uid is
#     dynamically allocated and DIFFERS between host (973) and guest (999),
#     unlike grafana/prometheus's static ids). host copy still on disk as
#     fallback; instances have diverged from this point.
#   - retarget forge.turb.io vhost 127.0.0.1:3300 -> vm :3300; retarget the
#     edge dnat (modules/edge-router.nix) from ballos-tailscale:2222 to the
#     vm's :2222; drop host forgejo + its firewall 2222 + bootstrap (moves
#     here with agenix); host keeps no forgejo state
{ config, lib, ... }:
{
  services.forgejo = {
    enable = true;

    database = {
      type = "sqlite3";
      # the host instance kept its db at the stateDir top level, not the
      # module-default data/forgejo.db — the migrated data preserves that
      # layout, so pin it (a fresh empty db at the default path is exactly
      # the "my login stopped working" failure)
      path = "${config.services.forgejo.stateDir}/forgejo.db";
    };

    settings = {
      DEFAULT.APP_NAME = "forge";

      server = {
        DOMAIN = "forge.turb.io";
        ROOT_URL = "https://forge.turb.io/";
        HTTP_ADDR = "0.0.0.0";
        HTTP_PORT = 3300;
        # SSH_PORT is what clone URLs advertise (edge routers DNAT public
        # :22 → :2222, so the user-facing port is 22). The forgejo built-in
        # SSH daemon still binds to 2222 locally.
        SSH_PORT = 22;
        SSH_LISTEN_PORT = 2222;
        START_SSH_SERVER = true;
        # Accept the conventional `git@forge.turb.io:owner/repo.git` URL
        # (both the displayed one and the one the built-in SSH server
        # authenticates against); otherwise nixpkgs' forgejo would default
        # both to `forgejo@…`.
        SSH_USER = "git";
        BUILTIN_SSH_SERVER_USER = "git";
        # Forgejo's built-in SSH server doesn't advertise PQ KEX by
        # default, so current openssh clients print "connection is not
        # using a post-quantum key exchange algorithm". Go crypto/ssh in
        # the version bundled here supports mlkem768x25519-sha256 — list
        # it first.
        SSH_SERVER_KEY_EXCHANGES = lib.concatStringsSep "," [
          "mlkem768x25519-sha256"
          "sntrup761x25519-sha512@openssh.com"
          "curve25519-sha256"
          "curve25519-sha256@libssh.org"
          "ecdh-sha2-nistp256"
          "ecdh-sha2-nistp384"
          "ecdh-sha2-nistp521"
          "diffie-hellman-group14-sha256"
        ];
      };

      service.DISABLE_REGISTRATION = true;
      session.COOKIE_SECURE = true;
      actions.ENABLED = false;

      # Apply repack.writeBitmaps to every `git` invocation forgejo makes
      # (including the cron gc below), so reachability bitmaps are kept up
      # to date. Without bitmaps, fresh clones of large repos (e.g.
      # turbio/nixpkgs) walk the full object graph server-side and blow
      # past nginx's 60s proxy_read_timeout, producing HTTP 504.
      "git.config" = {
        "repack.writeBitmaps" = true;
      };

      # the default GC deadline is 60s — a full repack of the nixpkgs
      # mirror never finished inside it (observed on the host instance for
      # ages: "context deadline exceeded", which is also why its bitmaps
      # kept going stale). an hour is generous; the repack is background
      # work either way.
      "git.timeout".GC = 3600;

      # Periodic git gc / repack across all repos so bitmaps and
      # commit-graphs stay current as refs move.
      "cron.git_gc_repos" = {
        ENABLED = true;
        RUN_AT_START = false;
        SCHEDULE = "@every 24h";
      };
    };
  };
}
