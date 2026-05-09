#!/usr/bin/env bash
set -euo pipefail

# Relaunch Polybar only on the XRandR primary monitor.
# Safe to run repeatedly from AwesomeWM startup or manually.

pkill -x polybar 2>/dev/null || true

# Wait briefly for old bars to exit.
for _ in $(seq 1 20); do
  pgrep -x polybar >/dev/null || break
  sleep 0.1
done

if command -v xrandr >/dev/null 2>&1; then
  primary="$(xrandr --query | awk '/ connected primary/{print $1; exit}')"
else
  primary=""
fi

if [ -n "$primary" ]; then
  MONITOR="$primary" polybar main -c "$HOME/.config/polybar/config.ini" >/tmp/polybar-"$primary".log 2>&1 &
else
  polybar main -c "$HOME/.config/polybar/config.ini" >/tmp/polybar-main.log 2>&1 &
fi
