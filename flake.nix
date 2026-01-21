{
  description = "dotfiles";

  nixConfig = {
    abort-on-warn = true;
    extra-experimental-features = [ "pipe-operators" ];
  };

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.11";
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
    nixvim.url = "github:nix-community/nixvim/nixos-25.11";
    nixvim.inputs.nixpkgs.follows = "nixpkgs";
    home-manager.url = "github:rycee/home-manager/release-25.11";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    nix-index-database.url = "github:nix-community/nix-index-database";
    nix-index-database.inputs.nixpkgs.follows = "nixpkgs";

    microvm = {
      url = "github:microvm-nix/microvm.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    github-copilot-vim = {
      flake = false;
      url = "github:github/copilot.vim";
    };
    muble-vim = {
      flake = false;
      url = "github:turbio/muble.vim";
    };
    lsp-lines-nvim = {
      flake = false;
      url = "git+https://git.sr.ht/~whynothugo/lsp_lines.nvim";
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
    wrappers.url = "github:turbio/wrappers";

    raspberry-pi-nix.url = "github:tstat/raspberry-pi-nix";
    raspberry-pi-nix.inputs.nixpkgs.follows = "nixpkgs";

    disko = {
      url = "github:nix-community/disko/latest";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    agenix.url = "github:ryantm/agenix";
    agenix.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    {
      nixpkgs,
      home-manager,
      nixos-hardware,
      disko,
      nixvim,
      wrappers,
      agenix,
      nix-index-database,
      ...
    }@inputs:
    let
      arch =
        hostname:
        if (hostname == "jenka" || hostname == "backle" || hostname == "cackle") then
          "aarch64-linux"
        else
          "x86_64-linux";

      lib = nixpkgs.lib;

      wrappersOverlay =
        final: prev:
        import ./wrappers.nix {
          inherit lib;
          pkgs = final;
        }
        |> (nixpkgs.lib.mapAttrs (
          name: config:
          wrappers.wrapperModules.${name}.apply {
            config = {
              pkgs = prev;
            }
            // config;
          }
          |> (a: a.wrapper)
        ));

      mksystem =
        extraModules: hostname:
        nixpkgs.lib.nixosSystem {
          system = arch hostname;
          modules =
            lib.optional (hostname == "ballos") {
              age.secrets."rfc2136-acme".file = ./secrets/rfc2136-acme.age;
              age.secrets."rfc2136-acme".owner = "acme";
            }
            ++ lib.optional (hostname == "aackle" || hostname == "backle") {
              age.secrets."rfc2136-acme".file = ./secrets/rfc2136-acme.age;
              age.secrets."rfc2136-acme".owner = "named";

              age.secrets."rfc2136-xfer".file = ./secrets/rfc2136-xfer.age;
              age.secrets."rfc2136-xfer".owner = "named";
            }
            ++ [
              nix-index-database.nixosModules.default
              agenix.nixosModules.default
              {
                age.secrets.userpassword.file = ./secrets/userpassword.age;
              }
              #./modules/wg-vpn.nix
              ./configuration.nix
              ./desktop.nix
              ./home.nix
              ./services/syncthing.nix
              (./hosts + "/${hostname}" + /configuration.nix)
              (./hosts + "/${hostname}" + /hardware-configuration.nix)
              #./vpn.nix
              disko.nixosModules.disko
              home-manager.nixosModules.home-manager
              nixvim.nixosModules.nixvim
              {
                nixpkgs.overlays = [
                  wrappersOverlay
                ];
              }
            ]
            ++ (lib.optional (hostname != "balrog" && hostname != "backle" && hostname != "aackle") ./vim.nix)
            ++ extraModules
            ++ (lib.optional (hostname == "gero") nixos-hardware.nixosModules.framework-13-7040-amd)
            ++ (lib.optional (hostname == "mote") {
              nixpkgs.config.contentAddressedByDefault = true;
            });

          specialArgs = {
            inherit hostname;
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

      mapEachHost =
        fn:
        builtins.readDir ./hosts
        |> builtins.attrNames
        |> map (c: {
          name = c;
          value = fn c;
        })
        |> builtins.listToAttrs;

      suffix =
        fix: attrs:
        nixpkgs.lib.attrsets.mapAttrs' (n: v: {
          name = "${n}-${fix}";
          value = v;
        }) attrs;
    in
    rec {
      overlays.default = wrappersOverlay;

      nixosConfigurations = mapEachHost <| mksystem [ ];

      nixosModules.wg-vpn = import ./modules/wg-vpn.nix;

      netbootableConfigurations = mapEachHost <| mksystem [ ./modules/netbootable_nfs.nix ];

      # Spits out the kernel and initrd for pxe booting a host.
      netbootableSystems = mapEachHost (
        h:
        let
          output = netbootableConfigurations.${h}.config.system.build;
        in
        nixpkgs.legacyPackages.x86_64-linux.linkFarm "netbootable-${h}" {
          bzImage = "${output.netbootKernel}/bzImage";
          initrd = "${output.netbootRamdisk}/initrd";
          cmdline = (nixpkgs.legacyPackages.x86_64-linux.writeText "cmdline" output.netbootCmdline);
          "nix-store.squashfs" = output.squashfsStore;
        }
      );

      # Just the initrd (no squashfs) for quick iteration on boot scripts
      netbootableInitrds = mapEachHost (
        h:
        let
          output = netbootableConfigurations.${h}.config.system.build;
        in
        nixpkgs.legacyPackages.x86_64-linux.linkFarm "netbootable-initrd-${h}" {
          bzImage = "${output.netbootKernel}/bzImage";
          initrd = "${output.netbootRamdisk}/initrd";
          cmdline = (nixpkgs.legacyPackages.x86_64-linux.writeText "cmdline" output.netbootCmdline);
        }
      );

      # nix run 'github:nix-community/disko/latest#disko-install' -- --write-efi-boot-entries --flake '.#<host>' --disk main /dev/<disk>
      packages.x86_64-linux =
        (
          mapEachHost (mksystem [
            (
              { ... }:
              {
                disko.devices.disk.main.imageSize = "60G"; # should be enough right
              }
            )
          ])
          |> nixpkgs.lib.filterAttrs (n: sys: n == "curly")
          |> nixpkgs.lib.filterAttrs (n: sys: sys.config.disko.devices.disk != { })
          |> nixpkgs.lib.mapAttrs (n: sys: sys.config.system.build.diskoImagesScript)
          |> suffix "disko-image-script"
        )
        // (wrappersOverlay nixpkgs.legacyPackages.x86_64-linux nixpkgs.legacyPackages.x86_64-linux)
        // {
          devvm = import ./devvm.nix {
            inherit mksystem;
            inherit lib;
            inherit (inputs) microvm;
            pkgs = import nixpkgs { system = "x86_64-linux"; };
          };

          vim =
            let
              pkgs = import nixpkgs {
                system = "x86_64-linux";
                config.allowUnfree = true;
              };
            in
            nixvim.legacyPackages.x86_64-linux.makeNixvimWithModule {
              inherit pkgs;
              module = import ./vimconfig.nix {
                inherit pkgs;
                repos = inputs;
                isDesktop = false;
              };
            };
        };

      # activate-uki.ballos =
      #   let
      #     system = (mksystem repartImageModule "ballos");
      #     pkgs = system.pkgs;
      #     config = system.config;
      #   in
      #   nixpkgs.legacyPackages.x86_64-linux.writeScript "activate-uki" ''
      #     cp ${pkgs.systemd}/lib/systemd/boot/efi/systemd-boot${pkgs.stdenv.hostPlatform.efiArch}.efi \
      #       /boot/EFI/BOOT/BOOT${system.lib.toUpper pkgs.stdenv.hostPlatform.efiArch}.EFI
      #     cp ${config.system.build.uki}/${config.system.boot.loader.ukiFile} \
      #       /boot/EFI/Linux/${config.system.boot.loader.ukiFile}
      #   '';

      pxeScript = mapEachHost (h: mksystem pxeModules h |> pxeExecScript);

      formatter.x86_64-linux = nixpkgs.legacyPackages.x86_64-linux.nixfmt-rfc-style;
    };
}
