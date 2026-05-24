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
  # Build one explicit RandR transaction so stale output positions cannot leave gaps.
  # Desired two-screen layout:
  #   internal: 1920x1080+0+0
  #   external: 1920x1080+1920+0, primary
  local args=()
  local x=0
  local output

  if [ -n "$internal" ]; then
    args+=(--output "$internal")
    if supports_mode "$internal" "$TARGET_MODE"; then
      args+=(--mode "$TARGET_MODE")
    else
      args+=(--auto)
    fi
    args+=(--pos "${x}x0")
    x=$((x + 1920))
  fi

  if [ -n "$external" ]; then
    args+=(--output "$external" --primary)
    if supports_mode "$external" "$TARGET_MODE"; then
      args+=(--mode "$TARGET_MODE")
    else
      args+=(--auto)
    fi
    args+=(--pos "${x}x0")
    x=$((x + 1920))
  elif [ -n "$internal" ]; then
    args+=(--output "$internal" --primary)
  fi

  for output in "${connected[@]}"; do
    [ "$output" = "$internal" ] && continue
    [ "$output" = "$external" ] && continue
    args+=(--output "$output")
    if supports_mode "$output" "$TARGET_MODE"; then
      args+=(--mode "$TARGET_MODE")
    else
      args+=(--auto)
    fi
    args+=(--pos "${x}x0")
    x=$((x + 1920))
  done

  xrandr "${args[@]}"
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
