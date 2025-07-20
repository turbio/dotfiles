{ pkgs, repos, config, ... }:
let
  plugins = with pkgs.vimPlugins; [
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
  ] ++ (if pkgs.stdenv.hostPlatform == "x86_64-linux" then [ vim-go ] else [ ]);
in
{

  nixpkgs.config.allowUnfree = true; # copilot

  programs.nixvim = {
    enable = true;

    vimAlias = true;
    viAlias = false;

    opts.laststatus = 2;

    extraConfigVim = (builtins.readFile ./config/nvim/init.vim);

    plugins = {
      lsp.enable = true;
      web-devicons.enable = true;

      render-markdown.enable = true;
      render-markdown.autoLoad = true;

      avante.enable = config.isDesktop; # too big (pulls in rust/llvm)
      avante.settings = {
        provder = "openai";
        auto_suggestions_provider = "openai";
        behaviour = {
          auto_suggestions = false;
          auto_set_highlight_group = true;
          auto_set_keymaps = true;
          auto_apply_diff_after_generation = false;
          support_paste_from_clipboard = false;
          minimize_diff = true;
          enable_token_counting = true;
          enable_cursor_planning_mode = true;
        };
        hints = {
          enabled = true;
        };
      };
      nui.enable = true;

      #telescope.enable = true;
      fzf-lua.enable = true;
      fzf-lua.keymaps = {
        "<C-/>" = "live_grep";
        "<C-p>" = "files";
      };

      openscad.enable = config.isDesktop; # bruh... pulls in cups + gtk + qt and morjek:wweb-devicons
      #copilot-vim.enable = true;
      gitgutter.enable = true;
    };

    extraPlugins = plugins;
  };

  environment.variables = {
    EDITOR = "vim";
  };

  environment.systemPackages = with pkgs; [
    ripgrep

    # should all my machines really have nix tooling???
    nil
    nixfmt-rfc-style
  ];

  programs.neovim = {
    enable = false;

    withRuby = true;
    withPython3 = true;
    withNodeJs = true;

    defaultEditor = true;
    vimAlias = true;
    viAlias = false;

    configure = {
      customRC = (builtins.readFile ./config/nvim/init.vim);
      packages.myVimPackage = {
        start = plugins;
      };
    };
  };
}
