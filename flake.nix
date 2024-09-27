{
  description = "My dotfiles uwu";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-23.11";
    unstable.url = "github:nixos/nixpkgs/master";

    # localpkgs.url = "/home/turbio/code/nixpkgs";

    home-manager = {
      url = "github:rycee/home-manager/release-23.11";
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

    hyprland = {
      url = "github:vaxerski/Hyprland";
      # build with your own instance of nixpkgs
      inputs.nixpkgs.follows = "unstable";
    };

  };

  outputs = { self, nixpkgs, home-manager, unstable, ... }@inputs:
    let
      system = "x86_64-linux";
      unstablepkgs = import unstable {
        inherit system;
        config.allowUnfree = true;
      };
    in
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
                  #(inputs.hyprland.nixosModules.default)
                  #({ programs.hyprland.enable = true; })
                ];
                specialArgs = {
                  hostname = c;
                  localpkgs = inputs.localpkgs.legacyPackages.x86_64-linux;
                  pkgs = import nixpkgs {
                    inherit system;
                    overlays = [
                      # pick some unstable stuff
                      (self: super: with unstablepkgs; {
                        inherit discord obs-studio mars-mips fish;

                        obs-studio-plugins = unstablepkgs.obs-studio-plugins;
                        vimPlugins = super.vimPlugins // { vim-fugitive = unstablepkgs.vimPlugins.vim-fugitive; };
                      })
                    ];
                    config.allowUnfree = true; # owo sowwy daddy stallman
                  };

                  repos = inputs;
                };
              };
        })
        (builtins.attrNames (builtins.readDir ./hosts)));
    };
}
