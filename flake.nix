{
  description = "My dotfiles uwu";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    neovim-nightly-overlay.url = "github:nix-community/neovim-nightly-overlay";
    home-manager = {
      url = "github:rycee/home-manager/release-21.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, neovim-nightly-overlay }:
    let system = "x86_64-linux"; in
    {
      nixosConfigurations = builtins.listToAttrs (map
        (c: {
          name = c;
          value =
            nixpkgs.lib.nixosSystem
              {
                inherit system;
                modules = [
                  ./configuration.nix
                  (home-manager.nixosModules.home-manager)
                ];
                specialArgs = {
                  hostname = c;
                  pkgs = import nixpkgs {
                    inherit system;
                    overlays = [ neovim-nightly-overlay.overlay ];

                    config.allowUnfree = true; # owo sowwy daddy stallman
                  };
                };
              };
        })
        (builtins.attrNames (builtins.readDir ./hosts)));
    };
}
