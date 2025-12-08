{
  pkgs,
  repos,
  config,
  lib,
  ...
}:
let
  plugins =
    with pkgs.vimPlugins;
    [
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
      cmp-nvim-lsp
      lsp_signature-nvim
      trouble-nvim

      nvim-treesitter # and ast based syntax highlighting
      nvim-cmp
      #render-markdown-nvim

      #vim-gitgutter
      vim-fugitive

      vim-endwise # auto adds end/endif/etc
      undotree # time travel isn't linear
      nerdtree # happy lil file tree
      vim-sleuth # auto configures intentation based on what the file looks like
      nerdcommenter # gives me some easy shortcuts to comment/uncomment
      vim-misc # ?????
      echodoc-vim # print function signatures in command line
      popup-nvim # [wip] pop api from vim in neovim
      #telescope-nvim # alternative fzf

      codewindow-nvim

      indent-blankline-nvim

      (pkgs.vimUtils.buildVimPlugin {
        pname = "muble";
        version = "1";
        src = repos.muble-vim;
      })
      (pkgs.vimUtils.buildVimPlugin {
        pname = "lsp_lines.nvim";
        version = "1";
        src = repos.lsp-lines-nvim;
      })
    ]
    ++ (if pkgs.stdenv.hostPlatform == "x86_64-linux" then [ vim-go ] else [ ]);
in
{
  nixpkgs.config.allowUnfree = true; # copilot-vim

  programs.nixvim = {
    extraPackages = with pkgs; [
      ripgrep

      # should all my machines really have nix tooling???
      nixd
      nixfmt-rfc-style
    ];

    nixpkgs.pkgs = pkgs;

    enable = true;

    vimAlias = true;
    viAlias = false;

    opts.laststatus = 2;

    extraConfigVim = (builtins.readFile ./config/nvim/init.vim);

    plugins = {
      copilot-vim.enable = true;

      direnv.enable = true;

      lspconfig.enable = true;
      web-devicons.enable = true;

      render-markdown.enable = true;
      render-markdown.autoLoad = true;

      nui.enable = true;

      #telescope.enable = true;
      fzf-lua.enable = true;
      fzf-lua.keymaps = {
        "<C-/>" = "live_grep";
        "<C-p>" = "files";
      };

      openscad.enable = config.isDesktop; # bruh... pulls in cups + gtk + qt and morjek:wweb-devicons
      gitgutter.enable = true;
    };

    lsp.inlayHints.enable = true;
    lsp.servers = {
      clangd.enable = true;
      gopls.enable = true;
      rust_analyzer.enable = true;
      nixd.enable = true;
      hls.enable = true;
      ts_ls.enable = true;
      bashls.enable = true;
    };

    extraPlugins = plugins;
  };

  environment.variables = {
    EDITOR = "vim";
  };
}
