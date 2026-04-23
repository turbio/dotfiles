{
  config,
  lib,
  pkgs,
  ...
}:
let
  zfsService = "zfs-ensure-tank-enc-forgejo.service";

  forgejoPkg = config.services.forgejo.package;
  appIni = "${config.services.forgejo.customDir}/conf/app.ini";
  dbPath = config.services.forgejo.database.path;

  adminUser = "turbio";
  adminEmail = "turbio@turb.io";

  buildbotClientId = "buildbot";
  buildbotRedirectUri = "https://buildbot.turb.io/auth/login";

  bootstrapEnv = pkgs.python3.withPackages (ps: [ ps.bcrypt ]);

  # SSH public keys attached to the forgejo admin user, authorizing
  # `git push git@forge.turb.io:turbio/...`. Idempotent in the bootstrap
  # service; add more entries as needed.
  adminSshKeys = {
    turbio-main = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIONmQgB3t8sb7r+LJ/HeaAY9Nz2aPS1XszXTub8A1y4n";
  };
in
{
  zfs.pools.tank.datasets."enc/forgejo" = {
    perms.owner = "forgejo";
    perms.group = "forgejo";
    perms.mode = "750";
  };

  services.forgejo = {
    enable = true;
    stateDir = config.zfs.pools.tank.datasets."enc/forgejo".mountpoint;

    database = {
      type = "sqlite3";
      path = "${config.zfs.pools.tank.datasets."enc/forgejo".mountpoint}/forgejo.db";
    };

    settings = {
      DEFAULT.APP_NAME = "forge";

      server = {
        DOMAIN = "forge.turb.io";
        ROOT_URL = "https://forge.turb.io/";
        HTTP_ADDR = "127.0.0.1";
        HTTP_PORT = 3300;
        # SSH_PORT is what clone URLs advertise (edge routers DNAT public
        # :22 → ballos :2222, so the user-facing port is 22). The forgejo
        # built-in SSH daemon still binds to 2222 locally.
        SSH_PORT = 22;
        SSH_LISTEN_PORT = 2222;
        START_SSH_SERVER = true;
        # Accept the conventional `git@forge.turb.io:owner/repo.git` URL
        # (both the displayed one and the one the built-in SSH server
        # authenticates against); otherwise nixpkgs' forgejo would default
        # both to `forgejo@…`.
        SSH_USER = "git";
        BUILTIN_SSH_SERVER_USER = "git";
      };

      service.DISABLE_REGISTRATION = true;
      session.COOKIE_SECURE = true;
      actions.ENABLED = false;
    };
  };

  services.nginx.virtualHosts."forge.turb.io" = {
    forceSSL = true;
    useACMEHost = "turb.io";
    http2 = true;

    locations."/" = {
      proxyPass = "http://127.0.0.1:3300";
      extraConfig = ''
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        client_max_body_size 512M;
      '';
    };
  };

  systemd.services.forgejo-secrets.after = [ zfsService ];
  systemd.services.forgejo-secrets.requires = [ zfsService ];

  # Idempotent provisioning so buildbot-nix can talk to forgejo without any
  # manual UI steps. Runs after forgejo.service is up; on each activation it
  # ensures:
  #   1. The admin user exists (created via the forgejo CLI).
  #   2. An API access token for that user is persisted at
  #        /var/lib/forgejo-bootstrap/api-token
  #      so buildbot can authenticate API requests (repo reads, webhook
  #      installs on repos tagged `build-with-buildbot`).
  #   3. An OAuth2 application named `buildbot` exists with a fixed
  #      client_id (so it's committable in nix) and a client_secret whose
  #      plaintext comes from the age-encrypted forgejo-oauth-secret.
  #      The row is inserted directly into forgejo's sqlite DB since
  #      forgejo has no CLI/API for declaring an OAuth app with a
  #      caller-chosen client_id — the secret column stores a bcrypt hash,
  #      matching what `CreateOAuth2Application` would have produced.
  systemd.services.forgejo-bootstrap = {
    description = "Provision forgejo admin user + buildbot OAuth application";
    after = [ "forgejo.service" ];
    requires = [ "forgejo.service" ];
    wantedBy = [ "multi-user.target" ];

    path = [
      forgejoPkg
      pkgs.sqlite
      pkgs.gawk
      pkgs.gnugrep
      pkgs.coreutils
      pkgs.curl
      pkgs.jq
      bootstrapEnv
    ];

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      User = "forgejo";
      Group = "forgejo";
      StateDirectory = "forgejo-bootstrap";
      StateDirectoryMode = "0700";
      LoadCredential = [
        "oauth-client-secret:${config.age.secrets."forgejo-oauth-secret".path}"
        "admin-password:${config.age.secrets."forgejo-admin-password".path}"
      ];
    };

    script = ''
      set -eu

      admin_user=${adminUser}
      admin_email=${adminEmail}
      client_id=${buildbotClientId}
      redirect_uri=${buildbotRedirectUri}
      app_ini=${appIni}
      db=${dbPath}
      state=$STATE_DIRECTORY

      # 1. Ensure admin user exists with the password from the age secret.
      # We hash the plaintext and compare against a stored hash so rotating
      # the age file pushes the new password into forgejo on the next run.
      pw_file="$CREDENTIALS_DIRECTORY/admin-password"
      pw_hash=$(sha256sum "$pw_file" | awk '{print $1}')
      stored_hash=""
      if [ -f "$state/admin-password.hash" ]; then
        stored_hash=$(cat "$state/admin-password.hash")
      fi

      if ! forgejo -c "$app_ini" admin user list | grep -qw "$admin_user"; then
        forgejo -c "$app_ini" admin user create \
          --username "$admin_user" \
          --email "$admin_email" \
          --admin \
          --password "$(cat "$pw_file")" \
          --must-change-password=false
        echo -n "$pw_hash" > "$state/admin-password.hash"
      elif [ "$stored_hash" != "$pw_hash" ]; then
        forgejo -c "$app_ini" admin user change-password \
          --username "$admin_user" \
          --password "$(cat "$pw_file")" \
          --must-change-password=false
        echo -n "$pw_hash" > "$state/admin-password.hash"
      fi

      # 2. Ensure API token exists (idempotent by file presence).
      if [ ! -s "$state/api-token" ]; then
        umask 077
        forgejo -c "$app_ini" admin user generate-access-token \
          --username "$admin_user" \
          --token-name buildbot \
          --scopes write:admin,write:repository,write:issue,write:user \
          --raw > "$state/api-token.tmp"
        mv "$state/api-token.tmp" "$state/api-token"
      fi

      # 3. Ensure OAuth2 application row exists.
      oauth_count=$(sqlite3 "$db" \
        "SELECT COUNT(*) FROM oauth2_application WHERE client_id = '$client_id';")
      if [ "$oauth_count" -eq 0 ]; then
        uid=$(sqlite3 "$db" \
          "SELECT id FROM user WHERE lower_name = lower('$admin_user');")
        if [ -z "$uid" ]; then
          echo "forgejo-bootstrap: admin user '$admin_user' not found after create" >&2
          exit 1
        fi

        hash=$(python3 <<'PY'
      import os, bcrypt
      with open(os.environ["CREDENTIALS_DIRECTORY"] + "/oauth-client-secret", "rb") as f:
          secret = f.read().strip()
      print(bcrypt.hashpw(secret, bcrypt.gensalt(10)).decode())
      PY
              )

              sqlite3 "$db" <<SQL
      INSERT INTO oauth2_application
        (uid, name, client_id, client_secret, confidential_client,
         redirect_uris, created_unix, updated_unix)
      VALUES
        ($uid, 'buildbot', '$client_id', '$hash', 1,
         '["$redirect_uri"]',
         strftime('%s','now'), strftime('%s','now'));
      SQL
      fi

      api=http://127.0.0.1:${toString config.services.forgejo.settings.server.HTTP_PORT}/api/v1
      token=$(cat "$state/api-token")
      auth_hdr="Authorization: token $token"
      ${lib.concatStrings (
        lib.mapAttrsToList (title: key: ''
          if ! curl -sfS -H "$auth_hdr" "$api/user/keys" \
              | jq -e --arg t ${lib.escapeShellArg title} 'any(.[]; .title == $t)' >/dev/null; then
            curl -sfS -H "$auth_hdr" -H "Content-Type: application/json" \
              -X POST "$api/user/keys" \
              -d ${
                lib.escapeShellArg (
                  builtins.toJSON {
                    inherit title key;
                    read_only = false;
                  }
                )
              } >/dev/null
            echo "forgejo-bootstrap: added SSH key '${title}' to $admin_user"
          fi
        '') adminSshKeys
      )}
    '';
  };

  networking.firewall.allowedTCPPorts = [ 2222 ];
}
