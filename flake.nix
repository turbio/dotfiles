{
  description = "dotfiles";

  nixConfig = {
    abort-on-warn = true;
    extra-experimental-features = [ "pipe-operators" ];
  };

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.11";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";
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
    wrappers.inputs.nixpkgs.follows = "nixpkgs";

    raspberry-pi-nix.url = "github:tstat/raspberry-pi-nix";
    raspberry-pi-nix.inputs.nixpkgs.follows = "nixpkgs";

    disko = {
      url = "github:nix-community/disko/latest";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    agenix.url = "github:ryantm/agenix";
    agenix.inputs.nixpkgs.follows = "nixpkgs";

    redex.url = "git+https://git.turb.io/redex";
    redex.inputs.nixpkgs.follows = "nixpkgs";

    buildbot-nix.url = "github:nix-community/buildbot-nix";
    buildbot-nix.inputs.nixpkgs.follows = "nixpkgs-unstable";
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
      redex,
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

      hostModulesList =
        extraModules: hostname:
        lib.optional (hostname == "ballos") redex.nixosModules.default
        ++ lib.optional (hostname == "ballos") inputs.buildbot-nix.nixosModules.buildbot-master
        ++ lib.optional (hostname == "ballos") inputs.buildbot-nix.nixosModules.buildbot-worker
        ++ lib.optional (hostname == "ballos") {
          age.secrets."rfc2136-acme".file = ./secrets/rfc2136-acme.age;
          age.secrets."rfc2136-acme".owner = "acme";

          age.secrets."forgejo-oauth-secret".file = ./secrets/forgejo-oauth-secret.age;
          age.secrets."forgejo-webhook-secret".file = ./secrets/forgejo-webhook-secret.age;
        }
        ++ lib.optional (hostname == "aackle" || hostname == "backle") {
          age.secrets."rfc2136-acme".file = ./secrets/rfc2136-acme.age;
          age.secrets."rfc2136-acme".owner = "named";

          age.secrets."rfc2136-xfer".file = ./secrets/rfc2136-xfer.age;
          age.secrets."rfc2136-xfer".owner = "named";
        }

        ++ lib.optional (hostname != "zote" && hostname != "j1" && hostname != "j2") {
          age.secrets.userpassword.file = ./secrets/userpassword.age;
        }
        ++ [
          nix-index-database.nixosModules.default
          agenix.nixosModules.default
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
          #nixpkgs.config.contentAddressedByDefault = true;
        });

      hostSpecialArgs = hostname: {
        inherit hostname;
        assignments = import ./assignments.nix;
        repos = inputs;
      };

      mksystem =
        extraModules: hostname:
        nixpkgs.lib.nixosSystem {
          system = arch hostname;
          modules = hostModulesList extraModules hostname;
          specialArgs = hostSpecialArgs hostname;
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
        # hosts/vm is a placeholder filled in by devvm.nix (it pulls in the
        # microvm module + actual config); the bare nixosConfiguration would
        # fail eval for lack of a root fs, so skip it here.
        |> builtins.filter (c: c != "vm")
        |> map (c: {
          name = c;
          value = fn c;
        })
        |> builtins.listToAttrs;
    in
    rec {
      overlays.default = wrappersOverlay;

      nixosConfigurations = (mapEachHost <| mksystem [ ]) // {
        ballos = mksystem [ { _module.args.netbootImages = netbootImages; } ] "ballos";
      };

      nixosModules.wg-vpn = import ./modules/wg-vpn.nix;

      netbootableConfigurations = mapEachHost <| mksystem [ ./modules/netbootable_scratch.nix ];

      netbootableSystems = mapEachHost (
        h: netbootableConfigurations.${h}.config.system.build.netbootSystem
      );

      # nix run 'github:nix-community/disko/latest#disko-install' -- --write-efi-boot-entries --flake '.#<host>' --disk main /dev/<disk>
      packages.x86_64-linux =
        { }
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

      netbootImages =
        let
          pkgs = nixpkgs.legacyPackages.x86_64-linux;
          allHosts = builtins.attrNames netbootableConfigurations;
          pairs = builtins.concatMap (
            hostname:
            let
              cfg = netbootableConfigurations.${hostname};
              macs = cfg.config.netboot.macAddresses;
              system = netbootableSystems.${hostname};
            in
            map (mac: {
              name = mac;
              path = system;
            }) macs
          ) allHosts;
        in
        pkgs.linkFarm "netboot-images" pairs;

      pxeScript = mapEachHost (h: mksystem pxeModules h |> pxeExecScript);

      devShells.x86_64-linux.infra =
        let
          pkgs = nixpkgs.legacyPackages.x86_64-linux;
        in
        pkgs.mkShell {
          packages = [
            pkgs.google-cloud-sdk
            pkgs.oci-cli
            pkgs.opentofu
          ];
          shellHook = ''
            echo "Infrastructure shell - gcloud, oci, tofu available"
          '';
        };

      checks =
        let
          hostsBy = system: lib.filterAttrs (name: _: arch name == system) nixosConfigurations;
          toplevels = lib.mapAttrs (_: cfg: cfg.config.system.build.toplevel);
        in
        {
          x86_64-linux = toplevels (hostsBy "x86_64-linux") // {
            ballos-vm = import ./tests/ballos-vm.nix {
              pkgs = nixpkgs.legacyPackages.x86_64-linux;
              hostModulesList =
                extraModules: hostname:
                hostModulesList extraModules hostname
                ++ lib.optional (hostname == "ballos") {
                  _module.args.netbootImages = netbootImages;
                };
              inherit hostSpecialArgs;
            };
          };
          aarch64-linux = toplevels (hostsBy "aarch64-linux");
        };

      formatter.x86_64-linux = nixpkgs.legacyPackages.x86_64-linux.nixfmt-rfc-style;
    };
}
