#!/bin/bash
set -euo pipefail

# Non-modal screenshot helper for capturing transient UI like Rofi menus.
# Unlike Flameshot GUI, this does not open a selection overlay before capture.

mode="${1:-full}"
screenshot_dir="${XDG_PICTURES_DIR:-$HOME/Pictures}/Screenshots"
mkdir -p "$screenshot_dir"
file="$screenshot_dir/screenshot-$(date +%Y%m%d-%H%M%S).png"

copy_png() {
  xclip -selection clipboard -t image/png -i "$1"
}

case "$mode" in
  full)
    maim -u "$file"
    copy_png "$file"
    notify-send "Screenshot saved" "$file" -i "$file" -t 2500
    ;;
  delay|delayed)
    delay="${2:-3}"
    notify-send "Screenshot in ${delay}s" "Keep the target popup open" -t 1200
    maim -u -d "$delay" "$file"
    copy_png "$file"
    notify-send "Screenshot saved" "$file" -i "$file" -t 2500
    ;;
  select|region)
    maim -u -s "$file"
    copy_png "$file"
    notify-send "Region screenshot saved" "$file" -i "$file" -t 2500
    ;;
  *)
    notify-send -u critical "Screenshot helper" "Unknown mode: $mode"
    exit 2
    ;;
esac
