{
  description = "dotfiles";

  nixConfig = {
    #abort-on-warn = true;
    extra-experimental-features = [ "pipe-operators" ];
  };

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    nix.url = "github:turbio/nix/master";
    # TODO(turbio): can't follow, unstable Boost breaks URL tests

    nixvim.url = "github:nix-community/nixvim/main";
    nixvim.inputs.nixpkgs.follows = "nixpkgs";

    nix-index-database.url = "github:nix-community/nix-index-database";
    nix-index-database.inputs.nixpkgs.follows = "nixpkgs";

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
    flippyflops.url = "github:turbio/flippyflops?dir=dots.turb.io";
    # TODO(turbio): mkYarnPackage is gone from unstable, park flippyflops on 25.11 until its build is ported to the yarn hooks
    nixpkgs-flippyflops.url = "github:nixos/nixpkgs/nixos-25.11";
    flippyflops.inputs.nixpkgs.follows = "nixpkgs-flippyflops";
    wrappers.url = "github:lassulus/wrappers";
    wrappers.inputs.nixpkgs.follows = "nixpkgs";

    raspberry-pi-nix.url = "github:tstat/raspberry-pi-nix";
    raspberry-pi-nix.inputs.nixpkgs.follows = "nixpkgs";

    disko = {
      url = "github:nix-community/disko/latest";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    agenix.url = "github:ryantm/agenix";
    agenix.inputs.nixpkgs.follows = "nixpkgs";

    terranix.url = "github:terranix/terranix";
    terranix.inputs.nixpkgs.follows = "nixpkgs";

    microvm.url = "github:microvm-nix/microvm.nix";
    microvm.inputs.nixpkgs.follows = "nixpkgs";

    buildbot-nix.url = "github:nix-community/buildbot-nix";
    buildbot-nix.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    {
      self,
      nixpkgs,
      disko,
      nixvim,
      wrappers,
      agenix,
      nix-index-database,
      ...
    }@inputs:
    let
      lib = nixpkgs.lib;

      # inventory.nix is data only; lib/inventory.nix derives the addresses,
      # checks and helpers from it
      inventory = import ./lib/inventory.nix;

      # local copy of git+https://git.turb.io/vmshell while both sides are
      # being iterated on together; push it back upstream once it settles
      vmshell = import ./vmshell {
        inherit nixpkgs;
        microvm = inputs.microvm;
      };

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

      secretsModuleFor =
        hostname:
        (inventory.machines.${hostname}.secrets or [ ])
        |> lib.map (s: {
          age.secrets.${s}.file = ./secrets/${s}.age;
        });

      hostModulesList =
        extraModules: hostname:
        [
          nix-index-database.nixosModules.default
          agenix.nixosModules.default
          #./modules/wg-vpn.nix
          ./modules/vm-host.nix
          ./modules/vm-routes.nix
          ./modules/int-dns.nix
          ./configuration.nix
          ./desktop.nix
          ./home.nix
          ./services/syncthing.nix
          ./vim.nix
          (./hosts + "/${hostname}" + /configuration.nix)
          (./hosts + "/${hostname}" + /hardware-configuration.nix)
          #./vpn.nix
          disko.nixosModules.disko
          nixvim.nixosModules.nixvim
          {
            nixpkgs.overlays = [
              wrappersOverlay
              #inputs.nix.overlays.default
              (final: prev: {
                flippyflops = inputs.flippyflops.packages.${inventory.machines.${hostname}.arch}.flippyflops;
              })
            ];

            nix.package = inputs.nix.packages.x86_64-linux.nix;
          }
        ]
        ++ (secretsModuleFor hostname)
        ++ extraModules;

      hostSpecialArgs = hostname: {
        inherit hostname;
        assignments = import ./assignments.nix;
        inherit inventory;
        microvm = inputs.microvm;
        repos = inputs;
      };

      mksystem =
        extraModules: hostname:
        nixpkgs.lib.nixosSystem {
          system = inventory.machines.${hostname}.arch;
          modules = hostModulesList extraModules hostname;
          specialArgs = hostSpecialArgs hostname;
        };

      # `nix run .#appliance`
      appliances = import ./appliances {
        pkgs = inputs.nixpkgs.legacyPackages.x86_64-linux;
        inherit (inputs) terranix;
      };

      mapEachHost =
        fn:
        builtins.readDir ./hosts
        |> builtins.attrNames
        # hosts/vm is an empty placeholder; the bare nixosConfiguration
        # would fail eval for lack of a root fs, so skip it here.
        |> builtins.filter (c: c != "vm")
        |> map (c: {
          name = c;
          value = fn c;
        })
        |> builtins.listToAttrs;
    in
    {
      overlays.default = wrappersOverlay;

      nixosConfigurations = (mapEachHost <| mksystem [ ]) // {
        joast = mksystem [ { _module.args.netbootImages = self.netbootImages; } ] "joast";
      };

      nixosModules.wg-vpn = import ./modules/wg-vpn.nix;

      apps.x86_64-linux.appliance = appliances.app;

      netbootableConfigurations = mapEachHost <| mksystem [ ./modules/netbootable_scratch.nix ];

      netbootableSystems = mapEachHost (
        h: self.netbootableConfigurations.${h}.config.system.build.netbootSystem
      );

      # nix run 'github:nix-community/disko/latest#disko-install' -- --write-efi-boot-entries --flake '.#<host>' --disk main /dev/<disk>
      packages.x86_64-linux = {
        devvm = vmshell.lib.mkVMPackage {
          vm = {
            hostPlatform = "x86_64-linux";
            user = "turbio";
            modules = [
              {
                _module.args = {
                  hostname = "devvm";
                  repos = inputs;
                };
              }
              {
                # fresh home every boot: an empty ~/.zshrc keeps
                # zsh-newuser-install from eating the first keystroke
                systemd.tmpfiles.rules = [ "f /home/turbio/.zshrc 0644 turbio users -" ];
              }
              ./configuration.nix
              nix-index-database.nixosModules.default
              ./desktop.nix
              ./home.nix
              ./vim.nix
              nixvim.nixosModules.nixvim
              {
                nixpkgs.overlays = [
                  wrappersOverlay
                ];
              }
            ];
          };
        };
      }
      // (wrappersOverlay nixpkgs.legacyPackages.x86_64-linux nixpkgs.legacyPackages.x86_64-linux)
      // appliances.packages
      // {
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
          allHosts = builtins.attrNames self.netbootableConfigurations;
          pairs = builtins.concatMap (
            hostname:
            let
              cfg = self.netbootableConfigurations.${hostname};
              macs = cfg.config.netboot.macAddresses;
              system = self.netbootableSystems.${hostname};
            in
            map (mac: {
              name = mac;
              path = system;
            }) macs
          ) allHosts;
        in
        pkgs.linkFarm "netboot-images" pairs;

      # ci (buildbot) builds the checks tree. host toplevels are the real
      # signal: each embeds the host's full closure, and the hypervisors'
      # toplevels embed every vm they place — so "joast builds" covers the
      # whole vm fleet. split by arch so each attr lands on a worker that
      # can actually build it.
      checks =
        let
          toplevels = lib.mapAttrs' (
            name: cfg: lib.nameValuePair "host-${name}" cfg.config.system.build.toplevel
          );
          hostsBy =
            system:
            lib.filterAttrs (name: _: inventory.machines.${name}.arch == system) self.nixosConfigurations;
        in
        {
          x86_64-linux = toplevels (hostsBy "x86_64-linux") // {
            joast-boot = import ./tests/joast-boot.nix {
              pkgs = nixpkgs.legacyPackages.x86_64-linux;
              joast = self.nixosConfigurations.joast;
            };
          };
          aarch64-linux = toplevels (hostsBy "aarch64-linux");
        };

      formatter.x86_64-linux = nixpkgs.legacyPackages.x86_64-linux.nixfmt-rfc-style;
    };
}
