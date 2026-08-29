# vibes — media curation service. the media dataset (enc/vibes) mounts at
# /media via the inventory mounts mechanism. the guest owns its whole http
# surface: nginx serves the webroot and media statics off the mount and
# proxies /c/ to the app; the hypervisor's nginx is just an ssl-terminating
# proxy to :80 here (the vibes.turb.io vhost in hosts/joast).
{ pkgs, ... }:
let
  vibesbin = pkgs.buildGoModule {
    name = "vibes";
    version = "0.0.1";
    src = ./.;
    vendorHash = null;
    postPatch = ''
      go mod init vibes
    '';
  };

  mediaRoot = "/media";
  port = "3010";

  webroot = pkgs.linkFarm "vibes-webroot" [
    {
      name = "index.html";
      path = pkgs.replaceVars ./webroot/index.html {
        pageTitle = "vibes";
        extraHead = "";
      };
    }
  ];

  # the nice.meme /vids/ face of the same app (proxied from that vhost on
  # joast)
  vidsroot = pkgs.linkFarm "vibes-vids-webroot" [
    {
      name = "index.html";
      path = pkgs.replaceVars ./webroot/index.html {
        pageTitle = "nice memes";
        extraHead = ''
          <script async src="https://www.googletagmanager.com/gtag/js?id=G-6E4JY4KNSC"></script>
          <script>
            window.dataLayer = window.dataLayer || [];
            function gtag(){dataLayer.push(arguments);}
            gtag('js', new Date());

            gtag('config', 'G-6E4JY4KNSC');
          </script>
        '';
      };
    }
  ];
in
{
  users.groups.media = { };
  users.users.vibes = {
    group = "media";
    isSystemUser = true;
  };

  # the category structure the app expects (was an activation script on the
  # host); guest-side so ownership uses the guest's uid mapping
  systemd.tmpfiles.rules = [
    "d ${mediaRoot}/media 0775 vibes media -"
    "d ${mediaRoot}/cat/bop 0775 vibes media -"
    "d ${mediaRoot}/cat/flop 0775 vibes media -"
    "d ${mediaRoot}/cat/lewd 0775 vibes media -"
  ];

  systemd.services.vibes = {
    description = "just vibin";
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Group = "media";
      User = "vibes";
      ExecStart = "${vibesbin}/bin/vibes --addr 127.0.0.1:${port} --root ${mediaRoot}";
      Restart = "always";
      RestartSec = "5s";
    };
  };

  users.users.nginx.extraGroups = [ "media" ];
  services.nginx = {
    enable = true;
    virtualHosts.vibes = {
      default = true;

      locations."/" = {
        root = webroot;
        index = "index.html";
      };

      locations."/vids/" = {
        alias = "${vidsroot}/";
        index = "index.html";
      };

      locations."/c/" = {
        proxyPass = "http://127.0.0.1:${port}";
      };

      locations."/media/" = {
        root = mediaRoot;
      };

      extraConfig = ''
        charset utf-8;
      '';
    };
  };
}
