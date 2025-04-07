# TODO: doesn't actually work
#
# tryna to get a netbootable system with a systemd initrd
#
# pxe boot a system with mutable storage mounted over nbd.
#
# You'd think you could just nbd mount your root fs in initrd and switch_root
# right into it. lol. nope. nixos networking in stage1 can't be done
# uninterrupted with a systemd-ed initrd (yet). Haven't found
# a straight forward way to boot all the way up without interrupting the network
# connection. Soon as you do that it's all over: any boot progress touching disk
# needs network which needs boot progress... etc.
#
# but also we can't just throw our entire nix store into the initrd.
# - initrd must be under 4G (cpio and kernel limit?)
# - the nixos store for desktop systems can easily pass the limit
# - it sits entirely in memory for at least part of the boot....  that's a lot
#   of ram for my old thinkpad.
#
# so:
# initrd gets us into a minimal memory backed nixos system (it's like an initrd
# 2.0) with most of the userland setup. Then we actually mount the nbd over
# mutable storage and activate the real system.
let
	switchConfig = { config, pkgs, lib, modulesPath, ... }: {
		users.mutableUsers = false;
		security.sudo.wheelNeedsPassword = false;
		users.users.turbio = {
			home = "/home/turbio";
			isNormalUser = true;
			extraGroups = [ "wheel" ];
			uid = 1000;

			# probably a bad idea lmao
			hashedPassword = "$6$UnnB5IybU$cBw9zHoM7xTdwyXnAAbeXOGoqQQtzbYsuPqTDjpGF3J3H3WaarzAEtoBxXOImZlmmzY2amSqSgwUbEP0.ma3w0";

			openssh.authorizedKeys.keys = [
				"ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIONmQgB3t8sb7r+LJ/HeaAY9Nz2aPS1XszXTub8A1y4n turbio"
			];
		};

		boot.initrd.network = {
			enable = true;
			flushBeforeStage2 = false;
			#udhcpc.enable = true;
		};

		#inherit config;
		#modulesPath = "${modulesPath}/installer/netboot/netboot-minimal.nix";
		boot.loader.grub.enable = false;
		networking.hostName = "netboot-preswitch";

		system.build.initrdSquashfs = pkgs.makeInitrdNG {
			inherit (config.boot.initrd) compressor;
			prepend = [ "${config.system.build.initialRamdisk}/initrd" ];
		
			contents = [
				{
					source = config.system.build.squashfsStore;
					target = "/nix-store.squashfs";
				}
			];
		};

		system.build.squashfsStore = pkgs.callPackage "${modulesPath}/../lib/make-squashfs.nix" {
			storeContents = [  config.system.build.toplevel ];
			comp = "zstd -Xcompression-level 19";
		};

		boot.initrd.availableKernelModules = [ "loop" "squashfs" "overlay" ];

		#boot.initrd.systemd = {
		#	emergencyAccess = true;
		#	enable = true;
		#};

		systemd.enableEmergencyMode = true;
		boot.initrd.systemd.emergencyAccess = true;

		programs.nbd.enable = true;

		networking.networkmanager.enable = true;

		boot.initrd.systemd = {
			enable = true;
		};


		#boot.initrd.availableKernelModules = [
		#	"e1000e"
		#	"ixgbe"
		#	"nbd"
		#	"ext4"
		#	"btrfs"
		#	"loop"
		#	"squashfs"
		#	"overlay"
		#	"af_packet"
		#];

		systemd.services.nbd-client = {
			enable = true;

			#before = [ "initrd-switch-root.target" "sysroot.mount" ];
			#wantedBy = [ "initrd.target" "sysinit.target" ];
			#requiredBy = [ "initrd.target" "sysinit.target" "sysroot.mount" ];
			#requiredBy = [ "sysroot.mount" ];
			#after = [ "network-online.target" "network.target" "NetworkManager-wait-online.service" ];
			#after = [ "systemd-networkd-wait-online.service" ];

			#partOf = [ "nbd.service" ];
			wants = [ "network-online.target" ];
			after = [ "network-online.target" ];

			requiredBy = [ "persist.mount" ];
			before = [ "persist.mount" ];

			serviceConfig = {
				StandardOutput = "tty";
				Type = "oneshot";
				RemainAfterExit = true;
				RestartSec = 1;
				Restart = "on-failure";
			};

			script = ''
				#host=ballos.lan
				host=192.168.86.113
				${pkgs.nbd}/bin/nbd-client -persist -timeout 3 -b 2048 -N star-root $host /dev/nbd0
			'';

			preStop = ''
				${pkgs.nbd}/bin/nbd-client -d /dev/nbd0
			'';
		};

		systemd.mounts = [
			{
				where = "/persist";
				what = "/dev/nbd0";
				requires = [ "nbd-client.service" ];
				after = [ "nbd-client.service" ];
				wantedBy = [ "remote-fs.target" ];
			}
		];

		fileSystems = {
			"/" = {
				neededForBoot = true;
				fsType = "tmpfs";
				options = [ "mode=0755" ];
			};

			"/nix/.ro-store" = {
				neededForBoot = true;
				fsType = "squashfs";
				device = "../nix-store.squashfs";
				options = [ "loop" "threads=multi" ];
			};

			"/nix/.rw-store" = {
				neededForBoot = true;
				fsType = "tmpfs";
				options = [ "mode=0755" ];
			};

			"/nix/store" = {
				neededForBoot = true;
				overlay = {
					upperdir = "/nix/.rw-store/store";
					lowerdir = [ "/nix/.ro-store" ];
					workdir = "/nix/.rw-store/work";
				};
			};
		};

		boot.kernelParams = [ "systemd.debug-shell=1" "systemd.log_level=debug" ];

		system.stateVersion = "21.05";
	};
	switchSys = lib.nixosSystem {
		system = "x86_64-linux";
		modules = [ switchConfig ];
	};

	# system.build.netbootKernel = switchSys.config.system.build.kernel;
	# system.build.netbootRamdisk = switchSys.config.system.build.initrdSquashfs;
	# system.build.netbootCmdline = toString (
	# 	[ "init=${switchSys.config.system.build.toplevel}/init" ]
	# 	++ switchSys.config.boot.kernelParams
	# );
in
