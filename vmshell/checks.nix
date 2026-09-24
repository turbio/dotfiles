{ nixpkgs, lib, ... }:
let
  pkgs = import nixpkgs {
    system = "x86_64-linux";
  };

  shellWithHello = lib.mkVMShell {
    vm.hostPlatform = "x86_64-linux";
    buildInputs = with pkgs; [
      hello
    ];
  };

  vmPackageWithHello = lib.mkVMPackage {
    vm.hostPlatform = "x86_64-linux";
    buildInputs = with pkgs; [
      hello
    ];
  };
in
{
  x86_64-linux.default = pkgs.runCommand "wow" { } ''
    # just make sure they cna build
    echo ${shellWithHello}
    echo ${vmPackageWithHello}

    touch $out
  '';
}
