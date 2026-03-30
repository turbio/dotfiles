{
  config,
  lib,
  pkgs,
  modulesPath,
  ...
}:
let
  scratchPath = "/scratch";
  scratchInitrdPath = "/sysroot${scratchPath}";
  storeImageInitrdPath = "${scratchInitrdPath}/nix-store.img";
  rwStoreInitrdPath = "${scratchInitrdPath}/rw-store";
  rwStorePath = "${scratchPath}/rw-store";
in
{
  options.netboot = {
    macAddresses = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "MAC addresses this host netboots from";
    };

    storeImageFormat = lib.mkOption {
      type = lib.types.enum [
        "squashfs"
        "erofs"
      ];
      default = "squashfs";
      description = "Filesystem format for the nix store image";
    };

    formatFirstAvailableDisk = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "automatically partition and format the first available local disk for scratch";
    };
  };

  imports = [ (modulesPath + "/profiles/all-hardware.nix") ];

  config = {
    # Show journal on tty1 instead of login prompt for debugging
    services.journald.console = "/dev/tty1";

    boot.loader.grub.enable = false;

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

    boot.initrd.kernelModules = [ "autofs4" ];

    boot.initrd.systemd.enable = true;

    boot.initrd.systemd.initrdBin = [
      pkgs.iproute2
      pkgs.unixtools.ping
      pkgs.curl
      config.boot.initrd.systemd.package.util-linux
      pkgs.coreutils
      pkgs.e2fsprogs
    ];

    boot.initrd.network = {
      enable = true;
      flushBeforeStage2 = false;
    };

    boot.initrd.supportedFilesystems = [
      "nfs"
      config.netboot.storeImageFormat
      "overlay"
    ];

    networking.useDHCP = true;

    boot.resumeDevice = lib.mkImageMediaOverride "";
    swapDevices = [
      {
        label = "swap";
        options = [ "nofail" ];
      }
    ];

    services.rpcbind.enable = true;

    fileSystems = {
      "/" = {
        device = "tmpfs";
        fsType = "tmpfs";
        options = [ "mode=0755" ];
        neededForBoot = true;
      };

      "/nix/.ro-store" = {
        device = storeImageInitrdPath;
        fsType = config.netboot.storeImageFormat;
        options = [
          "loop"
          "ro"
        ];
        neededForBoot = true;
      };

      "/nix/.rw-store" = {
        device = rwStorePath;
        fsType = "none";
        options = [ "bind" ];
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

      "/tmp" = {
        device = "${scratchPath}/tmp";
        fsType = "none";
        options = [ "bind" ];
        neededForBoot = true;
      };
    };

    boot.initrd.systemd.services.format-scratch-disk =
      lib.mkIf config.netboot.formatFirstAvailableDisk
        {
          description = "Format first available disk for scratch";
          wantedBy = [ "setup-scratch.service" ];
          before = [ "setup-scratch.service" ];
          after = [
            "sysroot.mount"
            "network-online.target"
          ];
          wants = [ "network-online.target" ];

          unitConfig.DefaultDependencies = false;
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
          };
          path = [
            config.boot.initrd.systemd.package.util-linux
            config.boot.initrd.systemd.package
            pkgs.e2fsprogs
            pkgs.curl
            pkgs.coreutils
          ];

          script = ''
            set -euo pipefail

            # Total RAM in bytes
            mem_bytes=0
            while read -r key value rest; do
              case "$key" in
                MemTotal:) mem_bytes=$((value * 1024)); break ;;
              esac
            done < /proc/meminfo

            # Store image size via HEAD request
            store_bytes=0
            store_url=""
            for param in $(cat /proc/cmdline); do
              case "$param" in
                store_url=*) store_url="''${param#store_url=}" ;;
              esac
            done
            if [ -n "''${store_url:-}" ]; then
              while IFS=': ' read -r header value; do
                case "$header" in
                  [Cc]ontent-[Ll]ength) store_bytes=$(echo "$value" | tr -d '\r') ;;
                esac
              done < <(curl -sfI "$store_url")
            fi

            # Minimum disk size: swap (=RAM) + store image + 1GB headroom
            extra=$((1024 * 1024 * 1024))
            min_bytes=$((mem_bytes + store_bytes + extra))
            echo "Need ''${min_bytes} bytes (swap=''${mem_bytes} store=''${store_bytes} extra=''${extra})"

            # Find first suitable disk
            target=""
            while read -r dname dtype; do
              [ "$dtype" = "disk" ] || continue

              # Skip disks with an iPXE-labeled partition
              skip=false
              while IFS= read -r label; do
                if [ "$label" = "iPXE" ]; then
                  skip=true
                  break
                fi
              done < <(lsblk -nro LABEL "$dname" 2>/dev/null)
              if $skip; then
                echo "Skipping $dname (iPXE)"
                continue
              fi

              # Skip disks with any mounted partition
              while IFS= read -r mp; do
                if [ -n "$mp" ]; then
                  skip=true
                  break
                fi
              done < <(lsblk -nro MOUNTPOINT "$dname" 2>/dev/null)
              if $skip; then
                echo "Skipping $dname (mounted)"
                continue
              fi

              # Check size
              disk_bytes=$(lsblk -dnbo SIZE "$dname")
              if [ "$disk_bytes" -lt "$min_bytes" ]; then
                echo "Skipping $dname (too small: ''${disk_bytes} < ''${min_bytes})"
                continue
              fi

              target="$dname"
              echo "Selected $dname (''${disk_bytes} bytes)"
              break
            done < <(lsblk -dpno NAME,TYPE)

            if [ -z "$target" ]; then
              echo "ERROR: no suitable disk found"
              exit 1
            fi

            # Partition: swap (RAM-sized) + scratch (rest of disk)
            swap_sectors=$((mem_bytes / 512))
            sfdisk --wipe always --force "$target" <<SFDISK
            label: gpt
            size=$swap_sectors, type=0657FD6D-A4AB-43C4-84E5-0933C84B4F4F
            type=0FC63DAF-8483-4772-8E79-3D69D8477DE4
            SFDISK

            udevadm settle

            # First partition = swap, second = scratch
            readarray -t parts < <(lsblk -lnpo NAME "$target" | tail -n +2)
            swap_dev="''${parts[0]}"
            scratch_dev="''${parts[1]}"

            mkswap -L swap "$swap_dev"
            mkfs.ext4 -F -L scratch "$scratch_dev"

            echo "Done: swap=$swap_dev scratch=$scratch_dev"
          '';
        };

    # Set up /scratch - either from partition labeled "scratch" or tmpfs fallback.
    boot.initrd.systemd.services.setup-scratch = {
      description = "Set up scratch space";
      wantedBy = [
        "sysroot-nix-.rw\\x2dstore.mount"
        "sysroot-tmp.mount"
      ];
      before = [
        "sysroot-nix-.rw\\x2dstore.mount"
        "sysroot-tmp.mount"
      ];
      after = [ "sysroot.mount" ];
      wants = [ "sysroot.mount" ];

      unitConfig.DefaultDependencies = false;
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      path = [
        config.boot.initrd.systemd.package.util-linux
        pkgs.coreutils
        pkgs.e2fsprogs
      ];

      script = ''
        set -euo pipefail

        mkdir -p ${scratchInitrdPath}
        scratch_dev=$(blkid -L scratch 2>/dev/null || true)

        if [ -n "$scratch_dev" ]; then
          mkfs.ext4 -F -L scratch "$scratch_dev"
          mount "$scratch_dev" ${scratchInitrdPath}
        else
          echo "WARNING: No scratch partition - using tmpfs"
          mount -t tmpfs -o mode=0755 tmpfs ${scratchInitrdPath}
        fi

        mkdir -p ${rwStoreInitrdPath}/store
        mkdir -p ${rwStoreInitrdPath}/work
        mkdir -p -m 1777 ${scratchInitrdPath}/tmp
      '';
    };

    boot.initrd.systemd.services.fetch-store-image = {
      description = "Fetch nix store image";
      wantedBy = [ "sysroot-nix-.ro\\x2dstore.mount" ];
      before = [ "sysroot-nix-.ro\\x2dstore.mount" ];
      after = [
        "sysroot.mount"
        "network-online.target"
        "setup-scratch.service"
      ];
      wants = [
        "sysroot.mount"
        "network-online.target"
        "setup-scratch.service"
      ];

      unitConfig.DefaultDependencies = false;
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      path = [
        pkgs.curl
        pkgs.coreutils
        pkgs.util-linux
      ];

      script = ''
        set -euo pipefail
        url=""
        for param in $(cat /proc/cmdline); do
          case "$param" in
            store_url=*) url="''${param#store_url=}" ;;
          esac
        done
        test -n "$url"

        # Parse Content-Length header using bash (no awk/grep in initrd)
        download_size=""
        while IFS=': ' read -r header value; do
          case "$header" in
            [Cc]ontent-[Ll]ength) download_size=$(echo "$value" | tr -d '\r') ;;
          esac
        done < <(curl -sfI "$url")
        available=$(df -B1 --output=avail ${scratchInitrdPath} | tail -1 | tr -d ' ')

        if [ -n "$download_size" ] && [ -n "$available" ]; then
          download_mb=$((download_size / 1024 / 1024))
          available_mb=$((available / 1024 / 1024))
          echo "Downloading $download_mb MB ($available_mb MB available)"
          if [ "$download_size" -gt "$available" ]; then
            echo "WARNING: Download ($download_mb MB) exceeds available space ($available_mb MB)"
            wall "WARNING: Download ($download_mb MB) exceeds available space ($available_mb MB)"
          fi
        fi

        curl -fL "$url" -o ${storeImageInitrdPath}
      '';
    };

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
      comp = "zstd";
    };

    system.build.erofsStore =
      let
        closureInfo = pkgs.closureInfo { rootPaths = [ config.system.build.toplevel ]; };
      in
      pkgs.runCommand "nix-store.erofs"
        {
          __structuredAttrs = true;
          nativeBuildInputs = [ pkgs.erofs-utils ];
          unsafeDiscardReferences.out = true;
        }
        ''
          mkdir root
          cp ${closureInfo}/registration root/nix-path-registration
          while IFS= read -r path; do
            cp -a "$path" root/
          done < ${closureInfo}/store-paths
          mkfs.erofs -z lz4hc -T 0 --all-root --workers=$NIX_BUILD_CORES $out root
        '';

    system.build.netbootSystem =
      let
        output = config.system.build;
        fmt = config.netboot.storeImageFormat;
        storeImage = if fmt == "erofs" then output.erofsStore else output.squashfsStore;
      in
      pkgs.linkFarm "netboot-system" {
        bzImage = "${output.netbootKernel}/bzImage";
        initrd = "${output.netbootRamdisk}/initrd";
        cmdline = pkgs.writeText "cmdline" output.netbootCmdline;
        "nix-store.img" = storeImage;
      };

    boot.postBootCommands = ''
      ${config.nix.package}/bin/nix-store --load-db < /nix/store/nix-path-registration
      touch /etc/NIXOS
      ${config.nix.package}/bin/nix-env -p /nix/var/nix/profiles/system --set /run/current-system
    '';
  };
}
