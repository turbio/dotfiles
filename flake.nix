{
  description = "My dotfiles uwu";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-24.05";
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
    unstable.url = "github:nixos/nixpkgs/master";
    nur.url = "github:nix-community/NUR";

    home-manager = {
      url = "github:rycee/home-manager/release-24.05";
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
    , nur
    , ...
  }@inputs:
    let
    arch = hostname: if hostname == "pando" then "aarch64-linux" else "x86_64-linux";
    mksystem = modules: hostname: nixpkgs.lib.nixosSystem {
      system = arch hostname;
      modules = [
        ./configuration.nix
        ./desktop.nix
        ./home.nix
        (./hosts + "/${hostname}" + /configuration.nix)
        (./hosts + "/${hostname}" + /hardware-configuration.nix)
        ./cachix.nix
        ./vpn.nix
        nur.nixosModules.nur
        # ./evergreen.nix maybe later
        (home-manager.nixosModules.home-manager)
      ] ++ modules;

      specialArgs = {
        inherit hostname;
        #unstablepkgs = unstablepkgs;
        #
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

    mapEachHost = fn: builtins.listToAttrs (map (c: { name = c; value = fn c; }) (builtins.attrNames (builtins.readDir ./hosts)));
    pxeExecScript = system: nixpkgs.legacyPackages.x86_64-linux.writers.writeBash "pixiecore" ''
      exec ${nixpkgs.legacyPackages.x86_64-linux.pixiecore}/bin/pixiecore \
        boot ${system.config.system.build.kernel}/bzImage ${system.config.system.build.netbootRamdisk}/initrd \
        --cmdline "init=${system.config.system.build.toplevel} loglevel=4"
        --debug --dhcp-no-bind \
        --port 64172 --status-port 64172 "$@"
    '';
    pxeModules = [
      ({ modulesPath, ... }: {
        imports = [
          (modulesPath + "/installer/netboot/netboot-minimal.nix")
        ];
      })
    ];
    imageModules = [
      ({ config, lib, pkgs, modulesPath, ... }: {

          imports = [ "${modulesPath}/image/repart.nix" ];

          image.repart = {
            name = "image";
            partitions = {
              "esp" = {
                contents = {
                  "/EFI/BOOT/BOOT${lib.toUpper pkgs.stdenv.hostPlatform.efiArch}.EFI".source =
                    "${pkgs.systemd}/lib/systemd/boot/efi/systemd-boot${pkgs.stdenv.hostPlatform.efiArch}.efi";

                  "/EFI/Linux/${config.system.boot.loader.ukiFile}".source =
                      "${config.system.build.uki}/${config.system.boot.loader.ukiFile}";
                };
                repartConfig = {
                  Type = "esp";
                  Format = "vfat";
                  SizeMinBytes = "512M";
                  Label = "boot";
                };
              };
              "root" = {
                storePaths = [ config.system.build.toplevel ];
                repartConfig = {
                  Type = "root";
                  Format = "ext4";
                  Label = "nixos";
                  Minimize = "guess";
                };
              };
            };
        };

      })
    ];
    pxeSystemScript = hostname: (pxeExecScript (mksystem pxeModules hostname));
  in
  rec {
    nixosConfigurations = mapEachHost (mksystem []);
    pxeScript = mapEachHost pxeSystemScript;
    image = mapEachHost (hostname: (mksystem imageModules hostname).config.system.build.image);

    # output a flashable raspi image
    images.pando = nixosConfigurations.pando.config.system.build.sdImage;
  };
}
