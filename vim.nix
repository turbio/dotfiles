{ config, pkgs, lib, ... }:
{
  programs.neovim = {
    enable = true;
    vimAlias = true;
    withNodeJs = true;
    withRuby = true;
    withPython3 = true;
    package = pkgs.neovim-nightly;

    plugins = with pkgs.vimPlugins; [
      vim-nix
      lightline-vim
      vim-jsx-typescript
      typescript-vim
      yats-vim # more typescript?

      # fancy new neovim powered lsp
      lspsaga-nvim
      nvim-lspconfig

      nvim-treesitter # and ast based syntax highlighting

      vim-gitgutter
      vim-fugitive

      neoformat

      vim-endwise # auto adds end/endif/etc
      undotree # time travel isn't linear
      nerdtree # happy lil file tree
      vim-sleuth # auto configures intentation based on what the file looks like
      nerdcommenter # gives me some easy shortcuts to comment/uncomment
      vim-misc # ?????
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
      (pkgs.vimUtils.buildVimPluginFrom2Nix {
        pname = "copilot";
        version = "1";
        src = pkgs.fetchFromGitHub {
          owner = "github";
          repo = "copilot.vim";
          rev = "release";
          sha256 = "sha256-hKRkn/+6S2JfAlgN13X2HNl/1vIjeMM5YnSTEwVQDTg=";
        };
      })
    ];
    extraConfig = (builtins.readFile ./config/nvim/init.vim);
  };
}
