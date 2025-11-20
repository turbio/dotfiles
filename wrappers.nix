{ pkgs, lib, ... }:
{
  ghostty = {
    settings = {
      background = "272822";
      foreground = "ffffff";

      cursor-color = "ffffff";
      cursor-text = "000000";

      palette = [
        "0=#272822"
        "1=#F92672"
        "2=#82B414"
        "3=#FD971F"
        "4=#268BD2"
        "5=#8C54FE"
        "6=#56C2D5"
        "7=#FFFFFF"

        "8=#5C5C5C"
        "9=#FF5995"
        "10=#A6E22E"
        "11=#E6DB74"
        "12=#62ADE3"
        "13=#AE81FF"
        "14=#66D9EF"
        "15=#CCCCCC"
      ];

      bold-is-bright = true;

      confirm-close-surface = false;

      font-family = "Terminus (TTF)";
      font-size = 9;
      font-style-italic = "Bold";
      adjust-cell-height = -2;

      window-width = 80;
      window-height = 24;

      window-padding-x = 2;
      window-padding-y = 2;

      mouse-scroll-multiplier = 3;
    };
  };
  mako = {
    config.path = ./config/mako/config;
  };
  fuzzel = {
    settings = {
      main = {
        font = "terminus:size=13,monospace";
      };
    };
  };
  alacritty = {
    settings = {
      bell = {
        animation = "EaseOutExpo";
        duration = 0;
      };
      colors = {
        draw_bold_text_with_bright_colors = true;
      };
      colors.bright = {
        black = "0x5C5C5C";
        blue = "0x62ADE3";
        cyan = "0x66D9EF";
        green = "0xA6E22E";
        magenta = "0xAE81FF";
        red = "0xFF5995";
        white = "0xCCCCCC";
        yellow = "0xE6DB74";
      };
      colors.cursor = {
        cursor = "0xffffff";
        text = "0x000000";
      };
      colors.normal = {
        black = "0x272822";
        blue = "0x268BD2";
        cyan = "0x56C2D5";
        green = "0x82B414";
        magenta = "0x8C54FE";
        red = "0xF92672";
        white = "0xffffff";
        yellow = "0xFD971F";
      };
      colors.primary = {
        background = "0x272822";
        foreground = "0xffffff";
      };
      font.size = 7;
      font.bold = {
        family = "Terminus";
        style = "Bold";
      };
      font.glyph_offset = {
        x = 0;
        y = 0;
      };
      font.italic = {
        family = "Terminus";
        style = "Bold";
      };
      font.normal = {
        family = "Terminus";
        style = "normal";
      };
      font.offset = {
        x = 0;
        y = 0;
      };
      mouse.bindings = [
        {
          action = "PasteSelection";
          mouse = "Middle";
        }
      ];
      selection = {
        semantic_escape_chars = '',?`|:"' ()[]{}<>'';
      };
      window.dimensions = {
        columns = 80;
        lines = 24;
      };
      window.padding = {
        x = 2;
        y = 2;
      };
      scrolling.multiplier = 4;
    };
  };
  waybar = {
    settings = import ./waybar.nix { inherit pkgs lib; };
    style.path = ./config/waybar/style.css;
  };
  niri = {
    "config.kdl".content = ''
      input {
          touchpad {
              tap
              click-method "clickfinger"
          }

          focus-follows-mouse max-scroll-amount="10%"
      }

      output "eDP-1" {
          scale 1.0
      }

      layout {
          gaps 10
          center-focused-column "never"

          shadow {
              on
          }

          struts {
              left 20
              right 20
          }

          preset-column-widths {
              proportion 0.33333
              proportion 0.5
              proportion 0.66667
          }

          default-column-width { proportion 0.5; }

          border {
              width 2
              active-color "#7fc8ff"
              inactive-color "#505050"
          }

          focus-ring {
              off
          }
      }

      prefer-no-csd

      screenshot-path null

      animations {
          slowdown 0.5
      }

      window-rule {
          open-floating true

          geometry-corner-radius 6
          clip-to-geometry true
      }

      window-rule {
          match title="Syncthing Tray"
          open-floating true
          default-floating-position x=10 y=10 relative-to="top-right"
      }

      binds {
          Mod+Shift+Slash { show-hotkey-overlay; }

          Mod+Return { spawn "${lib.getExe pkgs.alacritty}"; }
          Mod+Space { spawn "${lib.getExe pkgs.fuzzel}"; }

          XF86AudioRaiseVolume allow-when-locked=true { spawn "${pkgs.wireplumber}/bin/wpctl" "set-volume" "@DEFAULT_AUDIO_SINK@" "0.1+"; }
          XF86AudioLowerVolume allow-when-locked=true { spawn "${pkgs.wireplumber}/bin/wpctl" "set-volume" "@DEFAULT_AUDIO_SINK@" "0.1-"; }
          XF86AudioMute        allow-when-locked=true { spawn "${pkgs.wireplumber}/bin/wpctl" "set-mute" "@DEFAULT_AUDIO_SINK@" "toggle"; }
          XF86AudioMicMute     allow-when-locked=true { spawn "${pkgs.wireplumber}/bin/wpctl" "set-mute" "@DEFAULT_AUDIO_SOURCE@" "toggle"; }
          XF86AudioPlay        allow-when-locked=true { spawn "${lib.getExe pkgs.playerctl}" "play-pause"; }
          XF86AudioNext        allow-when-locked=true { spawn "${lib.getExe pkgs.playerctl}" "next"; }
          XF86AudioPrev        allow-when-locked=true { spawn "${lib.getExe pkgs.playerctl}" "previous"; }

          Mod+Q { close-window; }

          Mod+H     { focus-column-left; }
          Mod+J     { focus-window-or-workspace-down; }
          Mod+K     { focus-window-or-workspace-up; }
          Mod+L     { focus-column-right; }

          Mod+Shift+H     { move-column-left; }
          Mod+Shift+J     { move-window-down-or-to-workspace-down; }
          Mod+Shift+K     { move-window-up-or-to-workspace-up; }
          Mod+Shift+L     { move-column-right; }

          Mod+Home { focus-column-first; }
          Mod+End  { focus-column-last; }
          Mod+Ctrl+Home { move-column-to-first; }
          Mod+Ctrl+End  { move-column-to-last; }

          Mod+Ctrl+H     { focus-monitor-left; }
          Mod+Ctrl+J     { focus-monitor-down; }
          Mod+Ctrl+K     { focus-monitor-up; }
          Mod+Ctrl+L     { focus-monitor-right; }

          Mod+Shift+Ctrl+Left  { move-column-to-monitor-left; }
          Mod+Shift+Ctrl+Down  { move-column-to-monitor-down; }
          Mod+Shift+Ctrl+Up    { move-column-to-monitor-up; }
          Mod+Shift+Ctrl+Right { move-column-to-monitor-right; }
          Mod+Shift+Ctrl+H     { move-column-to-monitor-left; }
          Mod+Shift+Ctrl+J     { move-column-to-monitor-down; }
          Mod+Shift+Ctrl+K     { move-column-to-monitor-up; }
          Mod+Shift+Ctrl+L     { move-column-to-monitor-right; }

          Mod+O      { focus-workspace-down; }
          Mod+I        { focus-workspace-up; }
          Mod+Shift+O         { move-workspace-down; }
          Mod+Shift+I         { move-workspace-up; }

          Mod+Ctrl+Shift+O         { move-workspace-to-monitor-right; }
          Mod+Ctrl+Shift+I         { move-workspace-to-monitor-left; }

          Mod+WheelScrollDown      cooldown-ms=150 { focus-workspace-down; }
          Mod+WheelScrollUp        cooldown-ms=150 { focus-workspace-up; }
          Mod+Ctrl+WheelScrollDown cooldown-ms=150 { move-column-to-workspace-down; }
          Mod+Ctrl+WheelScrollUp   cooldown-ms=150 { move-column-to-workspace-up; }

          Mod+WheelScrollRight      { focus-column-right; }
          Mod+WheelScrollLeft       { focus-column-left; }
          Mod+Ctrl+WheelScrollRight { move-column-right; }
          Mod+Ctrl+WheelScrollLeft  { move-column-left; }

          Mod+Shift+WheelScrollDown      { focus-column-right; }
          Mod+Shift+WheelScrollUp        { focus-column-left; }
          Mod+Ctrl+Shift+WheelScrollDown { move-column-right; }
          Mod+Ctrl+Shift+WheelScrollUp   { move-column-left; }

          Mod+T       { move-window-to-tiling; }
          Mod+S       { move-window-to-floating; }

          Mod+1 { focus-workspace 1; }
          Mod+2 { focus-workspace 2; }
          Mod+3 { focus-workspace 3; }
          Mod+4 { focus-workspace 4; }
          Mod+5 { focus-workspace 5; }
          Mod+6 { focus-workspace 6; }
          Mod+7 { focus-workspace 7; }
          Mod+8 { focus-workspace 8; }
          Mod+9 { focus-workspace 9; }
          Mod+Ctrl+1 { move-column-to-workspace 1; }
          Mod+Ctrl+2 { move-column-to-workspace 2; }
          Mod+Ctrl+3 { move-column-to-workspace 3; }
          Mod+Ctrl+4 { move-column-to-workspace 4; }
          Mod+Ctrl+5 { move-column-to-workspace 5; }
          Mod+Ctrl+6 { move-column-to-workspace 6; }
          Mod+Ctrl+7 { move-column-to-workspace 7; }
          Mod+Ctrl+8 { move-column-to-workspace 8; }
          Mod+Ctrl+9 { move-column-to-workspace 9; }

          Mod+BracketLeft  { consume-or-expel-window-left; }
          Mod+BracketRight { consume-or-expel-window-right; }

          Mod+Comma  { consume-window-into-column; }
          Mod+Period { expel-window-from-column; }

          Mod+R { switch-preset-column-width; }
          Mod+Shift+R { switch-preset-window-height; }
          Mod+Ctrl+R { reset-window-height; }
          Mod+F { maximize-column; }
          Mod+Shift+F { fullscreen-window; }
          Mod+C { center-column; }

          Mod+Minus { set-column-width "-10%"; }
          Mod+Equal { set-column-width "+10%"; }
          Mod+Shift+Minus { set-window-height "-10%"; }
          Mod+Shift+Equal { set-window-height "+10%"; }

          Mod+Slash {
              spawn "${./bin/niri-rename-workspace}";
          }
      }

      spawn-at-startup "${lib.getExe pkgs.waybar}"
      spawn-at-startup "${lib.getExe pkgs.mako}"
      spawn-at-startup "${lib.getExe pkgs.xwayland-satellite}"
      spawn-at-startup "${lib.getExe pkgs.swaybg}" "-i" ".config/wallpaper"
      spawn-at-startup "${lib.getExe pkgs.swayidle}" "-w" "timeout" "300" "niri msg action power-off-monitors"

      environment {
          QT_QPA_PLATFORM "wayland"
          DISPLAY ":0"
      }
    '';
  };
}
