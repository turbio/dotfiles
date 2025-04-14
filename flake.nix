{
  description = "dotfiles";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-24.11";
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
    unstable.url = "github:nixos/nixpkgs/master";
    nur.url = "github:nix-community/NUR";

    home-manager = {
      url = "github:rycee/home-manager/release-24.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    github-copilot-vim = {
      flake = false;
      url = "github:github/copilot.vim";
    };
    openscad-vim = {
      flake = false;
      url = "github:sirtaj/vim-openscad";
    };
    muble-vim = {
      flake = false;
      url = "github:turbio/muble.vim";
    };
    lsp-lines-nvim = {
      flake = false;
      url = "git+https://git.sr.ht/~whynothugo/lsp_lines.nvim";
    };
    llm-nvim = {
      flake = false;
      url = "github:melbaldove/llm.nvim";
    };

    zsh-syntax-highlighting = {
      flake = false;
      url = "github:zsh-users/zsh-syntax-highlighting";
    };
    zsh-history-substring-search = {
      flake = false;
      url = "github:zsh-users/zsh-history-substring-search";
    };

    livewallpaper = {
      flake = false;
      url = "github:turbio/live_wallpaper/nixfix";
    };
    evaldb = {
      flake = false;
      url = "github:turbio/evaldb";
    };
    schemeclub = {
      flake = false;
      url = "github:turbio/schemeclub/nix";
    };
    flippyflops = {
      flake = false;
      url = "github:turbio/flippyflops";
    };

    raspberry-pi-nix.url = "github:tstat/raspberry-pi-nix";

    nil-ls = {
      url = "github:oxalica/nil";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      home-manager,
      nixos-hardware,
      unstable,
      nur,
      ...
    }@inputs:
    let
      arch = hostname: if hostname == "pando" then "aarch64-linux" else "x86_64-linux";
      mksystem =
        modules: hostname:
        nixpkgs.lib.nixosSystem {
          system = arch hostname;
          modules =
            [
              ./configuration.nix
              ./desktop.nix
              ./home.nix
              ./system_vim.nix
              ./services/syncthing.nix
              (./hosts + "/${hostname}" + /configuration.nix)
              (./hosts + "/${hostname}" + /hardware-configuration.nix)
              ./cachix.nix
              ./vpn.nix
              nur.modules.nixos.default
              home-manager.nixosModules.home-manager
            ]
            ++ modules
            ++ (if hostname == "gero" then [ nixos-hardware.nixosModules.framework-13-7040-amd ] else [ ])
            ++ [
              (
                { pkgs, ... }:
                {
                  nixpkgs.overlays = [
                    (final: prev: {
                      # TODO(turbio): until nil has a release including pipe-operators
                      # (https://github.com/oxalica/nil/commit/52304da8e9748feff559ec90cb1f4873eda5cee1)
                      nil = inputs.nil-ls.outputs.packages.x86_64-linux.nil;
                      saleae-logic-2 = pkgs.callPackage ./packages/saleae-logic-2.nix { };
                    })
                  ];
                }
              )
            ];

          specialArgs = {
            inherit hostname;
            unstablepkgs = unstable.legacyPackages.${arch hostname};
            assignments = import ./assignments.nix;

            repos = inputs;
          };
        };

      pxeExecScript =
        system:
        nixpkgs.legacyPackages.x86_64-linux.writers.writeBash "pixiecore" ''
          exec ${nixpkgs.legacyPackages.x86_64-linux.pixiecore}/bin/pixiecore \
            boot ${system.config.system.build.kernel}/bzImage ${system.config.system.build.netbootRamdisk}/initrd \
            --cmdline "init=${system.config.system.build.toplevel} loglevel=4"
            --debug --dhcp-no-bind \
            --port 64172 --status-port 64172 "$@"
        '';
      pxeModules = [
        (
          { modulesPath, ... }:
          {
            imports = [
              (modulesPath + "/installer/netboot/netboot-minimal.nix")
            ];
          }
        )
      ];
      imageModules = [
        (
          {
            config,
            lib,
            pkgs,
            modulesPath,
            ...
          }:
          {

            imports = [ "${modulesPath}/image/repart.nix" ];

            boot.loader.grub.enable = false;

            image.repart.name = "image";
            image.repart.partitions = {
              "10-esp" = {
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
              "20-store" = {
                storePaths = [ config.system.build.toplevel ];
                stripNixStorePrefix = true;
                repartConfig = {
                  Type = "linux-generic";
                  Format = "ext4";
                  Label = "nix-store";
                  Minimize = "guess";
                };
              };
            };

          }
        )
      ];

      mapEachHost =
        fn:
        builtins.readDir ./hosts
        |> builtins.attrNames
        |> map (c: {
          name = c;
          value = fn c;
        })
        |> builtins.listToAttrs;
    in
    rec {
      nixosConfigurations = mapEachHost <| mksystem [ ];

      netbootableConfigurations = mapEachHost <| mksystem [ ./modules/netbootable.nix ];

      nixosModules.wg-vpn = import ./modules/wg-vpn.nix;

      # Spits out the kernel and initrd for pxe booting a host.
      netbootableSystems = mapEachHost (
        h:
        nixpkgs.legacyPackages.x86_64-linux.linkFarm "netbootable-${h}" {
          bzImage = "${(mksystem [ ./modules/netbootable.nix ] h).config.system.build.netbootKernel}/bzImage";
          initrd = "${(mksystem [ ./modules/netbootable.nix ] h).config.system.build.netbootRamdisk}/initrd";
          cmdline = (
            nixpkgs.legacyPackages.x86_64-linux.writeText "cmdline"
              (mksystem [ ./netbootable.nix ] h).config.system.build.netbootCmdline
          );

          "squashfs.img" = (mksystem [ ./netbootable.nix ] h).config.system.build.squashfsStore;

          "${h}-store" = (mksystem [ ./netbootable.nix ] h).config.system.build.ext4Store;
        }
      );

      netbootInitrd = mapEachHost (
        h:
        (nixpkgs.legacyPackages.x86_64-linux.writeText "cmdline"
          (mksystem [ ./netbootable.nix ] h).config.system.build.netbootCmdline
        )
      );

      image = mapEachHost (h: (mksystem imageModules h).config.system.build.image);

      activate-uki.ballos =
        let
          system = (mksystem imageModules "ballos");
          pkgs = system.pkgs;
          config = system.config;
        in
        nixpkgs.legacyPackages.x86_64-linux.writeScript "activate-uki" ''
          cp ${pkgs.systemd}/lib/systemd/boot/efi/systemd-boot${pkgs.stdenv.hostPlatform.efiArch}.efi \
            /boot/EFI/BOOT/BOOT${system.lib.toUpper pkgs.stdenv.hostPlatform.efiArch}.EFI
          cp ${config.system.build.uki}/${config.system.boot.loader.ukiFile} \
            /boot/EFI/Linux/${config.system.boot.loader.ukiFile}
        '';

      pxeScript = mapEachHost (h: mksystem pxeModules h |> pxeExecScript);

      # output a flashable raspi image
      images.pando = nixosConfigurations.pando.config.system.build.sdImage;

      formatter.x86_64-linux = nixpkgs.legacyPackages.x86_64-linux.nixfmt-rfc-style;
    };
}
