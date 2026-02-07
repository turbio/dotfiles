# NixOS module for nixvim
{
  pkgs,
  repos,
  config,
  ...
}:
let
  nixvimConfig = import ./vimconfig.nix {
    inherit pkgs repos;
    isDesktop = config.isDesktop or false;
  };
in
{
  nixpkgs.config.allowUnfree = true;

  programs.nixvim = nixvimConfig // {
    enable = true;
    nixpkgs.pkgs = pkgs;
  };

  environment.variables = {
    EDITOR = "vim";
  };
}
