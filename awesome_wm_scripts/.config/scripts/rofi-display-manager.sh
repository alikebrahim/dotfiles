#!/usr/bin/env bash
set -euo pipefail

# Options for Rofi
OPTIONS="󰍹  Dual Monitor\n󰓏  External Only\n󰌢  Laptop Only\n󰍺  Mirror Displays"

# Run Rofi selection
CHOICE=$(echo -e "$OPTIONS" | rofi -dmenu -i -p "Monitor Setup" -config ~/.config/rofi/config.rasi)

# Map internal/external names for this system
INTERNAL="eDP-1-1"
EXTERNAL="HDMI-0"

case "$CHOICE" in
    *Dual*)
        # Run your stabilized 2-pass setup
        /home/alikebrahim/.config/scripts/x11-monitor-setup.sh
        ;;
    *External*)
        # External primary, laptop off
        xrandr --output "$EXTERNAL" --auto --primary --output "$INTERNAL" --off
        ;;
    *Laptop*)
        # Laptop primary (1080p for consistency), external off
        xrandr --output "$INTERNAL" --mode 1920x1080 --primary --output "$EXTERNAL" --off
        ;;
    *Mirror*)
        # Mirror both at 1080p
        xrandr --output "$EXTERNAL" --mode 1920x1080 --primary --output "$INTERNAL" --mode 1920x1080 --same-as "$EXTERNAL"
        ;;
    *)
        exit 0
        ;;
esac

# Cleanup UI: Apply wallpaper and restart Polybar to match new screen geometry
/home/alikebrahim/.config/polybar/launch.sh
feh --bg-fill /home/alikebrahim/Pictures/background.png /home/alikebrahim/Pictures/background.png
