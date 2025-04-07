{ pkgs, ... }:
let
  pixiectrl = pkgs.buildGoModule {
    pname = "pixiectrl";
    version = "0.0.1";
    src = ./pixiectrl;
    vendorHash = null;
  };
in
{
  users.users.pixiecore = {
    extraGroups = [ "users" ];
  };
  services.pixiecore = {
    enable = true;
    openFirewall = true;
    mode = "api";
    apiServer = "http://localhost:4242";
    dhcpNoBind = true;
    port = 8180;
  };


  services.nbd.server = {
    enable = true;
    exports = {
      star-store = { allowAddresses = [ "192.168.0.0/16" ]; path = "/mnt/sync/netboot/star-store"; };
      star-persist = { allowAddresses = [ "192.168.0.0/16" ]; path = "/mnt/sync/netboot/star-persist"; };
      itoh-store = { allowAddresses = [ "192.168.0.0/16" ]; path = "/mnt/sync/netboot/itoh-store"; };
      itoh-persist = { allowAddresses = [ "192.168.0.0/16" ]; path = "/mnt/sync/netboot/itoh-persist"; };
    };
  };

  users.groups.pixiectrl = {};
  users.users.pixiectrl = {
    extraGroups = [ "users" ];
    group = "pixiectrl";
    home = "/var/lib/pixiectrl";
    description = "pixiectrl Daemon user";
    isSystemUser = true;
  };

  systemd.services.pixiectrl = {
    enable = true;
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Group = "pixiectrl";
      User = "pixiectrl";
      WorkingDirectory = "/var/lib/pixiectrl";
      RuntimeDirectory = "pixiectrl";
      RuntimeDirectoryMode = "0750";
      ExecStart = "${pixiectrl}/bin/pixiectrl -port 4242 -addr 127.0.0.1 -hosts /mnt/sync/netboot/";
    };
  };

  systemd.tmpfiles.rules = [
    "d '/var/lib/pixiectrl' 0750 pixiectrl pixiectrl -"
  ];
}
