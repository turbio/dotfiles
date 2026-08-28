# cgit — read-only web view over the git dataset (mounted ro at /git),
# behind ballos's git.turb.io vhost. stateless: no persistVar, cache lives
# and dies with the vm. cut over in one step 2026-07-31 — both instances
# would have read the same live dataset, so side-by-side proved nothing.
{ ... }:
{
  # the dataset is git:git 750 on the host and virtiofs passes ids through
  # unmapped — group access needs the host's git gid, which is dynamically
  # allocated there (977:976, checked 2026-07-31). structural pin, same
  # lesson as forgejo's migration chown.
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

  # repos are owned by uid 977, cgit's git invocations run as other users
  environment.etc.gitconfig.text = ''
    [safe]
      directory = *
  '';
}
