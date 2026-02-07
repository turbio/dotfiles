{ pkgs, lib, ... }:
{
  position = "top";
  height = 30;
  layer = "top";
  modules-center = [ ];
  modules-left = [
    "sway/workspaces"
    "niri/workspaces"
  ];
  modules-right = [
    "custom/media"
    "custom/claude"
    "idle_inhibitor"
    "custom/kbd-toggle"
    "custom/yubi"
    "custom/tailscale"
    "network"
    "bluetooth"
    "pulseaudio"
    "backlight"
    "battery"
    "clock"
    "custom/hostname"
    "tray"
  ];

  backlight = {
    format = "{percent}% {icon}";
    format-icons = [
      ""
      ""
    ];
    scroll-step = 1;
  };

  battery = {
    format = "{capacity}% {icon}";
    format-alt = "{time} {icon}";
    format-charging = "{capacity}% 󰂄";
    format-icons = [
      "󰁺"
      "󰁼"
      "󰁾"
      "󰂀"
      "󰁹"
    ];
    format-plugged = "{capacity}% ";
    states = {
      critical = 15;
      warning = 30;
    };
  };

  bluetooth = {
    format = " {status}";
    format-connected = " {device_alias}";
    format-connected-battery = " {device_alias} {device_battery_percentage}%";
    on-click = "blueberry";
  };

  clock = {
    format = "{:%H:%M %Z}";
    format-alt = "{:%H:%M %Y-%m-%d %Z}";
    tooltip-format = ''
      <big>{:%Y %B}</big>
      <tt><small>{calendar}</small></tt>'';
  };

  "custom/hostname" = {
    exec = "hostname";
    format = "{}";
    interval = "once";
  };

  "custom/claude" = {
    exec = builtins.toString (
      pkgs.writeShellScript "claude-waybar-status" ''
        JQ="${lib.getExe pkgs.jq}"
        CURL="${lib.getExe pkgs.curl}"
        INOTIFYWAIT="${lib.getExe' pkgs.inotify-tools "inotifywait"}"
        CREDS="$HOME/.claude/.credentials.json"
        PROJECTS="$HOME/.claude/projects"

        fetch_usage() {
          if [ ! -f "$CREDS" ]; then
            echo ""
            return
          fi

          OAUTH=$($JQ -r '.claudeAiOauth' "$CREDS")
          TOKEN=$(echo "$OAUTH" | $JQ -r '.accessToken // empty')
          EXPIRES=$(echo "$OAUTH" | $JQ -r '.expiresAt // 0')

          if [ -z "$TOKEN" ]; then
            echo ""
            return
          fi

          # refresh token if expiring within 5 minutes
          NOW_MS=$(date +%s%3N)
          if [ "$EXPIRES" -lt "$((NOW_MS + 300000))" ]; then
            REFRESH=$(echo "$OAUTH" | $JQ -r '.refreshToken // empty')
            if [ -n "$REFRESH" ]; then
              RESP=$($CURL -sf -X POST "https://console.anthropic.com/v1/oauth/token" \
                -H "Content-Type: application/x-www-form-urlencoded" \
                -d "grant_type=refresh_token&client_id=9d1c250a-e61b-44d9-88ed-5944d1962f5e&refresh_token=$REFRESH")
              if [ $? -eq 0 ] && [ -n "$RESP" ]; then
                NEW_ACCESS=$(echo "$RESP" | $JQ -r '.access_token // empty')
                NEW_REFRESH=$(echo "$RESP" | $JQ -r '.refresh_token // empty')
                EXPIRES_IN=$(echo "$RESP" | $JQ -r '.expires_in // 0')
                if [ -n "$NEW_ACCESS" ]; then
                  TOKEN="$NEW_ACCESS"
                  $JQ \
                    --arg at "$NEW_ACCESS" \
                    --arg rt "''${NEW_REFRESH:-$REFRESH}" \
                    --argjson exp "$((NOW_MS + EXPIRES_IN * 1000))" \
                    '.claudeAiOauth.accessToken = $at | .claudeAiOauth.refreshToken = $rt | .claudeAiOauth.expiresAt = $exp' \
                    "$CREDS" > "$CREDS.tmp" && mv "$CREDS.tmp" "$CREDS"
                fi
              fi
            fi
          fi

          RESP=$($CURL -sf "https://api.anthropic.com/api/oauth/usage" \
            -H "Authorization: Bearer $TOKEN" \
            -H "anthropic-beta: oauth-2025-04-20")

          if [ $? -ne 0 ] || [ -z "$RESP" ]; then
            echo ""
            return
          fi

          echo "$RESP" | $JQ -c '
            def parse_ts: sub("\\.[0-9]+"; "") | sub("[+-]00:00$"; "Z") | fromdateiso8601;
            def countdown(reset):
              ((reset | parse_ts) - now | floor) as $s |
              if $s <= 0 then "now"
              elif $s >= 86400 then "\($s / 86400 | floor)d\($s % 86400 / 3600 | floor)h"
              else "\($s / 3600 | floor)h\($s % 3600 / 60 | floor | tostring | if length < 2 then "0" + . else . end)m"
              end;

            def pacing(pct; reset; window_s):
              (((reset | parse_ts) - now | floor)) as $left |
              (((window_s - $left) / window_s * 100) | round) as $elapsed |
              (if $elapsed > 0 then pct / $elapsed else 0 end) as $p |
              if $p > 1.05 then {icon: "↑", dev: (($p - 1) * 100 | round)}
              elif $p < 0.95 then {icon: "↓", dev: ((1 - $p) * 100 | round | (- .))}
              else {icon: "→", dev: 0}
              end + {elapsed: $elapsed};

            .five_hour as $s | .seven_day as $w |
            ($s.utilization | round) as $spct |
            ($w.utilization | round) as $wpct |
            pacing($wpct; $w.resets_at; 604800) as $wp |
            pacing($spct; $s.resets_at; 18000) as $sp |
            (if $wp.dev >= 25 or $wpct >= 90 then "critical"
             elif $wp.dev >= 10 or $wpct >= 75 then "warning"
             else "" end) as $class |
            {
              text: "\($spct)% \($sp.icon) ⧖\($sp.elapsed)% \(countdown($s.resets_at))",
              tooltip: "Weekly: \($wpct)% \($wp.icon) ⧖\($wp.elapsed)% (resets \(countdown($w.resets_at)))",
              class: $class
            }
          '
        }

        fetch_usage
        $INOTIFYWAIT -mr -e modify -e create --include '\.jsonl$' "$PROJECTS" 2>/dev/null \
          | while read -r _dir _event _file; do
              fetch_usage
            done
      ''
    );
    format = "✻ {}";
    return-type = "json";
  };

  "custom/media" = {
    return-type = "json";
    exec = "${lib.getExe pkgs.waybar-mpris} --autofocus --play ' ' --pause ' ' --order SYMBOL:ARTIST:TITLE";
    on-click = "waybar-mpris --send toggle";
    on-scroll-up = "waybar-mpris --send player-next";
    on-scroll-down = "waybar-mpris --send player-prev";
    escape = true;
  };

  "custom/kbd-toggle" = {
    exec = builtins.toString (
      pkgs.writeShellScript "kbd-toggle-status" ''
        STATE_FILE="/tmp/kbd-toggle-state"
        GRAB_PID_FILE="/tmp/kbd-toggle-grab.pid"

        get_sway_kbd_state() {
          KBD_ID=$(${pkgs.sway}/bin/swaymsg -t get_inputs -r 2>/dev/null | \
            ${pkgs.jq}/bin/jq -r '.[] | select(.type == "keyboard") | select(.name | test("AT Translated|Internal|internal")) | .identifier' | \
            head -1)
          if [ -n "$KBD_ID" ]; then
            ${pkgs.sway}/bin/swaymsg -t get_inputs -r | ${pkgs.jq}/bin/jq -r ".[] | select(.identifier == \"$KBD_ID\") | .libinput.send_events"
          fi
        }

        get_grab_state() {
          if [ -f "$GRAB_PID_FILE" ] && kill -0 "$(cat "$GRAB_PID_FILE")" 2>/dev/null; then
            echo "disabled"
          else
            echo "enabled"
          fi
        }

        output_state() {
          if [ -n "$SWAYSOCK" ]; then
            STATE=$(get_sway_kbd_state)
          else
            STATE=$(get_grab_state)
          fi

          if [ "$STATE" = "disabled" ]; then
            echo '{"text": "󰌐", "alt": "disabled", "tooltip": "Internal keyboard disabled", "class": "disabled"}'
          else
            echo '{"text": "󰌌", "alt": "enabled", "tooltip": "Internal keyboard enabled"}'
          fi
        }

        output_state

        while true; do
          if [ -n "$SWAYSOCK" ]; then
            ${pkgs.sway}/bin/swaymsg -t subscribe '["input"]' > /dev/null 2>&1 || sleep 5
          else
            ${pkgs.inotify-tools}/bin/inotifywait -qq -e create,delete /tmp --include 'kbd-toggle-grab.pid' || sleep 5
          fi
          output_state
        done
      ''
    );
    format = "{}";
    return-type = "json";
    on-click = builtins.toString (
      pkgs.writeShellScript "kbd-toggle-click" ''
        GRAB_PID_FILE="/tmp/kbd-toggle-grab.pid"

        if [ -n "$SWAYSOCK" ]; then
          # Sway: use swaymsg input control
          KBD_ID=$(${pkgs.sway}/bin/swaymsg -t get_inputs -r | \
            ${pkgs.jq}/bin/jq -r '.[] | select(.type == "keyboard") | select(.name | test("AT Translated|Internal|internal")) | .identifier' | \
            head -1)

          if [ -z "$KBD_ID" ]; then
            ${pkgs.libnotify}/bin/notify-send "Keyboard Toggle" "No internal keyboard found"
            exit 1
          fi

          STATE=$(${pkgs.sway}/bin/swaymsg -t get_inputs -r | ${pkgs.jq}/bin/jq -r ".[] | select(.identifier == \"$KBD_ID\") | .libinput.send_events")
          if [ "$STATE" = "disabled" ]; then
            ${pkgs.sway}/bin/swaymsg input "$KBD_ID" events enabled
            ${pkgs.libnotify}/bin/notify-send "Keyboard" "Internal keyboard enabled"
          else
            ${pkgs.sway}/bin/swaymsg input "$KBD_ID" events disabled
            ${pkgs.libnotify}/bin/notify-send "Keyboard" "Internal keyboard disabled"
          fi
        else
          # Niri/other: use evtest --grab to capture keyboard events
          if [ -f "$GRAB_PID_FILE" ] && kill -0 "$(cat "$GRAB_PID_FILE")" 2>/dev/null; then
            # Currently disabled, enable by killing grab process
            kill "$(cat "$GRAB_PID_FILE")" 2>/dev/null
            rm -f "$GRAB_PID_FILE"
            ${pkgs.libnotify}/bin/notify-send "Keyboard" "Internal keyboard enabled"
          else
            # Find internal keyboard device
            KBD_DEV=$(${pkgs.libinput}/bin/libinput list-devices | \
              grep -B5 -A5 -i "AT Translated\|Internal" | \
              grep "Kernel:" | head -1 | awk '{print $2}')

            if [ -z "$KBD_DEV" ]; then
              ${pkgs.libnotify}/bin/notify-send "Keyboard Toggle" "No internal keyboard found"
              exit 1
            fi

            # Grab keyboard in background (requires input group membership)
            ${pkgs.evtest}/bin/evtest --grab "$KBD_DEV" > /dev/null 2>&1 &
            echo $! > "$GRAB_PID_FILE"
            ${pkgs.libnotify}/bin/notify-send "Keyboard" "Internal keyboard disabled"
          fi
        fi
      ''
    );
  };

  "custom/tailscale" = {
    exec = builtins.toString (
      pkgs.writeShellScript "tailscale-waybar-status" ''
        output_state() {
          ${lib.getExe pkgs.tailscale} status --json 2>/dev/null | \
            ${pkgs.jq}/bin/jq --unbuffered --compact-output \
              '.Self.TailscaleIPs | first | if . then {text: ., alt: "connected"} else {text: "disconnected", alt: "disconnected"} end'
        }

        output_state

        ${pkgs.iproute2}/bin/ip monitor link | while read -r line; do
          output_state
        done
      ''
    );
    format = "{icon} {text}";
    format-icons = {
      connected = "󰌘";
      default = "󰌗";
      disconnected = "󰌙";
    };
    return-type = "json";
  };

  "custom/yubi" = {
    exec = builtins.toString (
      pkgs.writeShellScript "yubi-waybar-status" ''
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
    );
    exec-if = "ykman -v";
    format = "{icon} {}";
    format-icons = {
      default = "";
      key = "";
    };
    on-click = builtins.toString (
      pkgs.writeShellScript "yubi-waybar-click" ''
        ${pkgs.alacritty}/bin/alacritty \
          --title 'Yubikey Oath Codes' \
          --command sh -c " \
            echo Yubikey Oath Codes; \
            printf %80s |tr ' ' '-'; \
            echo -en 'Loading codoes...\r'; \
            ${pkgs.yubikey-manager}/bin/ykman oath accounts code; \
            read";
      ''
    );
    return-type = "json";
  };

  network = {
    format-disconnected = "Disconnected ⚠";
    format-ethernet = "󰈀 {ifname}: {ipaddr}/{cidr}";
    format-linked = "󰈀 {ifname} (No IP)";
    format-wifi = "  {essid} ({signalStrength}%)";
    on-click = "nm-connection-editor";
  };

  "niri/workspaces" = { };

  pulseaudio = {
    format = "{volume}% {icon} {format_source}";
    format-bluetooth = "{volume}% {icon}  {format_source}";
    format-bluetooth-muted = " {icon}  {format_source}";
    format-icons = {
      car = "";
      default = [
        " "
        " "
        " "
      ];
      hands-free = "";
      headphone = "";
      headset = "";
      phone = "";
      portable = "";
    };
    format-muted = " {format_source}";
    format-source = "{volume}% ";
    format-source-muted = "";
    on-click = "pavucontrol";
  };

  "sway/workspaces" = {
    all-outputs = false;
    disable-scroll = true;
    format = "{name}";
    format-icons = {
      spotify = "";
      urgent = "";
    };
  };

  tray = {
    spacing = 10;
  };

  idle_inhibitor = {
    format = "{icon}";
    format-icons = {
      activated = "";
      deactivated = "";
    };
  };
}
