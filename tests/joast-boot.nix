{ pkgs, joast }:
let
  lib = pkgs.lib;

  passphrase = "correct horse battery staple";

  real = joast.config.system.build;

  target = joast.extendModules {
    modules = [
      (
        { lib, pkgs, ... }:
        {
          # ttyS0 is a unix socket the test script reads raw, cause the driver's
          # own line based serial reader can't see the key prompt (no newline).
          # last console= is /dev/console, where systemd's status lines go
          boot.kernelParams = [
            "console=tty0"
            "console=ttyS0"
          ];

          # guests can't do much nested in here and they're most of the closure
          microvm.vms = lib.mkForce { };

          # the test driver's root shell, stage 2 only. not using nixpkgs'
          # test-instrumentation.nix cause it messes with the initrd
          systemd.services.backdoor = {
            wantedBy = [ "multi-user.target" ];
            requires = [
              "dev-hvc0.device"
              "dev-ttyS0.device"
            ];
            after = [
              "dev-hvc0.device"
              "dev-ttyS0.device"
            ];
            script = ''
              export USER=root
              export HOME=/root
              source /etc/profile
              export PAGER=
              cd /tmp
              exec < /dev/hvc0 > /dev/hvc0
              while ! exec 2> /dev/ttyS0; do sleep 0.1; done
              stty -F /dev/hvc0 raw -echo
              echo "Spawning backdoor root shell..."
              PS1="" exec ${pkgs.bashNonInteractive}/bin/bash --norc /dev/hvc0
            '';
            serviceConfig.KillSignal = "SIGHUP";
          };
          systemd.services."serial-getty@ttyS0".enable = false;
          systemd.services."serial-getty@hvc0".enable = false;
        }
      )
    ];
  };

  test = target.config.system.build;
  toplevel = test.toplevel;

  # same layout as the real thing: boot ssd, 9 wide raidz2 on the sas
  # backplane, nvme pair split into special + l2arc
  ssd = "ssd0";
  hdds = lib.genList (i: "hdd${toString i}") 9;
  nvmes = [
    "nvme0"
    "nvme1"
  ];

  images = {
    ${ssd} = "16G";
  }
  // lib.genAttrs hdds (_: "8G")
  // lib.genAttrs nvmes (_: "16G");

  drive = name: "-drive id=${name},if=none,format=qcow2,cache=unsafe,file=$JOAST_DISKS/${name}.qcow2";

  # 6 ports per ahci controller
  diskArgs = lib.concatStringsSep " " (
    [
      "-device ahci,id=sata0"
      "-device ahci,id=sata1"
    ]
    ++ lib.imap0 (
      i: name:
      "${drive name} -device ide-hd,drive=${name},serial=${name},bus=sata${toString (i / 6)}.${toString (lib.mod i 6)}"
    ) ([ ssd ] ++ hdds)
    ++ map (name: "${drive name} -device nvme,drive=${name},serial=${name}") nvmes
  );

  ata = name: "/dev/disk/by-id/ata-QEMU_HARDDISK_${name}";
  nvme = name: "/dev/disk/by-id/nvme-QEMU_NVMe_Ctrl_${name}";

  qemu = pkgs.qemu_test;
  ovmf = pkgs.OVMFFull;

  # eno1 is the only nic we can get the name right for, the bond's
  # eno5np0/eno6np1 need a real driver's phys_port_name
  startJoast = lib.concatStringsSep " " [
    "${qemu}/bin/qemu-kvm"
    "-machine q35,smm=on"
    "-global driver=cfi.pflash01,property=secure,value=on"
    "-cpu max"
    "-smp 8"
    "-m 16G"
    "-drive if=pflash,format=raw,unit=0,readonly=on,file=${ovmf.firmware}"
    "-drive if=pflash,format=raw,unit=1,file=$JOAST_DISKS/efi-vars.fd"
    diskArgs
    "-chardev socket,id=console,path=$JOAST_DISKS/console.sock,server=on,wait=off"
    "-serial chardev:console"
    "-netdev user,id=eno1,restrict=on"
    "-device e1000e,netdev=eno1,acpi-index=1"
  ];
