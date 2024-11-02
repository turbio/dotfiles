{ pkgs, ... }: {
  isDesktop = true;

  services.fwupd.enable = true;

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.interfaces.wlp1s0.useDHCP = true;

  hardware.bluetooth.enable = true;
  services.blueman.enable = true;

  programs.light.enable = true;

  boot.initrd.kernelModules = [ "amdgpu" ];

  services.logind = {
    lidSwitch = "suspend";
    extraConfig = ''
      HandlePowerKey=ignore
      HandleSuspendKey=ignore
      HandleHibernateKey=ignore
    '';
  };

  services.syncthing = {
    enable = true;
    configDir = "/home/turbio/.config/syncthing";
    dataDir = "/home/turbio";
    settings.folders = {
      "photos" = { enable = true; path = "~/photos"; };
      "code" = { enable = true; path = "~/code"; };
    };
  };
}
