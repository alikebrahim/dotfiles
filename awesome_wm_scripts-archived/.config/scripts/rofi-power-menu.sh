#!/bin/bash
set -euo pipefail

THEME="$HOME/.config/rofi/power.rasi"

need() {
  command -v "$1" >/dev/null 2>&1 || {
    notify-send -u critical "Power menu" "Missing command: $1" 2>/dev/null || true
    exit 1
  }
}

for cmd in rofi systemctl notify-send awk grep xargs; do
  need "$cmd"
done

notify() {
  notify-send "Power" "$1" -t 1800
}

battery_path() {
  if command -v upower >/dev/null 2>&1; then
    upower -e 2>/dev/null | grep '/battery_' | head -n 1 || true
  fi
}

battery_status() {
  local path info percentage state time icon
  path="$(battery_path)"
  if [[ -n $path ]]; then
    info="$(upower -i "$path" 2>/dev/null || true)"
    percentage="$(awk '/percentage:/ {print $2; exit}' <<<"$info")"
    state="$(awk '/state:/ {print $2; exit}' <<<"$info")"
    time="$(awk -F': +' '/time to empty:/ {print $2; exit} /time to full:/ {print $2; exit}' <<<"$info")"
  fi
  [[ -n ${percentage:-} ]] || percentage="N/A"
  [[ -n ${state:-} ]] || state="unknown"
  [[ -n ${time:-} ]] || time=""
  icon="󰁹"
  [[ $state == *"charging"* ]] && icon="󰂄"
  [[ $state == *"fully-charged"* ]] && icon="󰁹"
  if [[ -n $time ]]; then
    printf '%s %s %s · %s' "$icon" "$percentage" "$state" "$time"
  else
    printf '%s %s %s' "$icon" "$percentage" "$state"
  fi
}

power_profile() {
  local raw
  if ! command -v system76-power >/dev/null 2>&1; then
    printf 'unavailable'
    return
  fi
  raw="$(system76-power profile 2>/dev/null | grep 'Power Profile' | cut -d: -f2 | xargs || true)"
  case "$raw" in
    performance) printf 'Performance' ;;
    battery) printf 'Battery Saver' ;;
    balanced) printf 'Balanced' ;;
    *) printf 'Balanced' ;;
  esac
}

status_line() {
  printf '%s    󰓅 Profile: %s' "$(battery_status)" "$(power_profile)"
}

set_profile() {
  local profile="$1" label="$2"
  if ! command -v system76-power >/dev/null 2>&1; then
    notify-send -u critical "Power Profile" "system76-power is not installed"
    return 1
  fi
  if ! command -v pkexec >/dev/null 2>&1; then
    notify-send -u critical "Power Profile" "pkexec is not installed"
    return 1
  fi
  notify-send "Power Profile" "Switching to $label..."
  pkexec system76-power profile "$profile"
}

options="󰖠  Suspend
󰗽  Logout
󰜉  Restart
󰐥  Poweroff
󰓅  Performance
󰾅  Balanced
󰌢  Battery Saver"

choice=$(printf "%s" "$options" | rofi -dmenu -i -no-custom \
  -p "Power" \
  -mesg "$(status_line)" \
  -theme "$THEME" \
  -kb-row-up "Up,Control+p" \
  -kb-row-down "Down,Control+n" \
  -kb-row-left "Control+Page_Up,Alt+h" \
  -kb-row-right "Control+Page_Down,Alt+l") || exit 0

case "${choice:-}" in
  *"Logout"*)
    awesome-client "awesome.quit()"
    ;;
  *"Suspend"*)
    systemctl suspend
    ;;
  *"Restart"*)
    systemctl reboot
    ;;
  *"Poweroff"*)
    systemctl poweroff
    ;;
  *"Performance"*)
    set_profile performance "Performance"
    ;;
  *"Balanced"*)
    set_profile balanced "Balanced"
    ;;
  *"Battery Saver"*)
    set_profile battery "Battery Saver"
    ;;
esac
