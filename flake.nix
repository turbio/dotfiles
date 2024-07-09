{
  description = "My dotfiles uwu";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-23.05";
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
    unstable.url = "github:nixos/nixpkgs/master";

    home-manager = {
      url = "github:rycee/home-manager/release-23.05";
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
    dash.url = "path:/home/turbio/code/home";

    raspberry-pi-nix.url = "github:tstat/raspberry-pi-nix";

    #hyprland = {
    #  url = "github:vaxerski/Hyprland";
    #  # build with your own instance of nixpkgs
    #  inputs.nixpkgs.follows = "unstable";
    #};
  };

  outputs =
    { self
    , nixpkgs
    , home-manager
    , nixos-hardware
    , unstable
    , ...
    }@inputs: rec {
      nixosConfigurations = builtins.listToAttrs
        (map
          (c:
            let
              system = if c == "pando" then "aarch64-linux" else "x86_64-linux";
              unstablepkgs = import unstable {
                inherit system;
                config.allowUnfree = true;
              };
            in
            {
              name = c;
              value =
                nixpkgs.lib.nixosSystem {
                  inherit system;
                  modules = [
                    ./configuration.nix
                    ./desktop.nix
                    ./home.nix
                    (./hosts + "/${c}" + /hardware-configuration.nix)
                    (./hosts + "/${c}" + /host.nix)
                    ./cachix.nix
                    ./vpn.nix
                    # ./evergreen.nix maybe later
                    (home-manager.nixosModules.home-manager)
                  ];

                  specialArgs = {
                    hostname = c;
                    unstablepkgs = unstablepkgs;

                    # kinda fucky, probably incorrect... sometimes usefull when
                    # we really don't want anyone to fuck w our nixpkgs
                    #pkgs = import nixpkgs {
                    #  inherit system;
                    #  overlays = [
                    #    # pick some unstable stuff
                    #    (self: super: with unstablepkgs; {
                    #      inherit discord obs-studio mars-mips fish;

                    #      obs-studio-plugins = unstablepkgs.obs-studio-plugins;
                    #      vimPlugins = super.vimPlugins // { vim-fugitive = unstablepkgs.vimPlugins.vim-fugitive; };
                    #    })

                    #    # cause openra is fucked in upstream
                    #    (self: super: {
                    #      openra = (super.appimageTools.wrapType2 {
                    #        name = "openra";
                    #        src = super.fetchurl
                    #          {
                    #            url = "https://github.com/OpenRA/OpenRA/releases/download/release-20210321/OpenRA-Red-Alert-x86_64.AppImage";
                    #            sha256 = "sha256-toJ416/V0tHWtEA0ONrw+JyU+ssVHFzM6M8SEJPIwj0=";
                    #          };
                    #      });
                    #    })

                    #  ];
                    #  config.allowUnfree = true; # owo sowwy daddy stallman
                    #};

                    repos = inputs;
                  };
                };
            })
          (builtins.attrNames (builtins.readDir ./hosts)));

      # can build this to make a flashable raspi image
      images.pando = nixosConfigurations.pando.config.system.build.sdImage;
    };
}
