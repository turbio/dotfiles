# Shared nixvim configuration
# Used by both NixOS module (vim.nix) and standalone package (flake.nix)
{
  pkgs,
  repos,
  isDesktop ? false,
}:
let
  extraVimPlugins =
    with pkgs.vimPlugins;
    [
      nvim-nio
      plenary-nvim
      popup-nvim
      codewindow-nvim

      (pkgs.vimUtils.buildVimPlugin {
        pname = "muble";
        version = "1";
        src = repos.muble-vim;
      })
    ]
    ++ (if pkgs.stdenv.hostPlatform == "x86_64-linux" then [ vim-go ] else [ ]);
in
{
  extraPackages = with pkgs; [
    ripgrep
    nixfmt-rfc-style
  ];

  vimAlias = true;
  viAlias = false;

  opts.laststatus = 2;

  extraConfigVim = (builtins.readFile ./config/nvim/init.vim);

  plugins = {
    copilot-vim.enable = true;
    direnv.enable = true;
    lspconfig.enable = true;
    web-devicons.enable = true;

    treesitter = {
      enable = true;
    };

    render-markdown.enable = true;
    render-markdown.autoLoad = true;

    nui.enable = true;

    fzf-lua = {
      enable = true;
      keymaps = {
        "<C-/>" = "live_grep";
        "<C-p>" = "files";
      };
    };

    openscad.enable = isDesktop;

    lightline = {
      enable = true;
      settings.component_function.filename = "LightlineFilename";
    };

    fugitive.enable = true;
    sleuth.enable = true;
    dressing.enable = true;
    endwise.enable = true;
    comment.enable = true;

    undotree = {
      enable = true;
      settings = {
        SplitWidth = 30;
        DiffAutoOpen = 0;
        WindowLayout = 3;
      };
    };

    gitgutter = {
      enable = true;
      settings = {
        realtime = 0;
        eager = 0;
        sign_added = "+";
        sign_modified = "~";
        sign_removed = "-";
        sign_modified_removed = "~";
        sign_removed_first_line = "^";
      };
    };

    lsp-signature = {
      enable = true;
      settings = {
        handler_opts.border = "rounded";
        hint_prefix = {
          above = "↙ ";
          current = "← ";
          below = "↖ ";
        };
      };
    };

    trouble = {
      enable = true;
      settings.icons.enabled = false;
    };

    indent-blankline = {
      enable = true;
      settings.indent = {
        char = "┊";
        tab_char = "┊";
      };
    };

    cmp = {
      enable = true;
      autoEnableSources = true;
      settings = {
        preselect = "cmp.PreselectMode.None";
        window = {
          completion = {
            border = "rounded";
            scrollbar = true;
            winhighlight = "Normal:Normal,FloatBorder:FloatBorder,CursorLine:Visual,Search:None";
          };
          documentation = {
            border = "rounded";
            scrollbar = true;
            winhighlight = "Normal:Normal,FloatBorder:FloatBorder,CursorLine:Visual,Search:None";
          };
        };
        mapping = {
          "<Tab>" = "cmp.mapping.confirm({ select = false })";
          "<C-Space>" = "cmp.mapping.complete()";
          "<C-e>" = "cmp.mapping.abort()";
          "<C-j>" = "cmp.mapping.select_next_item({ behavior = cmp.SelectBehavior.Insert })";
          "<C-k>" = "cmp.mapping.select_prev_item({ behavior = cmp.SelectBehavior.Insert })";
        };
        sources = [
          { name = "nvim_lsp"; }
        ];
      };
    };

    neo-tree = {
      enable = true;
      settings = {
        window = {
          width = 30;
          mappings = {
            "/" = "none";
          };
        };
        filesystem = {
          window = {
            mappings = {
              "/" = "none";
            };
          };
        };
      };
    };

    lsp-lines.enable = true;
  };

  lsp.inlayHints.enable = false;
  lsp.servers = {
    clangd.enable = true;
    gopls.enable = true;
    rust_analyzer.enable = true;
    hls.enable = true;
    ts_ls.enable = true;
    bashls.enable = true;
    nushell.enable = true;
    nixd.enable = true;
  };

  extraPlugins = extraVimPlugins;
}
