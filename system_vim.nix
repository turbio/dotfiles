{ pkgs, repos, ... }: {
  environment.variables = { EDITOR = "vim"; };

  environment.systemPackages = with pkgs; [
    ripgrep
  ];

  programs.neovim = {
    enable = true;

    withRuby = true;
    withPython3 = true;
    withNodeJs = true;

    defaultEditor = true;
    vimAlias = true;
    viAlias = false;

    configure = {
      customRC = (builtins.readFile ./config/nvim/init.vim);
      packages.myVimPackage = with pkgs.vimPlugins; {
        start = [
          nvim-nio
          vim-nix
          lightline-vim
          vim-jsx-typescript
          typescript-vim
          yats-vim # more typescript?

          dressing-nvim
          plenary-nvim
          nui-nvim

          # fancy new neovim powered lsp
          nvim-lspconfig
          cmp-nvim-lsp
          actions-preview-nvim
          renamer-nvim
          lsp_signature-nvim
          trouble-nvim

          nvim-treesitter # and ast based syntax highlighting
          nvim-cmp
          render-markdown-nvim

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
          popup-nvim # [wip] pop api from vim in neovim
          telescope-nvim # alternative fzf
          avante-nvim

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
        ] ++ (if pkgs.stdenv.hostPlatform == "x86_64-linux" then [ vim-go ] else []);
      };
    };
  };
}
