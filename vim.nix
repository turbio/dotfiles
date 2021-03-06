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
      (pkgs.vimUtils.buildVimPluginFrom2Nix {
        pname = "vim-openscad";
        version = "1";
        src = pkgs.fetchFromGitHub {
          owner = "sirtaj";
          repo = "vim-openscad";
          rev = "81db508";
          sha256 = "1wcdfayjpb9h0lzwdi5nda4c0ch263fdr0379l9k1gf47bgq9cx2";
        };
      })
    ];
    extraConfig = (builtins.readFile ./config/nvim/init.vim);
  };
}
