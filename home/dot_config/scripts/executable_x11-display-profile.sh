#!/usr/bin/env bash
set -euo pipefail

# Fixed-profile RandR backend for the Quickshell display manager.
# Modes:
#   --apply dual|external|laptop|mirror
#   --query
# Laptop-only does not require the external output to be connected.
# Dual, mirror, and external-only do.

INTERNAL="eDP-1-1"
EXTERNAL="HDMI-0"
MODE="1920x1080"
WALLPAPER="${HOME}/Pictures/background.png"

usage() {
    printf 'Usage: %s --apply dual|external|laptop|mirror | --query\n' "$0" >&2
    exit 2
}

[[ "$#" -ge 1 ]] || usage

command -v xrandr >/dev/null 2>&1 || {
    printf 'xrandr is required\n' >&2
    exit 1
}

mode="$1"
profile="${2:-}"

if [[ "$mode" == "--query" ]]; then
    [[ "$#" -eq 1 ]] || usage
elif [[ "$mode" == "--apply" ]]; then
    [[ "$#" -eq 2 ]] || usage
    case "$profile" in
        dual|external|laptop|mirror) ;;
        *) usage ;;
    esac
else
    usage
fi

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
    local mode_name="$2"
    awk -v output="$output" -v mode="$mode_name" '
        $1 == output && $2 == "connected" { in_output=1; next }
        in_output && /^[^[:space:]]/ { exit found ? 0 : 1 }
        in_output && $1 == mode { found=1 }
        END { exit found ? 0 : 1 }
    ' <<<"$initial_state"
}

output_line_from() {
    local output="$1"
    local source="$2"
    awk -v output="$output" '$1 == output { print; exit }' <<<"$source"
}

active_at_from() {
    local output="$1"
    local position="$2"
    local source="$3"
    [[ "$(output_line_from "$output" "$source")" == *"${MODE}+${position}"* ]]
}

primary_from() {
    local output="$1"
    local source="$2"
    [[ "$(output_line_from "$output" "$source")" == *" connected primary "* ]]
}

unused_from() {
    local output="$1"
    local source="$2"
    local line
    line="$(output_line_from "$output" "$source")"
    [[ "$line" == *" disconnected"* ]] && return 0
    awk -v output="$output" '
        $1 == output && $2 == "connected" &&
            $0 !~ /[0-9]+x[0-9]+\+[0-9]+\+[0-9]+/ { found=1 }
        END { exit !found }
    ' <<<"$source"
}

matches_profile() {
    local requested="$1"
    local source="$2"
    case "$requested" in
        dual)
            active_at_from "$INTERNAL" "0+0" "$source" \
                && active_at_from "$EXTERNAL" "1920+0" "$source" \
                && primary_from "$EXTERNAL" "$source" \
                && ! primary_from "$INTERNAL" "$source"
            ;;
        external)
            active_at_from "$EXTERNAL" "0+0" "$source" \
                && primary_from "$EXTERNAL" "$source" \
                && unused_from "$INTERNAL" "$source"
            ;;
        laptop)
            active_at_from "$INTERNAL" "0+0" "$source" \
                && primary_from "$INTERNAL" "$source" \
                && unused_from "$EXTERNAL" "$source"
            ;;
        mirror)
            active_at_from "$EXTERNAL" "0+0" "$source" \
                && active_at_from "$INTERNAL" "0+0" "$source" \
                && primary_from "$EXTERNAL" "$source"
            ;;
        *)
            return 1
            ;;
    esac
}

require_internal() {
    output_connected "$INTERNAL" || {
        printf '%s is not connected\n' "$INTERNAL" >&2
        exit 1
    }
    supports_mode "$INTERNAL" "$MODE" || {
        printf '%s does not support %s\n' "$INTERNAL" "$MODE" >&2
        exit 1
    }
}

require_external() {
    output_connected "$EXTERNAL" || {
        printf '%s is not connected\n' "$EXTERNAL" >&2
        exit 1
    }
    supports_mode "$EXTERNAL" "$MODE" || {
        printf '%s does not support %s\n' "$EXTERNAL" "$MODE" >&2
        exit 1
    }
}

if [[ "$mode" == "--query" ]]; then
    for candidate in dual external laptop mirror; do
        if matches_profile "$candidate" "$initial_state"; then
            printf 'current:%s\n' "$candidate"
            exit 0
        fi
    done
    printf 'current:unknown\n'
    exit 0
fi

case "$profile" in
    dual|mirror)
        require_internal
        require_external
        ;;
    external)
        require_external
        ;;
    laptop)
        require_internal
        ;;
esac

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
        if output_connected "$EXTERNAL"; then
            xrandr \
                --output "$INTERNAL" --mode "$MODE" --pos 0x0 --primary \
                --output "$EXTERNAL" --off
        else
            xrandr \
                --output "$INTERNAL" --mode "$MODE" --pos 0x0 --primary
        fi
        ;;
    mirror)
        xrandr \
            --output "$EXTERNAL" --mode "$MODE" --pos 0x0 --primary \
            --output "$INTERNAL" --mode "$MODE" --same-as "$EXTERNAL"
        ;;
esac

state="$(xrandr --query)"

matches_profile "$profile" "$state" || {
    printf 'Display profile %s did not reach its expected RandR geometry\n' "$profile" >&2
    exit 1
}

if command -v feh >/dev/null 2>&1 && [[ -f "$WALLPAPER" ]]; then
    feh --bg-fill "$WALLPAPER" "$WALLPAPER" \
        || printf 'Wallpaper refresh failed\n' >&2
fi

printf 'applied:%s\n' "$profile"
