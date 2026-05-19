# Imported by any host that wants to be a `nix.buildMachines` target for
# ballos. Provisions the `nixremote` user, accepts ballos's builder pubkey,
# and advertises the system-features ballos's nix-daemon expects to find
# on a remote builder.
{ lib, ... }:
{
  users.users.nixremote = {
    isNormalUser = true;
    description = "Remote-build account for ballos's nix-daemon";
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIZmfZntnzKWbcWMPghM4kPaDbfbYATLwwnNUJp4EbVT ballos-aarch-builder"
    ];
  };

  nix.settings.trusted-users = [ "nixremote" ];
  nix.settings.system-features = [
    "big-parallel"
    "benchmark"
    "nixos-test"
    "kvm"
  ];
}
