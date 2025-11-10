{ pkgs, ... }: {
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
    on-scroll-down = "light -U 1";
    on-scroll-up = "light -A 1";
    states = [
      0
      50
    ];
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
    exec = "waybar-mpris --autofocus --play ' ' --pause ' ' --order SYMBOL:ARTIST:TITLE";
    on-click = "waybar-mpris --send toggle";
    on-scroll-up = "waybar-mpris --send player-next";
    on-scroll-down = "waybar-mpris --send player-prev";
    escape = true;
  };

  "custom/tailscale" = {
    exec = "tailscale status --json | jq --unbuffered --compact-output '.Self.TailscaleIPs | first | if . then {text: ., alt: \"connected\"} else {text: \"disconnected\", alt: \"disconnected\"} end'";
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
    format-wifi = " {essid} ({signalStrength}%)";
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
        ""
        ""
        ""
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
