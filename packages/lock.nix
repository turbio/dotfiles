# bin/lock, with its runtime deps baked into the script itself so it works
# from a systemd unit, a keybind, or a bare shell with an empty PATH.
{
  lib,
  writeShellApplication,
  coreutils,
  procps,
  systemd,
  jq,
  grim,
  stackblur-go,
  swaylock,
  niri,
}:
writeShellApplication {
  name = "lock";

  # deliberately no errexit: every screenshot/blur step is best-effort, and
  # bailing out of one of them must not mean the screen goes unlocked
  bashOptions = [
    "nounset"
    "pipefail"
  ];

  runtimeInputs = [
    coreutils # timeout, id, mkdir, chmod, rm, sleep
    procps # pgrep, pkill
    systemd # systemctl
    jq
    grim
    stackblur-go # stackblur
    swaylock
    niri # niri msg
  ];

  # the shebang would land mid-file once writeShellApplication adds its own
  text = lib.removePrefix "#!/usr/bin/env bash\n" (builtins.readFile ../bin/lock);

  meta.mainProgram = "lock";
}
