{ pkgs, ... }:
let
  kubeMasterIP = "192.168.86.53";
  kubeMasterHostname = "api.kube";
  kubeMasterAPIServerPort = 6443;
in
{
  networking.firewall.enable = false;

  boot.binfmt.emulatedSystems = [ "aarch64-linux" ];

  networking.extraHosts = "${kubeMasterIP} ${kubeMasterHostname}";

  environment.systemPackages = with pkgs; [
    kompose
    kubectl
    kubernetes

    k9s
  ];

  services.kubernetes = {
    roles = ["master" "node"];
    masterAddress = kubeMasterHostname;
    apiserverAddress = "https://${kubeMasterHostname}:${toString kubeMasterAPIServerPort}";
    easyCerts = true;
    apiserver = {
      securePort = kubeMasterAPIServerPort;
      advertiseAddress = kubeMasterIP;
    };
  };
}
