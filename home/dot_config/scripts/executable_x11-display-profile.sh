#!/usr/bin/env bash
set -euo pipefail

# Fixed-profile RandR backend for the servalws Quickshell display manager.
# This command has no interactive mode: callers must provide one allowlisted
# profile token, and every connected-output/mode preflight completes before the
# first RandR mutation.

INTERNAL="eDP-1-1"
EXTERNAL="HDMI-0"
MODE="1920x1080"
WALLPAPER="${HOME}/Pictures/background.png"

usage() {
    printf 'Usage: %s --apply dual|external|laptop|mirror\n' "$0" >&2
    exit 2
}

[[ "$#" -eq 2 && "$1" == "--apply" ]] || usage
profile="$2"
case "$profile" in
    dual|external|laptop|mirror) ;;
    *) usage ;;
esac

command -v xrandr >/dev/null 2>&1 || {
    printf 'xrandr is required\n' >&2
    exit 1
}

initial_state="$(xrandr --query)"

output_connected() {
    local output="$1"
    awk -v output="$output" '
        $1 == output && $2 == "connected" { found=1 }
        END { exit !found }
    ' <<<"$initial_state"
}

supports_mode() {
    local output="$1"
    local mode="$2"
    awk -v output="$output" -v mode="$mode" '
        $1 == output && $2 == "connected" { in_output=1; next }
        in_output && /^[^[:space:]]/ { exit found ? 0 : 1 }
        in_output && $1 == mode { found=1 }
        END { exit found ? 0 : 1 }
    ' <<<"$initial_state"
}

output_connected "$INTERNAL" || {
    printf '%s is not connected\n' "$INTERNAL" >&2
    exit 1
}
output_connected "$EXTERNAL" || {
    printf '%s is not connected\n' "$EXTERNAL" >&2
    exit 1
}
supports_mode "$INTERNAL" "$MODE" || {
    printf '%s does not support %s\n' "$INTERNAL" "$MODE" >&2
    exit 1
}
supports_mode "$EXTERNAL" "$MODE" || {
    printf '%s does not support %s\n' "$EXTERNAL" "$MODE" >&2
    exit 1
}

case "$profile" in
    dual)
        xrandr \
            --output "$INTERNAL" --mode "$MODE" --pos 0x0 \
            --output "$EXTERNAL" --mode "$MODE" --pos 1920x0 --primary
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
    local output="$1"
    awk -v output="$output" '
        $1 == output && $2 == "connected" &&
            $0 !~ /[0-9]+x[0-9]+\+[0-9]+\+[0-9]+/ { found=1 }
        END { exit !found }
    ' <<<"$state"
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

# Wallpaper restoration is cosmetic; verified display geometry remains success.
if command -v feh >/dev/null 2>&1 && [[ -f "$WALLPAPER" ]]; then
    feh --bg-fill "$WALLPAPER" "$WALLPAPER" \
        || printf 'Wallpaper refresh failed\n' >&2
fi

printf 'applied:%s\n' "$profile"
