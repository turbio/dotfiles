{
  description = "My dotfiles uwu";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    neovim-nightly-overlay.url = "github:nix-community/neovim-nightly-overlay";
    home-manager = {
      url = "github:rycee/home-manager/release-21.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    github-copilot-vim = { flake = false; url = "github:github/copilot.vim"; };
    openscad-vim = { flake = false; url = "github:sirtaj/vim-openscad"; };
    muble-vim = { flake = false; url = "github:turbio/muble.vim"; };

    zsh-syntax-highlighting = { flake = false; url = "github:zsh-users/zsh-syntax-highlighting"; };
    zsh-history-substring-search = { flake = false; url = "github:zsh-users/zsh-history-substring-search"; };

    livewallpaper = { flake = false; url = "github:turbio/live_wallpaper/nixfix"; };
    evaldb = { flake = false; url = "github:turbio/evaldb"; };
    schemeclub = { flake = false; url = "github:turbio/schemeclub/nix"; };
    flippyflops = { flake = false; url = "github:turbio/flippyflops"; };
  };

  outputs = { self, nixpkgs, home-manager, neovim-nightly-overlay, ... }@inputs:
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

                  repos = inputs;
                };
              };
        })
        (builtins.attrNames (builtins.readDir ./hosts)));
    };
}
