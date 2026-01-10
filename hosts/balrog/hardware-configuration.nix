{ lib, modulesPath, ... }:
{
  imports = [
    "${modulesPath}/virtualisation/google-compute-image.nix"
  ];

  security.pam.services.sshd.googleOsLoginAccountVerification = lib.mkForce false;
}
