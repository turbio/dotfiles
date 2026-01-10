let
  me = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIONmQgB3t8sb7r+LJ/HeaAY9Nz2aPS1XszXTub8A1y4n";
  aackle = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPKa5CiDUyWLbYaB/h0r7fSTd3dRS/1OImKvR8B109+/";
  backle = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFPCXE7qQxOFsDTxN0/LLExtNr2oRYxnMvJyW7UddWhO";
  cackle = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIM5hSwGfL0Ff+jvnpfPdEQA6uuFCNF0NpBbsCW4i8Qgp";
  ballos = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJWYDyDSh9zG0qFoJHMOM0W4QnXPsPZ7Z2D/QkdOQYIq";
  all = [
    me
    aackle
    backle
    cackle
    ballos
  ];
in
{
  "userpassword.age".publicKeys = all;

  # generate with `tsig-keygen rfc2136key`
  "rfc2136-acme.age".publicKeys = all;
  "rfc2136-xfer.age".publicKeys = all;
}
