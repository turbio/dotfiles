{
  config,
  lib,
  pkgs,
  modulesPath,
  hostname,
  ...
}:
{
  users.users.root.password = "pass";

  boot.loader.grub.enable = false;

  imports = [ (modulesPath + "/profiles/all-hardware.nix") ];

  boot.initrd.availableKernelModules = [
    "e1000e"
    "ext4"
    "loop"
    "af_packet"
    "autofs4"
    "autofs"
    "nfs"
    "nfsv4"
    "overlay"
    "bnx2x"
    "igb"
    "mlx4_en"
    "mlx4_core"
    "mlx5_core"
    "qla4xxx"
    "ixgbe"
    "i40e"
    "be2net"
    "cxgb4"
  ];

  hardware.enableRedistributableFirmware = true;

  boot.initrd.kernelModules = [
    "autofs4"
  ];

  boot.initrd.systemd.enable = true;

  boot.initrd.systemd.initrdBin = [
    pkgs.iproute2
    pkgs.unixtools.ping
    pkgs.curl
  ];

  boot.initrd.network = {
    enable = true;
    flushBeforeStage2 = false;
  };

  boot.initrd.supportedFilesystems = [ "nfs" ];

  networking.useDHCP = true;

  boot.resumeDevice = lib.mkImageMediaOverride "";
  swapDevices = lib.mkImageMediaOverride [ ];

  services.rpcbind.enable = true;

  fileSystems = lib.mkImageMediaOverride {
    "/" = {
      device = "tmpfs";
      fsType = "tmpfs";
      options = [ "mode=0755" ];
      neededForBoot = true;
    };
    #"/nix/.rw-store" = {
    #  fsType = "tmpfs";
    #  neededForBoot = true;
    #};
    #"/nix/.ro-store" = {
    #  neededForBoot = true;
    #  fsType = "nfs";
    #  options = [
    #    "ro"
    #    "noatime"
    #    "addr=192.168.86.114"
    #    "nfsvers=4"
    #    "local_lock=all"
    #  ];
    #  device = "192.168.86.114:/nix/store";
    #};
    #"/nix/store" = {
    #  neededForBoot = true;
    #  fsType = "overlay";
    #  depends = [
    #    "/nix/.ro-store"
    #    "/nix/.rw-store/store"
    #    "/nix/.rw-store/work"
    #  ];
    #  overlay = {
    #    lowerdir = [ "/nix/.ro-store" ];
    #    upperdir = "/nix/.rw-store/store";
    #    workdir = "/nix/.rw-store/work";
    #  };
    #  device = "overlay";
    #};

    "/nix/.ro-store" = {
      device = "/sysroot/var/lib/netboot/nix-store.squashfs";
      fsType = "squashfs";
      options = [
        "loop"
        "ro"
        "x-systemd.requires=fetch-store-squashfs.service"
      ];
      neededForBoot = true;
    };

    "/nix/.rw-store" = {
      device = "tmpfs";
      fsType = "tmpfs";
      options = [ "mode=0755" ];
      neededForBoot = true;
    };

    "/nix/store" = {
      device = "overlay";
      fsType = "overlay";
      neededForBoot = true;
      overlay = {
        upperdir = "/nix/.rw-store/store";
        workdir = "/nix/.rw-store/work";
        lowerdir = [ "/nix/.ro-store" ];
      };
    };

  };

  boot.initrd.systemd.services.fetch-store-squashfs =
    let
      cacheDir = "/sysroot/var/lib/netboot";
      squashPath = "${cacheDir}/nix-store.squashfs";
    in
    {
      description = "Fetch nix-store.squashfs to disk (for later mounting)";
      wantedBy = [ "initrd-switch-root.target" ];
      before = [ "initrd-switch-root.target" ];
      after = [
        "sysroot.mount"
        "network-online.target"
      ];
      wants = [
        "sysroot.mount"
        "network-online.target"
      ];

      unitConfig.DefaultDependencies = false;
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      path = [
        pkgs.curl
        pkgs.coreutils
      ];

      script = ''
        set -euxo pipefail
        url=""
        for param in $(cat /proc/cmdline); do
          case "$param" in
            store_url=*) url="''${param#store_url=}" ;;
          esac
        done
        test -n "$url"

        mkdir -p ${cacheDir}
        if [ ! -s ${squashPath} ]; then
          curl -fL "$url" -o ${squashPath}
        fi
      '';
    };

  boot.kernelParams = [
    "systemd.debug-shell=1"
    "systemd.log_level=debug"
    "boot.shell_on_fail=1"
  ];

  boot.initrd.systemd = {
    emergencyAccess = true;
  };

  system.build.netbootKernel = config.system.build.kernel;
  system.build.netbootRamdisk = config.system.build.initialRamdisk;
  system.build.netbootCmdline = toString (
    [ "init=${config.system.build.toplevel}/init" ] ++ config.boot.kernelParams
  );
  system.build.squashfsStore = pkgs.callPackage "${modulesPath}/../lib/make-squashfs.nix" {
    storeContents = [ config.system.build.toplevel ];
    comp = "zstd -Xcompression-level 19";
  };

}
