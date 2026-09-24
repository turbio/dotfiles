{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    vmshell.url = "git+https://git.turb.io/vmshell";
    vmshell.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    {
      self,
      nixpkgs,
      vmshell,
    }:
    let
      pkgs = import nixpkgs { system = "x86_64-linux"; };
    in
    {
      # enter with `nix develop`
      devShells.x86_64-linux.default = vmshell.lib.mkVMShell {
        vm.hostPlatform = "x86_64-linux";
        buildInputs = with pkgs; [
          git
          python3
        ];
      };

      # enter with `nix develop .#pkgs-example`
      devShells.x86_64-linux.pkgs-example = vmshell.lib.mkVMShell {
        vm.pkgs = pkgs;
        buildInputs = with pkgs; [
          git
          nodejs
          python3
        ];
      };

      devShells.x86_64-linux.aarch64-example =
        let
          # the passed in packages/buildInupts must target the guest system
          # either natively
          aarch64Pkgs = import nixpkgs { system = "aarch64-linux"; };

          # or cross
          aarch64Cross = import nixpkgs {
            system = "x86_64-linux";
            crossSystem.config = "aarch64-linux";
          };
        in
        vmshell.lib.mkVMShell {
          vm.hostPlatform = "x86_64-linux";
          vm.guestPlatform = "aarch64-linux";
          buildInputs = [
            aarch64Pkgs.git
            aarch64Cross.nodejs
          ];
        };

      # as a package that will mount the working directory into vm
      # run with `nix run .#devvm`
      packages.x86_64-linux.devvm = vmshell.lib.mkVMPackage {
        vm = { inherit pkgs; };
      };
    };
}
