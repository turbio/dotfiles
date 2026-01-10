{
  microvm,
  mksystem,
  pkgs,
  lib,
  ...
}:
let
  vmexec =
    mksystem [
      microvm.nixosModules.microvm
      (
        { pkgs, ... }:
        {
          users.users.root.password = "";
          microvm = {
            volumes = [
              {
                mountPoint = "/var";
                image = "var.img";
                size = 256;
              }
            ];
            shares = [
              {
                # use proto = "virtiofs" for MicroVMs that are started by systemd
                proto = "9p";
                tag = "ro-store";
                # a host's /nix/store will be picked up so that no
                # squashfs/erofs will be built for it.
                source = "/nix/store";
                mountPoint = "/nix/.ro-store";
                readOnly = true;
              }

              {
                proto = "9p";
                tag = "ro-host-home";
                source = "/home";
                mountPoint = "/shares/host-home";
                readOnly = true;
              }

              {
                proto = "9p";
                tag = "rw-project-root";
                source = "./devvm-checkout";
                mountPoint = "/shares/project-root";
                readOnly = false;
              }
            ];

            writableStoreOverlay = "/nix/.rw-store";

            # "qemu" has 9p built-in!
            hypervisor = "qemu";
            socket = "control.socket";

            interfaces =
              lib.optional true # qemu or kvmtool
                {
                  type = "user";
                  id = "qemu";
                  mac = "02:00:00:01:01:01";
                };
          };

          fileSystems = {
            "/home" = {
              overlay = {
                upperdir = "/shares/.overlay-host-home/upper";
                workdir = "/shares/.overlay-host-home/work";
                lowerdir = [ "/shares/host-home" ];
              };
              fsType = "overlay";
            };
          };

          systemd.services.myCustomStartupScript = {
            wantedBy = [ "multi-user.target" ]; # Ensures it runs at boot
            path = [
              pkgs.coreutils
              pkgs.bash
            ];
            enable = true;
            serviceConfig = {
              Type = "oneshot";
              User = "root";
              Group = "root";
            };
            script = ''
              chown -R turbio:users /home
            '';
          };

          isDesktop = true;
          services.getty.autologinUser = "turbio";
          environment.systemPackages = with pkgs; [
            claude-code
          ];

          systemd.timers."webcam-log".enable = false;
        }
      )
    ] "vm"
    |> (s: s.config.microvm.declaredRunner);
in
pkgs.writeShellScriptBin "devvm-in-cwd" ''
  set -euo pipefail

  repo_root=$(git rev-parse --show-toplevel)
  mkdir -p "$repo_root/devvm-checkout"
  cd "$repo_root"
  exec ${lib.getExe vmexec}
''
