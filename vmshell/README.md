# VMShell

A drop in replacement for mkShell with isolation

The guest boots with the project directory mounted at `~/project-root` and the
host attaches over ssh on AF_VSOCK via systemd-ssh-proxy (no networking involved). The serial console
is streamed to the terminal until sshd answers, then ssh takes over — so TERM
and window size propagate like any ssh session. The vm is powered off when ssh
returns.

`vm` attrs:

- `hostPlatform` / `pkgs` — one of these is required
- `guestPlatform` — defaults to the host platform
- `modules` — extra nixos modules for the guest
- `user` — the login user (default `nixos`). Drives autologin, the project
  mount ownership and path, and the login shell init. Defining the user in
  `modules` replaces the built-in definition entirely.

`nix run .#<package> -- <cmd>` runs `<cmd>` in the guest instead of an
interactive shell (as a non-login shell, so not from `~/project-root`).
