{ lib, hostname, ... }:
{
  services.syncthing = {
    enable = lib.mkDefault false;
    user = "turbio";
    group = "users";
    openDefaultPorts = true; # todo(turbio): magic hostnames
    settings = {
      options = {
        urAccepted = -1;
        # globalAnnounceEnabled = false; todo(turbio): disable this
        localAnnounceEnabled = true;
        natEnabled = false;
      };
      folders = {
        "photos" = {
          enable = lib.mkDefault false;
          path = lib.mkDefault "/none";
          devices = [
            "ballos"
            "gero"
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
          id = "QJTQAXZ-H67T4R2-5TOKD3Y-LKGTNPA-GF5NDQR-6X2CPVG-UHPTDOR-ER6SGAE";
        };
        ballos = {
          id = "6SH2YN7-U5D7HOJ-NE4QYNS-E3MIXKO-XIWYIUA-TZBEAHU-4LH3XFK-VHLBGAQ";
        };
        gero = {
          id = "GOL62KY-JI4LNIQ-73LQB46-N5PDIXH-FSRZVDJ-TKIR5G3-FPRRZ3T-SBR5SA3";
        };
        itoh = {
          id = "6SH2YN7-U5D7HOJ-NE4QYNS-E3MIXKO-XIWYIUA-TZBEAHU-4LH3XFK-VHLBGAQ";
        };
        curly = {
          id = "CIVDHUC-7N4ASZ6-DSOFH3X-NPI3TQA-7SDUNV4-JFSUDEC-GRPFWEA-GRXLIQJ";
        };
      };
    };
  };
}
