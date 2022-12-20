{
  description = "My dotfiles uwu";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-21.11";
    unstable.url = "github:nixos/nixpkgs/master";
    neovim-nightly-overlay.url = "github:nix-community/neovim-nightly-overlay";

    # localpkgs.url = "/home/turbio/code/nixpkgs";

    home-manager = {
      url = "github:rycee/home-manager/release-21.11";
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

    #hyprland = {
    #  url = "github:vaxerski/Hyprland";
    #  # build with your own instance of nixpkgs
    #  inputs.nixpkgs.follows = "unstable";
    #};

  };

  outputs = { self, nixpkgs, home-manager, neovim-nightly-overlay, unstable, ... }@inputs:
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
                      #neovim-nightly-overlay.overlay

                      # pick some unstable stuff
                      (self: super: with unstablepkgs; {
                        inherit discord obs-studio mars-mips fish;

                        obs-studio-plugins = unstablepkgs.obs-studio-plugins;
                        vimPlugins = super.vimPlugins // { vim-fugitive = unstablepkgs.vimPlugins.vim-fugitive; };
                      })

                      (self: super: {
                        openra = (super.appimageTools.wrapType2 {
                          name = "openra";
                          src = super.fetchurl
                            {
                              url = "https://github.com/OpenRA/OpenRA/releases/download/release-20210321/OpenRA-Red-Alert-x86_64.AppImage";
                              sha256 = "sha256-toJ416/V0tHWtEA0ONrw+JyU+ssVHFzM6M8SEJPIwj0=";
                            };
                        });
                      })


                      #(self: super: {
                      #  urbit = super.callPackage ./urbit.nix { };
                      #})
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
