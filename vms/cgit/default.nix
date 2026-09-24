{ ... }:
{
  users.groups.git.gid = 976;

  services.cgit.default = {
    enable = true;
    group = "git";
    scanPath = "/git/repositories";
    nginx.virtualHost = "git.turb.io";

    gitHttpBackend.enable = true;
    gitHttpBackend.checkExportOkFiles = false;

    settings = {
      enable-git-config = 1;
      remove-suffix = 1;
      enable-index-owner = 0;
      logo = "";
      root-title = "turbio git";
      clone-url = "https://git.turb.io/$CGIT_REPO_URL";
    };
  };

  environment.etc.gitconfig.text = ''
    [safe]
      directory = *
  '';
}
