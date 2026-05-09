#!/bin/bash
set -euo pipefail

# X11 screenshot helper for AwesomeWM.
# Modes:
#   gui   - interactive Flameshot region capture/editor
#   full  - full-screen capture saved to ~/Pictures/Screenshots and copied
#   copy  - full-screen capture copied to clipboard only

mode="${1:-gui}"
screenshot_dir="${XDG_PICTURES_DIR:-$HOME/Pictures}/Screenshots"
mkdir -p "$screenshot_dir"

if ! command -v flameshot >/dev/null 2>&1; then
  notify-send -u critical "Screenshot unavailable" "flameshot is not installed"
  exit 1
fi

# The GDM/X11 environment can retain Wayland-looking variables. Force Qt/Flameshot
# onto XCB or Flameshot tries the Wayland plugin and silently hangs/fails.
flameshot_x11() {
  env -u WAYLAND_DISPLAY \
    QT_QPA_PLATFORM=xcb \
    XDG_SESSION_TYPE=x11 \
    XDG_CURRENT_DESKTOP=awesome \
    flameshot "$@"
}

# Start daemon if needed. Flameshot's CLI works best when the daemon exists.
if ! pgrep -u "$USER" -x flameshot >/dev/null 2>&1; then
  flameshot_x11 >/tmp/flameshot-awesome.log 2>&1 &
  sleep 0.4
fi

case "$mode" in
  gui|region|edit)
    flameshot_x11 gui --path "$screenshot_dir"
    ;;
  full)
    file="$screenshot_dir/screenshot-$(date +%Y%m%d-%H%M%S).png"
    flameshot_x11 full --path "$file" --clipboard
    notify-send "Screenshot saved" "$file" -i "$file" -t 3000
    ;;
  copy)
    flameshot_x11 full --clipboard
    notify-send "Screenshot copied" "Full screenshot copied to clipboard" -t 2000
    ;;
  *)
    notify-send -u critical "Screenshot helper" "Unknown mode: $mode"
    exit 2
    ;;
esac
