{ config, lib, ... }:
{
  services.forgejo = {
    enable = true;

    database = {
      type = "sqlite3";
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

      "git.config" = {
        "repack.writeBitmaps" = true;
      };

      "git.timeout".GC = 3600;

      "cron.git_gc_repos" = {
        ENABLED = true;
        RUN_AT_START = false;
        SCHEDULE = "@every 24h";
      };
    };
  };
}
