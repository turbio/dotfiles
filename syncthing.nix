{ lib, ... }: {
  services.syncthing = {
    enable = lib.mkDefault false;
    user = "turbio";
    group = "users";
    openDefaultPorts = lib.mkDefault false;
    settings = {
      options.urAccepted = -1;
      folders = {
        "photos" = {
          enable = lib.mkDefault false;
          path = lib.mkDefault "/none";
          devices = [ "ballos" "gero" ];
        };
        "code" = {
          enable = lib.mkDefault false;
          path = lib.mkDefault "/none";
          devices = [ "ballos" "gero" "itoh" ];
        };
      };
      devices = {
        ballos = {
          id = "6SH2YN7-U5D7HOJ-NE4QYNS-E3MIXKO-XIWYIUA-TZBEAHU-4LH3XFK-VHLBGAQ";
        };
        gero = {
          id = "GOL62KY-JI4LNIQ-73LQB46-N5PDIXH-FSRZVDJ-TKIR5G3-FPRRZ3T-SBR5SA3";
        };
        itoh = {
          id = "UQWKK6L-ECHOK23-QNNH5PC-BDY6RL4-AILT6PX-QDG27VN-BLT664L-7ERCGAD";
        };
      };
    };
  };
}
