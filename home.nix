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
      }

      (lib.mkIf config.isDesktop {
        "bspwm/bspwmrc".source = ./config/bspwm/bspwmrc;
        "sxhkd/sxhkdrc".source = ./config/sxhkd/sxhkdrc;

        "alacritty/alacritty.yml".source = ./config/alacritty/alacritty.yml;
        "dunstrc".source = ./config/dunstrc;
        "mako/config".source = ./config/mako/config;
        "sway/config".text = (
          builtins.replaceStrings
            [ "NIX_REPLACE_WALLPAPER" ]
            [ (builtins.toString wallpaper) ]
            (builtins.readFile ./config/sway/config)
        );
        "hypr/hyprland.conf".text =

          builtins.replaceStrings
            [ "NIX_REPLACE_WALLPAPER" ]
            [ (builtins.toString wallpaper) ]

            ''
              # This is an example Hyprland config file.
              # Syntax is the same as in Hypr, but settings might differ.
              #
              # Refer to the wiki for more information.

              #monitor=,1280x720@60,0x0,1
              #workspace=DP-1,1

              input {
                  kb_layout=
                  kb_variant=
                  kb_model=
                  kb_options=
                  kb_rules=

                  follow_mouse=1
              }

              general {
                  max_fps=60 # deprecated, unused
                  sensitivity=1
                  main_mod=SUPER

                  gaps_in=5
                  gaps_out=20
                  border_size=2
                  col.active_border=0xff7f7f7f
                  col.inactive_border=0xff303030

                  damage_tracking=full
              }

              decoration {
                  rounding=10
                  blur=1
                  blur_size=3 # minimum 1
                  blur_passes=1 # minimum 1, more passes = more resource intensive.
                  # Your blur "amount" is blur_size * blur_passes, but high blur_size (over around 5-ish) will produce artifacts.
                  # if you want heavy blur, you need to up the blur_passes.
                  # the more passes, the more you can up the blur_size without noticing artifacts.
                  multisample_edges=1
              }

              animations {
                  enabled=1
                  animation=windows,1,7,default
                  animation=borders,1,10,default
                  animation=fadein,1,10,default
                  animation=workspaces,1,6,default
              }

              dwindle {
                  pseudotile=0 # enable pseudotiling on dwindle
              }

              exec-once=waybar
              exec-once=kitty
              exec-once=swaybg -i NIX_REPLACE_WALLPAPER

              windowrule=float,.*

              bind=SUPER,RETURN,exec,kitty
              bind=SUPER,Q,killactive,
              bind=SUPERSHIFT,Q,exit,
              bind=SUPER,S,togglefloating,
              bind=SUPER,F,fullscreen,1

              bind=SUPER,h,movefocus,l
              bind=SUPER,l,movefocus,r
              bind=SUPER,k,movefocus,u
              bind=SUPER,j,movefocus,d

              bind=SUPER,I,workspace,-1
              bind=SUPER,O,workspace,+1

              bind=SUPERSHIFT,I,movetoworkspace,-1
              bind=SUPERSHIFT,O,movetoworkspace,+1
            '';
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

    programs.zsh = {
      enable = true;
      enableAutosuggestions = true;
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
      EDITOR = "vim";
      MOZ_ENABLE_WAYLAND = "1";
      XDG_CURRENT_DESKTOP = "sway";
      CLUTTER_BACKEND = "wayland";
      _JAVA_AWT_WM_NONREPARENTING = "1";
    };

    imports = [
      (m@{ pkgs, ... }: import ./vim.nix (m // { inherit repos; }))
    ];

    programs.nix-index.enable = true;

    programs.git = {
      enable = true;
      userEmail = "git@turb.io";
      userName = "turbio";
      extraConfig = {
        pull = { ff = "only"; };
        init = { defaultBranch = "master"; };
        safe = { directory = "/etc/nixos"; };
      };
    };

    programs.firefox = {
      enable = true;
      package = pkgs.firefox-wayland;
      profiles."lbgu1zmc.default".userChrome = ''
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

    home.sessionPath = [
      "${./bin}"
    ];
  };
}
