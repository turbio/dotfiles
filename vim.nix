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
      nvim-lspconfig
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
    nixpkgs.pkgs = pkgs;

    enable = true;

    vimAlias = true;
    viAlias = false;

    opts.laststatus = 2;

    extraConfigVim = (builtins.readFile ./config/nvim/init.vim);

    plugins = {
      # minuet.enable = true;
      # minuet.settings = {
      #   n_completions = 5;
      #   context_window = 1024;
      #   provider = "openai_fim_compatible";
      #   provider_options = {
      #     openai_fim_compatible = {
      #       api_key = "TERM";
      #       #end_point = "http://ollama.int.turb.io/v1/completions";
      #       end_point = "http://localhost:11434/v1/completions";
      #       name = "llm";
      #       model = "qwen2.5-coder:1.5b";
      #       stream = true;
      #       optional = {
      #         max_tokens = 245;
      #         top_p = 0.9;
      #         stop = [ "\n\n" ];
      #       };
      #     };
      #   };

      #   # virtualtext = {
      #   #   auto_trigger_ft = [ "*" ];
      #   #   show_on_completion_menu = true;
      #   #   keymap = {
      #   #     accept = "<C-j>";
      #   #   };
      #   # };
      # };
      copilot-vim.enable = true;

      direnv.enable = true;

      lsp.enable = true;
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

    extraPlugins = plugins;
  };

  environment.variables = {
    EDITOR = "vim";
  };

  environment.systemPackages = with pkgs; [
    ripgrep

    # should all my machines really have nix tooling???
    nixd
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
