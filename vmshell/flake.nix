{
  description = "like a dev shell but it runs in a vm";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    microvm.url = "github:microvm-nix/microvm.nix";
    microvm.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    {
      self,
      nixpkgs,
      microvm,
    }:
    {
      lib = import ./default.nix { inherit microvm nixpkgs; };
      checks = import ./checks.nix {
        inherit nixpkgs;
        inherit (self) lib;
      };
    };
}
