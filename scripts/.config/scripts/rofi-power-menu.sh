#!/bin/bash
set -euo pipefail

# Simple System76 Power & System Menu for AwesomeWM / Rofi.
# Left column: system actions. Right column: power profiles/status.

batt_info=$(upower -i /org/freedesktop/UPower/devices/battery_BAT0 2>/dev/null || true)
percentage=$(echo "$batt_info" | grep percentage | awk '{print $2}' || echo "N/A")
state=$(echo "$batt_info" | grep state | awk '{print $2}' || echo "N/A")

icon="󰁹"
[[ $state == *"charging"* ]] && icon="󰂄"

raw_profile=$(system76-power profile 2>/dev/null | grep 'Power Profile' | cut -d: -f2 | xargs || echo "?")
case "$raw_profile" in
  performance) current_profile="Performance" ;;
  battery) current_profile="Battery Saver" ;;
  balanced) current_profile="Balanced" ;;
  # system76-power currently reports '?' on this Fedora setup; show a sane default
  # instead of leaking implementation weirdness into the menu.
  *) current_profile="Balanced" ;;
esac

status="${icon}  Battery: ${percentage} (${state})    󰓅  Profile: ${current_profile}"

# Vertical flow + two columns means first 4 entries are left column,
# next 4 entries are right column.
options="󰗽  Logout
󰖠  Suspend
󰜉  Restart
󰐥  Poweroff
󰓅  Performance
󰾅  Balanced
󰌢  Battery Saver
󰔟  Current: $current_profile"

choice=$(printf "%s" "$options" | rofi -dmenu -i -no-custom \
  -p "Search" \
  -mesg "$status" \
  -theme /home/alikebrahim/.config/rofi/power.rasi \
  -kb-row-up "Up,Control+p" \
  -kb-row-down "Down,Control+n" \
  -kb-row-left "Control+Page_Up,Alt+h" \
  -kb-row-right "Control+Page_Down,Alt+l") || exit 0

case "${choice:-}" in
  *"Current:"*)
    exit 0
    ;;
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
    notify-send "Power Profile" "Switching to Performance..."
    pkexec system76-power profile performance
    ;;
  *"Balanced"*)
    notify-send "Power Profile" "Switching to Balanced..."
    pkexec system76-power profile balanced
    ;;
  *"Battery Saver"*)
    notify-send "Power Profile" "Switching to Battery Saver..."
    pkexec system76-power profile battery
    ;;
esac
