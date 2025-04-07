# adds netboot-ability to a nixos configuration providing:
#
# system.build.netbootKernel  - netbootable kernel
# system.build.netbootRamdisk - initrd that knows how to boot into a full system
#                               over the networking using kernel cmdline
# system.build.netbootCmdline - a default cmdline telling the initrd how to boot
#                               into the system.
#
# also:
# system.build.ext4Store - a disk image of the nixos system store, expected as
#                          the contents of the nbd store export
#
# kernel cmdline opts for initrd:
# - netboot.nbd_server=<nbd server address>
# - netboot.nbd_store_name=<nbd export for nix store>
# - netboot.nbd_persist_name=<nbd export for system persistence>
#
# TODO: - has a tricky binding between the initrd image and the target system
#         config. A netboot initrd isn't interchangeable between systems in
#         some(???> cases.
#       - discovery of nixos closure root(s) `init=` fallback and/or version
#         selection
#       - squashfs backed store
#
{ config, lib, pkgs, modulesPath, hostname, ... }: {
	boot.loader.grub.enable = false;
	programs.nbd.enable = true;

	boot.initrd.availableKernelModules = [
		"e1000e"
		"ixgbe"
		"nbd"
		"ext4"
		"loop"
		"overlay"
		"af_packet"
		"autofs4"
		"autofs"
	];

	boot.initrd.kernelModules = [
		"autofs4"
		"nbd"
	];

	boot.initrd.postDeviceCommands = ''
		set -x

		# nbd params from the kernel cmdline:
		for o in $(cat /proc/cmdline); do
			case $o in
				netboot.nbd_server=*)
				nbd_server="$''+''{o#netboot.nbd_server=}"
				;;
				netboot.nbd_store_name=*)
				nbd_store_name="$''+''{o#netboot.nbd_store_name=}"
				;;
				netboot.nbd_persist_name=*)
				nbd_persist_name="$''+''{o#netboot.nbd_persist_name=}"
				;;
			esac
		done

		echo "Connecting to nbd server: $nbd_server"
		echo "Store: $nbd_store_name"
		echo "Persist: $nbd_persist_name"

		sleep 1
		lsblk

		${pkgs.nbd}/bin/nbd-client -persist -timeout 10 -block-size 2048 -connections 8 -N $nbd_store_name $nbd_server /dev/nbd0
		${pkgs.nbd}/bin/nbd-client -persist -timeout 10 -block-size 2048 -connections 8 -N $nbd_persist_name $nbd_server /dev/nbd1

		sleep 1
		lsblk

		ls -l /

		# nix won't create a --bind mount's source dir
		mkdir -p /fixup-persist
		mount /dev/nbd1 /fixup-persist
		mkdir -p /fixup-persist/home
		mkdir -p /fixup-persist/var
		umount /fixup-persist
	'';

	boot.postBootCommands = ''
		# After booting, register the contents of the Nix store
		# in the Nix database in the tmpfs.
		${config.nix.package}/bin/nix-store --load-db < /mnt/store/nix-path-registration

		# nixos-rebuild also requires a "system" profile and an
		# /etc/NIXOS tag.
		touch /etc/NIXOS
		${config.nix.package}/bin/nix-env -p /nix/var/nix/profiles/system --set /run/current-system
	'';


	boot.initrd.network = {
		enable = true;
		flushBeforeStage2 = false;
		udhcpc.enable = true;
	};

	boot.initrd.systemd.enable = false; # just to be sure

	networking.networkmanager.enable = lib.mkForce false;
	networking.dhcpcd.enable = true;
	networking.interfaces = lib.mkForce { };

	virtualisation.virtualbox.host.enable = lib.mkForce false;
	virtualisation.virtualbox.host.enableExtensionPack = lib.mkForce false;
	services.nscd.enable = lib.mkForce false;
	system.nssModules = lib.mkForce [];

	boot.resumeDevice = lib.mkImageMediaOverride "";
	swapDevices = lib.mkImageMediaOverride [ ];
	fileSystems = lib.mkImageMediaOverride {
		"/mnt/store" = lib.mkImageMediaOverride {
			neededForBoot = true;
			fsType = "ext4";
			device = "/dev/nbd0";
			autoResize = true;
		};
		"/" = lib.mkImageMediaOverride {
			neededForBoot = true;
			fsType = "tmpfs";
		};
		"/nix/store" = lib.mkImageMediaOverride {
			device = "/mnt/store/nix/store";
			options = [ "bind" ];
		};

		"/mnt/persist" = lib.mkImageMediaOverride {
			neededForBoot = true;
			device = "/dev/nbd1";
		};
		"/home" = lib.mkImageMediaOverride {
			device = "/mnt/persist/home";
			options = [ "bind" ];
		};
		"/var" = lib.mkImageMediaOverride {
			device = "/mnt/persist/var";
			options = [ "bind" ];
		};
	};

	boot.kernelParams = [
		"systemd.debug-shell=1"
		"systemd.log_level=debug"
		"nbd_server=192.168.86.113"
		"nbd_store_name=${hostname}-store"
		"nbd_persist_name=${hostname}-persist"
	];

	system.build.netbootKernel = config.system.build.kernel;
	system.build.netbootRamdisk = config.system.build.initialRamdisk;
	system.build.netbootCmdline = toString (
		[ "init=${config.system.build.toplevel}/init" ]
		++ config.boot.kernelParams
	);
	#system.build.netbootCmdline = "init=/nix/store/7hlgyyacqqxw8hxg0jq9r6mdm9spvkma-nixos-system-star-24.11.20250206.f5a32fa/init ip=dhcp systemd.debug-shell=1 systemd.log_level=debug root=fstab loglevel=4"; # systemd.unit=basic.target

	system.build.ext4Store = pkgs.callPackage "${modulesPath}/../lib/make-ext4-fs.nix" {
		storePaths = [ config.system.build.toplevel ];
		volumeLabel = "nixos";
		uuid = "44444444-4444-4444-8888-888888888888";
	};
}
