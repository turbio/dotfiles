{
  description = "My dotfiles uwu";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }: {

    nixosConfigurations = builtins.listToAttrs (map
      (c: {
        name = c;
        value = nixpkgs.lib.nixosSystem
          {
            system = "x86_64-linux";
            modules = [ ./configuration.nix ];
            specialArgs = {
              hostname = c;
            };
          };
      })
      (builtins.attrNames (builtins.readDir ./hosts)));
  };
}
