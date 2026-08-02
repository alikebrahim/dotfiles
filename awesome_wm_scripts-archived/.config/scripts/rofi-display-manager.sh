#!/usr/bin/env bash
set -euo pipefail

INTERNAL="eDP-1-1"
EXTERNAL="HDMI-0"
MODE="1920x1080"
SETUP_SCRIPT="/home/alikebrahim/.config/scripts/x11-monitor-setup.sh"
WALLPAPER="/home/alikebrahim/Pictures/background.png"

usage() {
    printf 'Usage: %s [--apply dual|external|laptop|mirror]\n' "$0" >&2
    exit 2
}

output_connected() {
    local output="$1"
    xrandr --query | awk -v output="$output" '$1 == output && $2 == "connected" { found=1 } END { exit !found }'
}

supports_mode() {
    local output="$1"
    local mode="$2"
    xrandr --query | awk -v output="$output" -v mode="$mode" '
        $1 == output && $2 == "connected" { in_output=1; next }
        in_output && /^[^[:space:]]/ { exit found ? 0 : 1 }
        in_output && $1 == mode { found=1 }
        END { exit found ? 0 : 1 }
    '
}

require_profile_outputs() {
    output_connected "$INTERNAL" || { printf '%s is not connected\n' "$INTERNAL" >&2; exit 1; }
    output_connected "$EXTERNAL" || { printf '%s is not connected\n' "$EXTERNAL" >&2; exit 1; }
    supports_mode "$INTERNAL" "$MODE" || { printf '%s does not support %s\n' "$INTERNAL" "$MODE" >&2; exit 1; }
    supports_mode "$EXTERNAL" "$MODE" || { printf '%s does not support %s\n' "$EXTERNAL" "$MODE" >&2; exit 1; }
}

profile=""
if [ "$#" -eq 0 ]; then
    options=$'Dual Monitor\nExternal Only\nLaptop Only\nMirror Displays'
    choice="$(printf '%s\n' "$options" | rofi -dmenu -i -p "Monitor Setup" -config ~/.config/rofi/config.rasi)" || exit 0
    case "$choice" in
        *Dual*) profile="dual" ;;
        *External*) profile="external" ;;
        *Laptop*) profile="laptop" ;;
        *Mirror*) profile="mirror" ;;
        *) exit 0 ;;
    esac
elif [ "$#" -eq 2 ] && [ "$1" = "--apply" ]; then
    profile="$2"
else
    usage
fi

require_profile_outputs

case "$profile" in
    dual)
        "$SETUP_SCRIPT"
        ;;
    external)
        xrandr \
            --output "$EXTERNAL" --mode "$MODE" --pos 0x0 --primary \
            --output "$INTERNAL" --off
        ;;
    laptop)
        xrandr \
            --output "$INTERNAL" --mode "$MODE" --pos 0x0 --primary \
            --output "$EXTERNAL" --off
        ;;
    mirror)
        xrandr \
            --output "$EXTERNAL" --mode "$MODE" --pos 0x0 --primary \
            --output "$INTERNAL" --mode "$MODE" --same-as "$EXTERNAL"
        ;;
    *)
        usage
        ;;
esac

state="$(xrandr --query)"
output_line() {
    local output="$1"
    awk -v output="$output" '$1 == output { print; exit }' <<<"$state"
}
active_at() {
    local output="$1"
    local position="$2"
    [[ "$(output_line "$output")" == *"${MODE}+${position}"* ]]
}
primary_output() {
    [[ "$(output_line "$1")" == *" connected primary "* ]]
}
inactive_output() {
    local line
    line="$(output_line "$1")"
    [[ "$line" == *" connected "* && ! "$line" =~ [0-9]+x[0-9]+\+[0-9]+\+[0-9]+ ]]
}

case "$profile" in
    dual)
        active_at "$INTERNAL" "0+0" && active_at "$EXTERNAL" "1920+0" \
            && primary_output "$EXTERNAL" && ! primary_output "$INTERNAL"
        ;;
    external)
        active_at "$EXTERNAL" "0+0" && primary_output "$EXTERNAL" \
            && inactive_output "$INTERNAL"
        ;;
    laptop)
        active_at "$INTERNAL" "0+0" && primary_output "$INTERNAL" \
            && inactive_output "$EXTERNAL"
        ;;
    mirror)
        active_at "$EXTERNAL" "0+0" && active_at "$INTERNAL" "0+0" \
            && primary_output "$EXTERNAL"
        ;;
esac || {
    printf 'Display profile %s did not reach its expected RandR geometry\n' "$profile" >&2
    exit 1
}

# Wallpaper restoration is cosmetic; a verified display profile remains a
# success even if feh or the configured image is unavailable.
if command -v feh >/dev/null 2>&1 && [ -f "$WALLPAPER" ]; then
    feh --bg-fill "$WALLPAPER" "$WALLPAPER" || printf 'Wallpaper refresh failed\n' >&2
fi

printf 'applied:%s\n' "$profile"