in
assert lib.assertMsg (
  test.kernel == real.kernel && test.initialRamdisk == real.initialRamdisk
) "joast-boot: the test system's kernel/initrd aren't the ones joast boots";
pkgs.testers.runNixOSTest {
  name = "joast-boot";
  globalTimeout = 30 * 60;

  nodes.installer =
    { lib, pkgs, ... }:
    {
      virtualisation = {
        # bootctl wants efivars
        useEFIBoot = true;
        memorySize = 8192;
        cores = 8;
        qemu.options = [ diskArgs ];
        additionalPaths = [ toplevel ];
      };

      boot.supportedFilesystems = [ "zfs" ];
      boot.kernelPackages = target.config.boot.kernelPackages;
      boot.zfs.package = target.config.boot.zfs.package;
      networking.hostId = target.config.networking.hostId;

      environment.systemPackages = [ pkgs.gptfdisk ];
      nix.settings.substituters = lib.mkForce [ ];
    };

  testScript = ''
    import json
    import os
    import shutil
    import subprocess
    import threading
    import re
    import socket
    import time

    passphrase = "${passphrase}"
    toplevel = "${toplevel}"

    disks = os.path.join(os.environ.get("TMPDIR", "/tmp"), "joast-disks")
    os.makedirs(disks, exist_ok=True)
    os.environ["JOAST_DISKS"] = disks
    for name, size in json.loads('${builtins.toJSON images}').items():
        subprocess.run(
            ["${qemu}/bin/qemu-img", "create", "-f", "qcow2", f"{disks}/{name}.qcow2", size],
            check=True,
        )

    with subtest("install"):
        installer.start()
        installer.wait_for_unit("multi-user.target")
        installer.succeed("udevadm settle")

        # no swap partition. disko says there's one but the ssd never had room
        installer.succeed(
            "sgdisk --zap-all ${ata ssd}",
            "sgdisk -n1:0:+500M -t1:EF00 -c1:disk-main-ESP ${ata ssd}",
            "sgdisk -n2:0:0 -t2:8300 -c2:disk-main-root ${ata ssd}",
            ${lib.concatMapStringsSep "\n        " (n: ''
              "sgdisk --zap-all ${nvme n}",
                      "sgdisk -n1:0:+12G -n2:0:0 ${nvme n}",'') nvmes}
            "udevadm settle",
            "mkfs.vfat /dev/disk/by-partlabel/disk-main-ESP",
            "mkfs.ext4 -q /dev/disk/by-partlabel/disk-main-root",
            "mkdir -p /mnt",
            "mount /dev/disk/by-partlabel/disk-main-root /mnt",
        )

        installer.succeed(
            # -f cause raidz2 + 2 way special is a replication mismatch
            "zpool create -f -R /mnt tank"
            " raidz2 ${lib.concatMapStringsSep " " ata hdds}"
            " special mirror ${lib.concatMapStringsSep " " (n: "${nvme n}-part1") nvmes}"
            " cache ${lib.concatMapStringsSep " " (n: "${nvme n}-part2") nvmes}",
            f"echo '{passphrase}' | zfs create -o encryption=aes-256-gcm -o keyformat=passphrase -o keylocation=prompt tank/enc",
            "zfs create -o acltype=posix -o special_small_blocks=64K tank/enc/nixstore",
            "zfs create -o sync=disabled tank/enc/nixbuilds",
        )

        installer.succeed(
            "mkdir -p /mnt/boot /mnt/nix/store",
            "mount -o umask=0077 /dev/disk/by-partlabel/disk-main-ESP /mnt/boot",
            "mount --bind /mnt/tank/enc/nixstore /mnt/nix/store",
        )
        installer.succeed(
            f"nixos-install --root /mnt --system {toplevel} --no-root-passwd --no-channel-copy >&2",
            timeout=3600,
        )
        print(installer.succeed("cat /mnt/boot/loader/loader.conf /mnt/boot/loader/entries/*.conf; bootctl --esp-path=/mnt/boot status || true"))

        installer.succeed(
            "umount /mnt/nix/store /mnt/boot",
            "zpool export tank",
            "umount /mnt",
        )
        installer.shutdown()

        # carries the Linux Boot Manager entry bootctl just wrote
        shutil.copy(installer.efi_vars_path, f"{disks}/efi-vars.fd")

    joast = create_machine("${startJoast}", name="joast")

    # not in the driver's machine list so it'd be left running on failure,
    # and its serial thread then keeps the driver from ever exiting
    machines_qemu.append(joast)

    ansi = re.compile(r"\x1b(\[[0-9;:?]*[A-Za-z]|[A-Z=>])")

    # our -serial comes before the driver's so the socket is ttyS0. the
    # driver's serial (ttyS1) gets nothing from linux
    class Console:
        def __init__(self):
            self.sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
            self.sock.connect(f"{disks}/console.sock")
            self.buf = ""
            self.lock = threading.Lock()
            threading.Thread(target=self.read, daemon=True).start()

        # has to keep draining even when nobody's expecting anything. if the
        # socket backs up, writes to /dev/console block and pid 1 stalls
        def read(self):
            partial = line = ""
            while True:
                try:
                    data = self.sock.recv(4096)
                except OSError:
                    return
                if not data:
                    return
                # systemd bolds the unit description in the middle of its
                # status lines, so the escapes have to go before matching.
                # hold back a sequence that's split across reads
                text = partial + data.decode(errors="ignore").replace("\r", "")
                partial = ""
                esc = text.rfind("\x1b")
                if esc != -1 and not ansi.match(text, esc):
                    text, partial = text[:esc], text[esc:]
                text = ansi.sub("", text)
                with self.lock:
                    self.buf += text
                *lines, line = (line + text).split("\n")
                for l in lines:
                    joast.log(f"console: {l.rstrip()}")

        def expect(self, regex, timeout=300):
            deadline = time.time() + timeout
            while True:
                with self.lock:
                    m = re.search(regex, self.buf)
                    if m:
                        self.buf = self.buf[m.end():]
                        return m
                    if time.time() > deadline:
                        raise Exception(f"timed out waiting for {regex!r} on the console, last seen:\n{self.buf[-2000:]!r}")
                time.sleep(0.2)

        def send(self, text):
            joast.log(f"console <- {text!r}")
            self.sock.sendall(text.encode())

    def start():
        joast.start()
        return Console()

    def answer_prompts(console, keys):
        for key in keys:
            console.expect(r"Enter key for tank/enc:")
            console.send(key + "\n")

    def check_stage2(console):
        # anything that breaks initrd lands in the emergency shell, and the
        # driver would otherwise wait on its root shell till the global timeout
        m = console.expect(r"Welcome to NixOS|You are in emergency mode")
        assert "Welcome" in m.group(0), "initrd dropped to the emergency shell"

        joast.wait_for_unit("multi-user.target")

        cmdline = joast.succeed("cat /proc/cmdline")
        assert f"init={toplevel}/init" in cmdline, cmdline
        for param in json.loads('${builtins.toJSON joast.config.boot.kernelParams}'):
            assert param in cmdline, f"{param} missing from {cmdline}"
        assert joast.succeed("readlink /run/booted-system").strip() == toplevel

        # the ro remount of /nix/store propagates back onto /tank/enc/nixstore
        # so mounts stack up there. they just all have to be the same thing
        def source(path):
            out = joast.succeed(f"findmnt -no SOURCE,FSTYPE {path} | sort -u").strip().splitlines()
            assert len(out) == 1, f"{path}: {out}"
            return out[0].split()

        assert source("/")[1] == "ext4", source("/")
        assert source("/boot")[1] == "vfat", source("/boot")
        assert source("/tank") == ["tank", "zfs"], source("/tank")
        assert source("/tank/enc") == ["tank/enc", "zfs"], source("/tank/enc")
        assert source("/tank/enc/nixstore") == ["tank/enc/nixstore", "zfs"], source("/tank/enc/nixstore")
        assert source("/nix/store") == ["tank/enc/nixstore", "zfs"], source("/nix/store")
        assert source("/nix/var/nix/builds") == ["tank/enc/nixbuilds", "zfs"], source("/nix/var/nix/builds")

        # stage 2's zfs mount -a didn't bury the store under /tank
        joast.succeed(f"test -e /tank/enc/nixstore/{os.path.basename(toplevel)}/init")

        joast.succeed("zpool status -x tank | grep -q 'is healthy'")
        assert joast.succeed("zfs get -H -o value keystatus tank/enc").strip() == "available"
        unmounted = joast.succeed("zfs list -H -o name,mounted,canmount -t filesystem -r tank | awk '$2 != \"yes\" && $3 == \"on\"'")
        assert unmounted == "", unmounted

        joast.succeed(
            "systemctl is-active local-fs.target zfs-mount.service zfs.target",
            "nix-store --verify-path /run/current-system",
        )
        failed = joast.succeed("systemctl list-units --failed --no-legend --plain 'zfs-*' '*.mount' | cat")
        assert failed.strip() == "", failed

        # nothing got written to the ext4 root where pool mounts should be
        joast.succeed(
            "mkdir -p /run/rootonly && mount --bind / /run/rootonly",
            "test -z \"$(ls -A /run/rootonly/tank)\"",
            "test ! -e /run/rootonly/sysroot",
            "umount /run/rootonly",
        )

        # just for the log. plenty fails in here w/ no network or secrets
        print(joast.succeed("systemctl list-units --failed --no-legend --plain | cat"))

    with subtest("boot"):
        console = start()
        answer_prompts(console, [passphrase])
        console.expect(r'Finished Import ZFS pool "tank"')
        check_stage2(console)
        joast.shutdown()

    with subtest("wrong key drops to the initrd emergency shell and recovers"):
        console = start()
        answer_prompts(console, ["definitely not it"] * 3)
        console.expect(r'Failed to start Import ZFS pool "tank"')
        console.expect(r"Control-D to continue\):")
        console.send("\n")
        console.expect(r"# $")
        console.send(f"echo '{passphrase}' | zfs load-key tank/enc; exit\n")
        check_stage2(console)
        joast.shutdown()
  '';
}
