# Disko config for netboot machines
# Formats a disk with swap (auto-mounted via GPT type) and scratch partition
#
# Usage: nix run github:nix-community/disko -- --mode disko --flake '.#<host>' --disk main /dev/sdX
{ lib, ... }:
{
  disko.devices.disk.main = {
    device = lib.mkDefault "/dev/sda";
    type = "disk";
    content = {
      type = "gpt";
      partitions = {
        swap = {
          size = "32G";
          type = "8200"; # Linux swap - systemd auto-enables this
          content = {
            type = "swap";
          };
        };
        scratch = {
          size = "100%";
          content = {
            type = "filesystem";
            format = "ext4";
            extraArgs = [ "-L" "scratch" ];
          };
        };
      };
    };
  };
}
