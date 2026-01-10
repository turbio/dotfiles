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
    "custom/kbd-toggle"
    "idle_inhibitor"
    "temperature"
    "memory"
    "cpu"
    "custom/yubi"
    "custom/tailscale"
    "backlight"
    "network"
    "bluetooth"
    "pulseaudio"
    "battery"
    "clock"
    "custom/hostname"
    "tray"
  ];

  temperature = {
    critical-threshold = 80;
    format = "{temperatureC}°C ";
  };

  cpu = {
    interval = 10;
    format = "{usage:02}% ";
  };

  memory = {
    interval = 30;
    format = "{}% ";
  };

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

        while true; do
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
          sleep 1
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
    exec = "${lib.getExe pkgs.tailscale} status --json | jq --unbuffered --compact-output '.Self.TailscaleIPs | first | if . then {text: ., alt: \"connected\"} else {text: \"disconnected\", alt: \"disconnected\"} end'";
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
