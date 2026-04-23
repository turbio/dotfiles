# NixOS VM integration test that boots the full ballos configuration (with
# the hardware/ACME/age stubs in ./ballos-vm-overrides.nix) and checks that
# forgejo + buildbot provisioning actually works end-to-end.
{
  pkgs,
  hostModulesList,
  hostSpecialArgs,
}:

let
  lib = pkgs.lib;
  # ballos's configuration.nix / vim.nix set allowUnfree = true. The test
  # framework would otherwise lock nixpkgs.config to read-only defaults
  # (allowUnfree = false), which conflicts. Inject a pre-configured pkgs.
  pkgsWithUnfree = import pkgs.path {
    system = "x86_64-linux";
    config.allowUnfree = true;
  };
in
pkgs.testers.runNixOSTest {
  name = "ballos-vm";

  node.specialArgs = hostSpecialArgs "ballos";
  node.pkgs = lib.mkForce pkgsWithUnfree;
  node.pkgsReadOnly = lib.mkForce false;

  nodes.machine = {
    imports = hostModulesList [ ./ballos-vm-overrides.nix ] "ballos";
  };

  testScript = ''
    machine.start()

    with subtest("system reaches multi-user"):
        machine.wait_for_unit("multi-user.target", timeout=900)

    with subtest("tank zpool is up and forgejo dataset dir exists"):
        machine.wait_until_succeeds("zpool list tank")
        # zfs-ensure-* are oneshot (no RemainAfterExit) so wait_for_unit
        # never sees them as "active". Check the end state: the dataset
        # directory should exist with the right perms.
        machine.wait_until_succeeds("zfs list tank/enc/forgejo")
        machine.wait_until_succeeds("test -d /tank/enc/forgejo")

    with subtest("forgejo comes up"):
        machine.wait_for_unit("forgejo.service")
        machine.wait_for_open_port(3300)
        machine.succeed("curl -sfo /dev/null http://127.0.0.1:3300/")

    with subtest("forgejo-bootstrap provisions admin, token, and OAuth app"):
        machine.wait_for_unit("forgejo-bootstrap.service")
        db = "/tank/enc/forgejo/forgejo.db"

        machine.succeed(
            f"sqlite3 {db} "
            "\"SELECT COUNT(*) FROM user WHERE lower_name = 'turbio'\" "
            "| grep -qx 1"
        )
        machine.succeed("test -s /var/lib/forgejo-bootstrap/api-token")
        machine.succeed(
            f"sqlite3 {db} "
            "\"SELECT client_secret FROM oauth2_application "
            "WHERE client_id = 'buildbot'\" "
            "| grep -Eq '^\\$2[aby]\\$'"
        )

    with subtest("forgejo-bootstrap is idempotent"):
        token_before = machine.succeed("cat /var/lib/forgejo-bootstrap/api-token")
        machine.succeed("systemctl restart forgejo-bootstrap.service")
        machine.wait_for_unit("forgejo-bootstrap.service")
        token_after = machine.succeed("cat /var/lib/forgejo-bootstrap/api-token")
        assert token_before == token_after, "API token changed across re-runs"

        count = machine.succeed(
            "sqlite3 /tank/enc/forgejo/forgejo.db "
            "\"SELECT COUNT(*) FROM oauth2_application "
            "WHERE client_id = 'buildbot'\""
        ).strip()
        assert count == "1", f"expected 1 oauth2_application row, got {count}"

    with subtest("buildbot-master starts after bootstrap and sees its creds"):
        machine.wait_for_unit("buildbot-master.service")
        machine.succeed("test -s /run/credentials/buildbot-master.service/gitea-token")
        machine.succeed("test -s /run/credentials/buildbot-master.service/gitea-oauth-secret")
        machine.succeed("test -s /run/credentials/buildbot-master.service/gitea-webhook-secret")

    with subtest("buildbot-worker connects"):
        machine.wait_for_unit("buildbot-worker.service")

    with subtest("nginx serves forge.turb.io with our self-signed cert"):
        machine.wait_for_unit("nginx.service")
        machine.succeed(
            "curl -sfk -o /dev/null https://forge.turb.io/"
        )
  '';
}
