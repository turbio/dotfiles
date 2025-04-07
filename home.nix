{ pkgs, lib, config, repos, ... }:
let
  stdenv = pkgs.stdenv;
  wallpaperbin = stdenv.mkDerivation {
    name = "wallpaper";
    src = repos.livewallpaper;
    buildInputs = with pkgs; [ SDL2 SDL2_gfx pkg-config clang xxd ];
    buildPhase = "cd build && make";
    installPhase = ''
      mkdir -p $out/bin
      cp walp $out/bin
      cp -r mods $out
    '';
  };
  wallpaper = stdenv.mkDerivation {
    name = "wallpaper-render";
    phases = [ "buildPhase" "installPhase" ];

    buildPhase = ''
      ${wallpaperbin}/bin/walp \
        -p ${wallpaperbin}/mods/cave_story_island.so \
        --width 2560 \
        --height 1440 \
        --bmp out.bmp \
        --once
    '';

    installPhase = ''
      cp out.bmp $out
    '';
  };
in
{

  home-manager.useGlobalPkgs = true;

  home-manager.users.turbio = { ... }: {
    home.stateVersion = "21.05";

    xdg.configFile = lib.mkMerge [
      {
        "tmux/tmux.conf".source = ./config/tmux/tmux.conf;

        "nvim/tmp/undo/.keep".text = "";
        "nvim/tmp/backup/.keep".text = "";
        "nvim/tmp/swap/.keep".text = "";

        "fish/functions/fish_prompt.fish".source = ./config/fish/functions/fish_prompt.fish;
      }

      (lib.mkIf config.isDesktop {
        # bspwm
        "bspwm/bspwmrc".source = ./config/bspwm/bspwmrc;
        "sxhkd/sxhkdrc".source = ./config/sxhkd/sxhkdrc;

        "alacritty/alacritty.toml".source = ./config/alacritty/alacritty.toml;
        "dunstrc".source = ./config/dunstrc;
        "mako/config".source = ./config/mako/config;
        "wofi/config".text = ''
          term=alacritty
          location=top
          yoffset=180
          width=30%
          lines=11

          prompt=
          show=drun
          insensitive=true
          allow_images=true
          hide_scroll=true

          aways_parse_args=true
          show_all=true
        '';
        "wofi/style.css".text = ''
                    window {
              margin: 0px;
              border: 5px solid #1e1e2e;
              background-color: #cdd6f4;
              border-radius: 15px;
          }

          #input {
              padding: 4px;
              margin: 4px;
              padding-left: 20px;
              border: none;
              color: #cdd6f4;
              font-weight: bold;
              background-color: #1e1e2e;
              outline: none;
              border-radius: 15px;
              margin: 10px;
              margin-bottom: 2px;
          }
          #input:focus {
              border: 0px solid #1e1e2e;
              margin-bottom: 0px;
          }

          #inner-box {
              margin: 4px;
              border: 10px solid #1e1e2e;
              color: #cdd6f4;
              font-weight: bold;
              background-color: #1e1e2e;
              border-radius: 15px;
          }

          #outer-box {
              margin: 0px;
              border: none;
              border-radius: 15px;
              background-color: #1e1e2e;
          }

          #scroll {
              margin-top: 5px;
              border: none;
              border-radius: 15px;
              margin-bottom: 5px;
              /* background: rgb(255,255,255); */
          }

          #img:selected {
              background-color: #89b4fa;
              border-radius: 15px;
          }

          #text:selected {
              color: #cdd6f4;
              margin: 0px 0px;
              border: none;
              border-radius: 15px;
              background-color: #89b4fa;
          }

          #entry {
              margin: 0px 0px;
              border: none;
              border-radius: 15px;
              background-color: transparent;
          }

          #entry:selected {
              margin: 0px 0px;
              border: none;
              border-radius: 15px;
              background-color: #89b4fa;
          }

        '';
        "niri/config.kdl".source = ./config/niri/config.kdl;
        "wallpaper".source = wallpaper;
        "sway/config".text = (
          builtins.replaceStrings
            [ "NIX_REPLACE_WALLPAPER" "NIX_REPLACE_GNOME_POLKIT" ]
            [ (builtins.toString wallpaper) ("${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1") ]
            (builtins.readFile ./config/sway/config)
        );
        "waybar/config".text =
          builtins.replaceStrings
            [ "NIX_WAYBAR_YUBI_EXEC" "NIX_WAYBAR_YUBI_ONCLICK" ]
            [
              (builtins.toString (pkgs.writeShellScript "yubi-waybar-status"
                ''
                  last=xxxxxx
                  ${pkgs.systemd}/bin/udevadm monitor \
                    --udev \
                    --subsystem-match=usb \
                    --tag-match=security-device \
                    | while read l; do
                      if [[ "$l" == *"add"* ]]; then
                        ykout="$(${pkgs.yubikey-manager}/bin/ykman list)";
                        if [[ "$ykout" != "" ]]; then
                          last="$(echo $l | awk '{print $4}')";
                          text=$(echo -n "$ykout" | sed 's/^\(.\+\) (.* \([0-9]\+\)$/\1 \2/')
                          echo '{"text": "'"$text"'", "alt": "key"}';
                        fi
                      elif [[ "$l" == *"remove"* ]] && [[ "$l" == *"$last"* ]]; then
                        echo;
                      fi
                    done
                ''
              ))

              (builtins.toString (pkgs.writeShellScript "yubi-waybar-click"
                ''
                  ${pkgs.alacritty}/bin/alacritty \
                    --title 'Yubikey Oath Codes' \
                    --command sh -c " \
                      echo Yubikey Oath Codes; \
                      printf %80s |tr ' ' '-'; \
                      echo -en 'Loading codoes...\r'; \
                      ${pkgs.yubikey-manager}/bin/ykman oath accounts code; \
                      read";
                ''
              ))
            ]
            (builtins.readFile ./config/waybar/config)
        ;
        "waybar/mediaplayer.py".source = ./config/waybar/mediaplayer.py;
        "waybar/style.css".source = ./config/waybar/style.css;
      })
    ];

    programs.direnv = {
      enable = true;
      nix-direnv.enable = true;
    };

    programs.fish = {
      enable = true;
      shellAliases = {
        lsa = "ls --color=auto -A";
        lsl = "ls --color=auto -l";
        lsal = "ls --color=auto -l -A";
        lsla = "ls --color=auto -l -A";
        ls = "ls --color=auto";

        grep = "grep --color=auto";

        gst = "git status -sb";
        gdf = "git diff";
        gdfc = "git diff --cached";
        gcm = "git commit -m";
        gad = "git add -A";
        gp = "git push --set-upstream origin (git rev-parse --abbrev-ref HEAD)";
        mkdirdate = ''mkdir "$(date +"%Y_%m_%d")"'';
      };

      shellInit = ''
        set fish_color_autosuggestion black --bold
        set fish_color_command green
        set fish_color_error red

        function fish_mode_prompt
        end

        fish_vi_key_bindings
        bind \cj down-or-search
        bind -M insert \cj down-or-search

        bind \ck up-or-search
        bind -M insert \ck up-or-search

        bind -M insert jk "if commandline -P; commandline -f cancel; else; set fish_bind_mode default; commandline -f backward-char force-repaint; end"

        bind -M insert \cz fg
        bind \cz fg

        function fish_greeting
            echo -ne "\
         ┌──────────────────────────────────┐
         │ Curse your sudden but inevitable │
         │ betrayal.                        │
         └────╮─────────────────────────────┘
              \e[0m│\e[0;32m                        .       .
              \e[0m│\e[0;32m                       / \`.   .' \"
              \e[0m│\e[0;32m               .---.  <    > <    >  .---.
              \e[0m│\e[0;32m               |    \\  \\ - ~ ~ - /  /    |
              \e[0m│\e[1;30m   _____\e[0;32m        \\  ..-~             ~-..-~
              \e[0m╰\e[1;30m  |     |\e[0;32m   \\~~~\\.'                    \`./~~~/
               \e[1;30m ---------\e[0;32m   \\__/                        \\__/
               .'  O    \\     /               /       \\  \"
              (_____,    `._.'               |         }  \\/~~~/
               `----.          /       }     |        /    \\__/
                     `-.      |       /      |       /      \`. ,~~|
                         ~-.__|      /_ - ~ ^|      /- _      \`..-'
                              |     /        |     /     ~-.     \`-._  _  _
                              |_____|        |_____|         ~ - . _ _ _ _ _>\e[0m\n"
        end
      '';
    };

    programs.zsh = {
      enable = true;
      autosuggestion.enable = true;
      plugins = [
        {
          name = "zsh-syntax-highlighting";
          src = repos.zsh-syntax-highlighting;
        }
        {
          name = "zsh-history-substring-search";
          src = repos.zsh-history-substring-search;
        }
      ];
      initExtra = (builtins.readFile ./config/zsh/zshrc);
    };

    home.sessionVariables = {
      MOZ_ENABLE_WAYLAND = "1";
      XDG_CURRENT_DESKTOP = "sway";
      CLUTTER_BACKEND = "wayland";
      _JAVA_AWT_WM_NONREPARENTING = "1";
    };

    programs.nix-index.enable = true;

    programs.git = {
      lfs = {
        enable = true;
      };
      enable = true;
      userEmail = "git@turb.io";
      userName = "turbio";
      extraConfig = {
        pull = { ff = "only"; };
        init = { defaultBranch = "master"; };
        safe = { directory = "/etc/nixos"; };
      };
    };

    programs.firefox = lib.mkIf config.isDesktop {
      enable = true;
      package = pkgs.firefox-wayland;
      profiles."lbgu1zmc.default" = {
        extensions = with pkgs.nur.repos.rycee.firefox-addons; [
          tree-style-tab
          metamask
          ublock-origin
        ];
        settings = {
          "toolkit.legacyUserProfileCustomizations.stylesheets" = true;
          "browser.toolbars.bookmarks.visibility" = "never";
          "browser.uiCustomization.state" = ''
            {"placements":{"widget-overflow-fixed-list":[],"unified-extensions-area":["ublock0_raymondhill_net-browser-action","webextension_metamask_io-browser-action"],"nav-bar":["back-button","forward-button","stop-reload-button","urlbar-container","downloads-button","fxa-toolbar-menu-button","treestyletab_piro_sakura_ne_jp-browser-action","_d634138d-c276-4fc8-924b-40a0ea21d284_-browser-action","unified-extensions-button"],"toolbar-menubar":["menubar-items"],"TabsToolbar":["firefox-view-button","tabbrowser-tabs","new-tab-button","alltabs-button"],"PersonalToolbar":["import-button","personal-bookmarks"]},"seen":["save-to-pocket-button","developer-button","treestyletab_piro_sakura_ne_jp-browser-action","_d634138d-c276-4fc8-924b-40a0ea21d284_-browser-action","ublock0_raymondhill_net-browser-action","webextension_metamask_io-browser-action"],"dirtyAreaCache":["nav-bar","PersonalToolbar","unified-extensions-area","toolbar-menubar","TabsToolbar"],"currentVersion":20,"newElementCount":7}
          '';
        };
        userChrome = ''
          /* Hide tab bar in FF Quantum */
          #TabsToolbar {
            visibility: collapse !important;
            margin-bottom: 21px !important;
          }

          #sidebar-box[sidebarcommand="treestyletab_piro_sakura_ne_jp-sidebar-action"] #sidebar-header {
            visibility: collapse !important;
          }
        '';
      };
    };

    gtk = lib.mkIf
      config.isDesktop
      {
        enable = true;
        font.package = pkgs.terminus_font;
        font.name = "Terminus";
        font.size = 9;

        theme.package = pkgs.arc-theme;
        theme.name = "Arc-Dark";
      };

    home.pointerCursor = lib.mkIf config.isDesktop {
      name = "Adwaita";
      package = pkgs.gnome.adwaita-icon-theme;
      x11 = {
        enable = true;
        defaultCursor = "Adwaita";
      };
    };


    home.sessionPath = [
      "${./bin}"
    ];
  };
}
