{ lib, inventory, ... }:
{
  services.syncthing = {
    enable = lib.mkDefault false;
    user = "turbio";
    group = "users";
    #openDefaultPorts = true; # todo(turbio): magic hostnames
    relay.enable = false;

    settings = {
      options = {
        urAccepted = -1;
        globalAnnounceEnabled = false;
        localAnnounceEnabled = false;
        natEnabled = false;
      };
      folders = {
        "photos" = {
          enable = lib.mkDefault false;
          path = lib.mkDefault "/none";
          devices = [
            "ballos"
            "gero"
            "curly"
          ];
        };
        "code" = {
          enable = lib.mkDefault false;
          path = lib.mkDefault "/none";
          devices = [
            "ballos"
            "gero"
            "itoh"
            "curly"
          ];
        };
        "notes" = {
          enable = lib.mkDefault false;
          path = lib.mkDefault "/none";
          devices = [
            "ballos"
            "gero"
            "iphone"
            "curly"
            "itoh"
          ];
        };
        "ios_photos" = {
          enable = lib.mkDefault false;
          path = lib.mkDefault "/none";
          devices = [
            "ballos"
            "iphone"
          ];
        };
        "clips" = {
          enable = lib.mkDefault false;
          path = lib.mkDefault "/none";
          devices = [
            "ballos"
            "curly"
            "itoh"
            "gero"
          ];
        };
        "webcamlog" = {
          enable = lib.mkDefault false;
          path = lib.mkDefault "/none";
          devices = [
            "ballos"
            "curly"
            "itoh"
            "gero"
          ];
        };
      };
      devices = {
        iphone = {
          id = "U6DSDQT-RHHKWPS-T5AI3LN-VVZSIAP-WOLWDDJ-GEC4JE6-LSL45CH-GGCXZQU";
        };
        ballos = {
          addresses = [
            "tcp://${inventory.machines.ballos.tailscale.ip6}:22000"
            "tcp://${inventory.machines.ballos.tailscale.ip4}:22000"
          ];
          id = "6SH2YN7-U5D7HOJ-NE4QYNS-E3MIXKO-XIWYIUA-TZBEAHU-4LH3XFK-VHLBGAQ";
        };
        gero = {
          addresses = [ ];
          id = "GOL62KY-JI4LNIQ-73LQB46-N5PDIXH-FSRZVDJ-TKIR5G3-FPRRZ3T-SBR5SA3";
        };
        itoh = {
          addresses = [ ];
          id = "YL2VOWW-XXW6YEW-GU6MD5H-LNYGDCU-3W7Q6LA-TR6ZGUW-O5U3JWJ-PPQADQJ";
        };
        curly = {
          addresses = [
            "tcp://${inventory.machines.curly.tailscale.ip4}:22000"
          ];
          id = "CIVDHUC-7N4ASZ6-DSOFH3X-NPI3TQA-7SDUNV4-JFSUDEC-GRPFWEA-GRXLIQJ";
        };
      };
    };
  };
}
