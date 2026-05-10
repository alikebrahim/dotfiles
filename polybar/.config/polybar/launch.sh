#!/usr/bin/env bash
set -euo pipefail

LOG_FILE="/tmp/polybar-main.log"
CONFIG_FILE="$HOME/.config/polybar/config.ini"
PREFERRED_MONITOR="HDMI-0"
BAR_NAME="main"

log() {
  printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" | tee -a "$LOG_FILE"
}

if [[ -z "${DISPLAY:-}" ]]; then
  log "ERROR: DISPLAY is not set; refusing to launch Polybar."
  exit 1
fi

if ! command -v polybar >/dev/null 2>&1; then
  log "ERROR: polybar command not found."
  exit 1
fi

if [[ ! -f "$CONFIG_FILE" ]]; then
  log "ERROR: Polybar config not found: $CONFIG_FILE"
  exit 1
fi

: > "$LOG_FILE"
log "Restarting Polybar."

# Ask existing bars to exit gracefully first.
if command -v polybar-msg >/dev/null 2>&1; then
  polybar-msg cmd quit >>"$LOG_FILE" 2>&1 || true
fi

# Wait up to 5 seconds for existing bars to exit.
for _ in $(seq 1 50); do
  if ! pgrep -u "$USER" -x polybar >/dev/null 2>&1; then
    break
  fi
  sleep 0.1
done

# Only force-kill if graceful quit timed out.
if pgrep -u "$USER" -x polybar >/dev/null 2>&1; then
  log "WARN: Existing Polybar processes did not exit; killing them."
  pkill -u "$USER" -x polybar 2>/dev/null || true
  sleep 0.5
fi

if ! command -v xrandr >/dev/null 2>&1; then
  log "ERROR: xrandr command not found; cannot resolve monitor."
  exit 1
fi

XRANDR_QUERY="$(xrandr --query)"

if awk -v mon="$PREFERRED_MONITOR" '$1 == mon && $2 == "connected" { found=1 } END { exit found ? 0 : 1 }' <<< "$XRANDR_QUERY"; then
  monitor="$PREFERRED_MONITOR"
else
  monitor="$(awk '/ connected primary/ { print $1; exit }' <<< "$XRANDR_QUERY")"
  if [[ -z "$monitor" ]]; then
    monitor="$(awk '/ connected/ { print $1; exit }' <<< "$XRANDR_QUERY")"
  fi
fi

if [[ -z "${monitor:-}" ]]; then
  log "ERROR: No connected monitor found; cannot launch Polybar."
  exit 1
fi

log "Launching Polybar '$BAR_NAME' on monitor '$monitor'."
MONITOR="$monitor" polybar "$BAR_NAME" -c "$CONFIG_FILE" >>"$LOG_FILE" 2>&1 &
