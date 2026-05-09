#!/bin/bash
set -euo pipefail

# Modern dual-pane Rofi calendar popup.
# Left: Date, Time
# Right: Visual Calendar table + Copy Actions

today_human="$(date '+%A, %d %B %Y')"
time_now="$(date '+%H:%M')"
date_iso="$(date '+%Y-%m-%d')"
timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
month_title="$(date '+%B %Y')"

# Calendar for the right pane (listview items)
calendar_lines="$(cal --monday --color=never | sed 's/[[:space:]]*$//')"

theme_str="
left-pane { 
  children: [ \"textbox-date\", \"textbox-time\", \"dummy\" ]; 
}
textbox-date {
  expand: false;
  content: \"$today_human\";
  text-color: @accent;
  font: \"JetBrainsMono Nerd Font Bold 12\";
  margin: 0 0 10px 0;
}
textbox-time {
  expand: false;
  content: \"$time_now\";
  font: \"JetBrainsMono Nerd Font Bold 32\";
}
"

menu="$calendar_lines
  Copy ISO Date ($date_iso)
  Copy Timestamp"

choice="$(printf '%s\n' "$menu" | rofi -dmenu -i -p "$month_title" \
    -theme /home/alikebrahim/.config/rofi/calendar.rasi \
    -theme-str "$theme_str")" || exit 0

case "$choice" in
  *"Copy ISO Date"*)
    printf '%s' "$date_iso" | xclip -selection clipboard
    notify-send "Date copied" "$date_iso" -t 1600
    ;;
  *"Copy Timestamp"*)
    printf '%s' "$timestamp" | xclip -selection clipboard
    notify-send "Timestamp copied" "$timestamp" -t 1600
    ;;
esac
