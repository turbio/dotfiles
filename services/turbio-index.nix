{ pkgs, ... }:
let
  root = (
    pkgs.writeTextDir "index.txt" ''
      hey!
      ====

      i'm mason / turbio

      🐧
    ''
  );

  catchall404 = (
    pkgs.writeTextDir "404.txt" ''
      zooweemama
    ''
  );

  turbioWildcard404 = (
    pkgs.writeTextDir "404.txt" ''
      404!
      ====

      uh oh
    ''
  );

  turbio404 = (
    pkgs.writeTextDir "404.txt" ''
      404!
      ====

      but like what were you expecting?
    ''
  );
in
{
  networking.firewall.allowedTCPPorts = [
    80
    443
  ];

  services.nginx.virtualHosts."turb.io" = {
    forceSSL = true;
    useACMEHost = "turb.io";

    root = "${root}";

    locations."/" = {
      index = "index.txt";
    };

    locations."=/404.txt" = {
      return = "404";
      root = "${turbio404}";
      index = "404.txt";
      extraConfig = ''
        internal;
      '';
    };

    extraConfig = ''
      error_page 404 /404.txt;
      charset utf-8;
    '';
  };

  services.nginx.virtualHosts."*.turb.io" = {
    addSSL = true;
    useACMEHost = "turb.io";

    root = "${turbioWildcard404}";

    locations."/" = {
      return = "404";
    };

    locations."=/404.txt" = {
      extraConfig = ''
        internal;
      '';
    };

    extraConfig = ''
      error_page 404 /404.txt;
      charset utf-8;
    '';
  };

  services.nginx.virtualHosts."_" = {
    default = true;
    rejectSSL = true;
    root = "${catchall404}";
    locations."/" = {
      return = "404";
    };
  };
}
