#!/usr/bin/env bash
set -euo pipefail

# X11 monitor setup for System76 Serval WS serw13 Intel/NVIDIA hybrid graphics.
# Current desired layout:
# - Forces connected monitors to 1920x1080 when supported
# - Sets the first external monitor as primary
# - Places the internal laptop panel to the left of the external monitor
# - Falls back to auto/native mode if 1920x1080 is unavailable
# - Disables disconnected outputs to reduce stale layouts
# - PRIME provider linking attempts are non-fatal

if ! command -v xrandr >/dev/null 2>&1; then
  exit 0
fi

# Standard FHD resolution to apply to all monitors
TARGET_MODE="1920x1080"

# If RandR providers are present but not linked, try both common PRIME links.
# These commands may fail depending on provider names; failures are non-fatal.
if xrandr --listproviders >/tmp/xrandr-providers.$$ 2>/dev/null; then
  if grep -q 'name:NVIDIA' /tmp/xrandr-providers.$$ && grep -q 'name:modesetting' /tmp/xrandr-providers.$$; then
    xrandr --setprovideroutputsource modesetting NVIDIA-0 2>/dev/null || true
    xrandr --setprovideroutputsource NVIDIA-0 modesetting 2>/dev/null || true
    xrandr --setprovideroutputsource modesetting NVIDIA-G0 2>/dev/null || true
    xrandr --setprovideroutputsource NVIDIA-G0 modesetting 2>/dev/null || true
  fi
fi
rm -f /tmp/xrandr-providers.$$

# Get list of all connected outputs
mapfile -t connected < <(xrandr --query | awk '/ connected/{print $1}')
[ "${#connected[@]}" -gt 0 ] || exit 0

# Find internal panel and external monitors
internal=""
external=""
for output in "${connected[@]}"; do
  case "$output" in
    eDP*|LVDS*) internal="$output" ;;
    *) [ -z "$external" ] && external="$output" ;;
  esac
done

# Helper function to check if a mode is supported by an output
supports_mode() {
  local output="$1"
  local mode="$2"
  xrandr --query | grep -A 100 "^$output" | grep -q " $mode "
}

apply_layout() {
  # 1. Reset/Force modes for all connected monitors to 1080p first.
  for output in "${connected[@]}"; do
    if supports_mode "$output" "$TARGET_MODE"; then
      xrandr --output "$output" --mode "$TARGET_MODE"
    else
      xrandr --output "$output" --auto
    fi
  done

  # 2. Apply primary status and positioning.
  if [ -n "$external" ]; then
    xrandr --output "$external" --primary

    if [ -n "$internal" ]; then
      xrandr --output "$internal" --left-of "$external"
    fi

    previous="$external"
    for output in "${connected[@]}"; do
      [ "$output" = "$external" ] && continue
      [ "$output" = "$internal" ] && continue
      xrandr --output "$output" --right-of "$previous"
      previous="$output"
    done
  elif [ -n "$internal" ]; then
    xrandr --output "$internal" --primary
  fi
}

# Apply twice because PRIME/RandR provider changes can settle asynchronously.
apply_layout
sleep 0.5
apply_layout

# Final verification: if the laptop panel drifted back to native mode, force it once more.
if [ -n "$internal" ] && supports_mode "$internal" "$TARGET_MODE"; then
  current="$(xrandr --query | awk -v out="$internal" '$1 == out {print $3}')"
  case "$current" in
    "$TARGET_MODE"+*) ;;
    *) xrandr --output "$internal" --mode "$TARGET_MODE" ;;
  esac
fi

# Disable disconnected outputs to reduce stale layouts.
while read -r output _; do
  case " ${connected[*]} " in
    *" $output "*) ;;
    *) xrandr --output "$output" --off 2>/dev/null || true ;;
  esac
done < <(xrandr --query | awk '/ disconnected/{print $1, $2}')
