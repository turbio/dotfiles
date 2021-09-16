{
  description = "My dotfiles uwu";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:rycee/home-manager/release-21.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager }: with builtins; {

    nixosConfigurations = listToAttrs (map
      (c: {
        name = c;
        value = nixpkgs.lib.nixosSystem
          {
            system = "x86_64-linux";
            modules = [
              ./configuration.nix
              (home-manager.nixosModules.home-manager)
            ];
            specialArgs = {
              hostname = c;
              uwu = trace "hmm er${nixpkgs}" "${nixpkgs}";
            };
          };
      })
      (attrNames (readDir ./hosts)));
  };
}
