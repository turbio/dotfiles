{
  description = "dotfiles";

  nixConfig = {
    abort-on-warn = true;
    extra-experimental-features = [ "pipe-operators" ];
  };

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.11";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";

    nixvim.url = "github:nix-community/nixvim/nixos-25.11";
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

    terranix.url = "github:terranix/terranix";
    terranix.inputs.nixpkgs.follows = "nixpkgs";

    microvm.url = "github:microvm-nix/microvm.nix";
    microvm.inputs.nixpkgs.follows = "nixpkgs";

    buildbot-nix.url = "github:nix-community/buildbot-nix";
    buildbot-nix.inputs.nixpkgs.follows = "nixpkgs-unstable";
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
            ];
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

      applianceConfig = inputs.terranix.lib.terranixConfiguration {
        system = "x86_64-linux";
        modules = [
          ./appliances/common.nix
          ./appliances/root.nix
        ];
      };

      # tofu with the routeros plugin from nixpkgs-unstable (25.11 has 1.92,
      # we want 1.99.x) — no registry access needed anywhere.
      # carries a local fix until it lands upstream: RouterOS REST returns
      # blackhole as a presence-flag ("blackhole": "" when set, absent when
      # not); without SetUnset handling the provider parses that as false on
      # every read, permadiffing blackhole routes.
      applianceTofu =
        let
          pkgs = inputs.nixpkgs-unstable.legacyPackages.x86_64-linux;
          routeros = pkgs.terraform-providers.terraform-routeros_routeros.overrideAttrs (old: {
            postPatch = (old.postPatch or "") + ''
              for f in routeros/resource_ip_route.go routeros/resource_ipv6_route.go; do
                substituteInPlace "$f" --replace-fail \
                  'MetaId:           PropId(Id),' \
                  'MetaId:             PropId(Id),
                   MetaSetUnsetFields: PropSetUnsetFields("blackhole"),'
              done
            '';
          });
        in
        pkgs.opentofu.withPlugins (_: [ routeros ]);

      # `nix run .#appliance -- <tofu args...>`: drops the freshly built
      # config.tf.json into appliances/root/ (state+lock live there,
      # committed) and runs tofu with the nix-provided routeros plugin —
      # init works offline, no registry access
      applianceApp =
        let
          pkgs = nixpkgs.legacyPackages.x86_64-linux;
          tofu = applianceTofu;
        in
        {
          type = "app";
          program = toString (
            pkgs.writeShellScript "appliance" ''
              set -euo pipefail
              dir="$(${pkgs.git}/bin/git rev-parse --show-toplevel)/appliances/root"
              mkdir -p "$dir"
              install -m 644 ${applianceConfig} "$dir/config.tf.json"
              cd "$dir"
              exec ${tofu}/bin/tofu "$@"
            ''
          );
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

      apps.x86_64-linux.appliance = applianceApp;

      netbootableConfigurations = mapEachHost <| mksystem [ ./modules/netbootable_scratch.nix ];

      netbootableSystems = mapEachHost (
        h: self.netbootableConfigurations.${h}.config.system.build.netbootSystem
      );

      # nix run 'github:nix-community/disko/latest#disko-install' -- --write-efi-boot-entries --flake '.#<host>' --disk main /dev/<disk>
      packages.x86_64-linux =
        { }
        // (wrappersOverlay nixpkgs.legacyPackages.x86_64-linux nixpkgs.legacyPackages.x86_64-linux)
        // {
          appliance-config = applianceConfig;
        }
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

      formatter.x86_64-linux = nixpkgs.legacyPackages.x86_64-linux.nixfmt-rfc-style;
    };
}
