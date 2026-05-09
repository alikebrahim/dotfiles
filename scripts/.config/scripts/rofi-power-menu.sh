#!/usr/bin/env bash
set -euo pipefail

# Options for Power Menu
OPTIONS="  Lock\n󰤄  Suspend\n󰗼  Logout\n󰜉  Reboot\n󰐥  Shutdown"

# Run Rofi selection
CHOICE=$(echo -e "$OPTIONS" | rofi -dmenu -i -p "Power Menu" -config ~/.config/rofi/config.rasi)

case "$CHOICE" in
    *Lock*)
        i3lock -c 1e1e2e
        ;;
    *Suspend*)
        i3lock -c 1e1e2e && systemctl suspend
        ;;
    *Logout*)
        awesome-client 'awesome.quit()'
        ;;
    *Reboot*)
        systemctl reboot
        ;;
    *Shutdown*)
        systemctl poweroff
        ;;
    *)
        exit 0
        ;;
esac
