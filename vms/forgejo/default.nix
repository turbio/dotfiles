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
        SSH_PORT = 22;
        SSH_LISTEN_PORT = 2222;
        START_SSH_SERVER = true;
        SSH_USER = "git";
        BUILTIN_SSH_SERVER_USER = "git";
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
