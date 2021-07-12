{ config, pkgs, lib, ... }:
{

  nixpkgs.overlays = [
    (import (builtins.fetchTarball {
      url = https://github.com/nix-community/neovim-nightly-overlay/archive/master.tar.gz;
    }))
  ];

  programs.neovim = {
    enable = true;
    package = pkgs.neovim-nightly;
    vimAlias = true;
    withNodeJs = true;
    withRuby = true;
    withPython3 = true;

    plugins = with pkgs.vimPlugins; [
      vim-nix
      lightline-vim
      vim-jsx-typescript
      typescript-vim
      yats-vim # more typescript?

      lspsaga-nvim
      nvim-lspconfig
      nvim-treesitter

      vim-gitgutter
      vim-fugitive

      neoformat

      nvim-web-devicons

      vim-obsession
      vim-endwise
      tagbar
      undotree
      nerdtree
      vim-sleuth
      nerdcommenter
      vim-misc
      echodoc-vim # print function signatures in command line
      fzf-vim # for ctrl-p and ctrl-/
      vim-go # snazzy go support
      popup-nvim # [wip] pop api from vim in neovim
      plenary-nvim # window managment stuff??
      telescope-nvim # alternative fzf
    ] ++ [
      (pkgs.vimUtils.buildVimPluginFrom2Nix {
        pname = "muble";
        version = "1";
        src = pkgs.fetchFromGitHub {
          owner = "turbio";
          repo = "muble.vim";
          rev = "master";
          sha256 = "1rbh896sfidwgz3g6dxavx9q8145ynx5nsbj0nqrh14s2p6p1qxw";
        };
      })
    ];
    extraConfig = (builtins.readFile ./config/nvim/init.vim);
  };
}
