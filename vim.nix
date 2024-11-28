{ config, pkgs, repos, lib, ... }:
{
  programs.neovim = {
    enable = true;
    vimAlias = true;
    withNodeJs = true;
    withRuby = true;
    withPython3 = true;

    plugins = with pkgs.vimPlugins; [
      nvim-nio
      vim-nix
      lightline-vim
      vim-jsx-typescript
      typescript-vim
      yats-vim # more typescript?

      plenary-nvim # window managment stuff??

      # fancy new neovim powered lsp
      nvim-lspconfig
      cmp-nvim-lsp
      actions-preview-nvim
      renamer-nvim
      lsp_signature-nvim
      trouble-nvim

      nvim-treesitter # and ast based syntax highlighting
      nvim-cmp

      vim-gitgutter
      vim-fugitive

      vim-endwise # auto adds end/endif/etc
      undotree # time travel isn't linear
      nerdtree # happy lil file tree
      vim-sleuth # auto configures intentation based on what the file looks like
      nerdcommenter # gives me some easy shortcuts to comment/uncomment
      vim-misc # ?????
      echodoc-vim # print function signatures in command line
      fzf-vim # for ctrl-p and ctrl-/
      # vim-go # snazzy go support TODO: no arm support???
      popup-nvim # [wip] pop api from vim in neovim
      telescope-nvim # alternative fzf
    ] ++ [
      (pkgs.vimUtils.buildVimPlugin {
        pname = "muble";
        version = "1";
        src = repos.muble-vim;
      })
      (pkgs.vimUtils.buildVimPlugin {
        pname = "vim-openscad";
        version = "1";
        src = repos.openscad-vim;
      })
      (pkgs.vimUtils.buildVimPlugin {
        pname = "copilot";
        version = "1";
        src = repos.github-copilot-vim;
      })
      (pkgs.vimUtils.buildVimPlugin {
        pname = "lsp_lines.nvim";
        version = "1";
        src = repos.lsp-lines-nvim;
      })
      (pkgs.vimUtils.buildVimPlugin {
        pname = "dingllm-nvim";
        version = "1";
        src = repos.dingllm-nvim;
      })
      (pkgs.vimUtils.buildVimPlugin {
        pname = "llm-nvim";
        version = "1";
        src = repos.llm-nvim;
      })
    ];
    extraConfig = (builtins.readFile ./config/nvim/init.vim);
  };
}
