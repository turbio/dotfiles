{ config, pkgs, repos, lib, ... }:
{
  programs.neovim = {
    enable = true;
    vimAlias = true;
    withNodeJs = true;
    withRuby = true;
    withPython3 = true;
    #package = pkgs.neovim-nightly;

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
      nvim-cmp

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
      # vim-go # snazzy go support TODO: no arm support???
      popup-nvim # [wip] pop api from vim in neovim
      plenary-nvim # window managment stuff??
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
      #(pkgs.vimUtils.buildVimPlugin {
      #pname = "copilot";
      #version = "1";
      #src = repos.github-copilot-vim;
      #})
    ];
    extraConfig = (builtins.readFile ./config/nvim/init.vim);
  };
}
