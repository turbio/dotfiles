{
  description = "dotfiles";

  nixConfig = {
    abort-on-warn = true;
    extra-experimental-features = [ "pipe-operators" ];
  };

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.11";
    unstable.url = "github:nixos/nixpkgs/nixos-unstable";
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
    nixvim.url = "github:nix-community/nixvim/nixos-25.11";
    nixvim.inputs.nixpkgs.follows = "nixpkgs";
    home-manager.url = "github:rycee/home-manager/release-25.11";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
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

    disko = {
      url = "github:nix-community/disko/latest";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      home-manager,
      nixos-hardware,
      disko,
      nixvim,
      wrappers,
      unstable,
      ...
    }@inputs:
    let
      arch =
        hostname:
        if hostname == "jenka" then
          "aarch64-linux"
        else if hostname == "zote" then
          "x86_64-linux-musl"
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

      muslOverlay = final: prev: {
        logrotate = prev.logrotate.overrideAttrs (
          finalAttrs: prevAttrs: {
            preCheck =
              prevAttrs.preCheck or ""
              + ''
                # test-0112 expects glibc's "Operation not supported" error string
                # but musl uses a different message
                sed -i '2iexit 77' test/test-0112.sh
              '';
          }
        );

        lkl = prev.lkl.overrideAttrs (
          finalAttrs: prevAttrs: {
            buildInputs = prevAttrs.buildInputs ++ [ final.argp-standalone ];
            env = prevAttrs.env or { } // {
              NIX_LDFLAGS = (prevAttrs.env.NIX_LDFLAGS or "") + " -largp";
            };
            postPatch =
              prevAttrs.postPatch or ""
              + ''
                # musl doesn't include these headers transitively like glibc does
                sed -i '1i#include <sys/types.h>' tools/lkl/include/lkl.h
                sed -i '1i#include <limits.h>' tools/lkl/cptofs.c tools/lkl/fs2tar.c tools/lkl/tests/disk.c

                # Disable glibc-specific components that don't work with musl:
                # - hijack library uses glibc's ioctl signature (unsigned long vs int)
                # - test-dlmopen uses dlmopen which is glibc-only
                sed -i '/liblkl-hijack/d; /liblkl-zpoline/d; /libhijack-priv/d; /test-dlmopen/d' tools/lkl/Targets
              '';
            # Don't try to install hijack library since we disabled building it
            installPhase = ''
              mkdir -p $out/bin $lib/lib $dev

              cp tools/lkl/bin/lkl-hijack.sh $out/bin
              sed -i $out/bin/lkl-hijack.sh \
                  -e "s,LD_LIBRARY_PATH=.*,LD_LIBRARY_PATH=$lib/lib,"

              cp tools/lkl/{cptofs,fs2tar,lklfuse} $out/bin
              ln -s cptofs $out/bin/cpfromfs
              cp -r tools/lkl/include $dev/
              cp tools/lkl/liblkl.a \
                 tools/lkl/lib/liblkl.so \
                 $lib/lib
            '';
          }
        );
      };

      mksystem =
        extraModules: hostname:
        nixpkgs.lib.nixosSystem {
          system = arch hostname;
          modules = [
            #./modules/wg-vpn.nix
            ./configuration.nix
            ./desktop.nix
            (if hostname == "zote" then { } else ./home.nix)
            ./vim.nix
            ./services/syncthing.nix
            (./hosts + "/${hostname}" + /configuration.nix)
            (./hosts + "/${hostname}" + /hardware-configuration.nix)
            ./cachix.nix
            #./vpn.nix
            disko.nixosModules.disko
            (if hostname == "zote" then { } else home-manager.nixosModules.home-manager)
            (
              if hostname == "zote" then
                { config, pkgs, ... }:
                {
                  services.udisks2.enable = false;
                  services.fwupd.enable = lib.mkForce false;
                  #i18n.supportedLocales = [ ];
                  i18n.defaultLocale = "C.UTF-8";
                  i18n.glibcLocales = pkgs.writeTextDir "path" "TODO";

                  nixpkgs.overlays = [
                    muslOverlay
                  ];
                }
              else
                { }
            )
            nixvim.nixosModules.nixvim
            {
              nixpkgs.overlays = [
                wrappersOverlay
              ];
            }
          ]
          ++ extraModules
          ++ (if hostname == "gero" then [ nixos-hardware.nixosModules.framework-13-7040-amd ] else [ ]);

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

          # "squashfs.img" = output.squashfsStore;
          # "${h}-store" = output.ext4Store;
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
          musled = import nixpkgs {
            system = "x86_64-linux-musl";
            overlays = [ muslOverlay ];
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
