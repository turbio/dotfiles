let
  me = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIONmQgB3t8sb7r+LJ/HeaAY9Nz2aPS1XszXTub8A1y4n";
  aackle = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPKa5CiDUyWLbYaB/h0r7fSTd3dRS/1OImKvR8B109+/";
  backle = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFPCXE7qQxOFsDTxN0/LLExtNr2oRYxnMvJyW7UddWhO";
  cackle = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIM5hSwGfL0Ff+jvnpfPdEQA6uuFCNF0NpBbsCW4i8Qgp";
  ballos = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJWYDyDSh9zG0qFoJHMOM0W4QnXPsPZ7Z2D/QkdOQYIq";
  mote = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEIKavDGGzGemCCwZ0n06JlwW/hAPxLMbLTdrrm2hAKS";
  curly = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINLLasBaQX/IdGPbnrD5TyPKHOBwaSnZNC9irMv16Bi1";
  itoh = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMRyt+V0ZWL+ISnC7J/d07Sj8k8/yZn2pkFCDC16XTvA";
  joast = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBOJ/J+mKaSFqz6HwYJv0jNhfNRGKdWydZaCDfW5iAdK";
  all = [
    me
    aackle
    backle
    cackle
    ballos
    joast
    mote
    curly
    itoh
  ];
in
{
  "userpassword.age".publicKeys = all;

  # generate with `tsig-keygen rfc2136key`
  "rfc2136-acme.age".publicKeys = all;
  "rfc2136-xfer.age".publicKeys = all;

  "forgejo-oauth-secret.age".publicKeys = all;
  "forgejo-webhook-secret.age".publicKeys = all;
  "forgejo-admin-password.age".publicKeys = all;
  # buildbot's forgejo api token (was minted imperatively by the old
  # forgejo-bootstrap unit at /var/lib/forgejo-bootstrap/api-token; the
  # buildbot vm receives it host-delivered)
  "forgejo-api-token.age".publicKeys = all;
  # ipinfo.io geoip download token (akvorado vm, host-delivered; was an
  # out-of-band file at /var/lib/akvorado-geoip/token)
  "ipinfo-token.age".publicKeys = all;
  "nix-builders-ssh-key.age".publicKeys = all;
}
