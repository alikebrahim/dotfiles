#!/bin/bash
set -euo pipefail

THEME="$HOME/.config/rofi/control-menu.rasi"

need() {
  command -v "$1" >/dev/null 2>&1 || {
    notify-send -u critical "Audio menu" "Missing command: $1"
    exit 1
  }
}

for cmd in rofi wpctl pactl pamixer jq notify-send; do
  need "$cmd"
done

notify() {
  notify-send "Audio" "$1" -t 1600
}

first_percent() {
  grep -oE '[0-9]+%' | head -n 1
}

sink_name() {
  pactl get-default-sink 2>/dev/null || true
}

source_name() {
  pactl get-default-source 2>/dev/null || true
}

sink_description() {
  local current
  current="$(sink_name)"
  pactl -f json list sinks | jq -r --arg name "$current" '.[] | select(.name == $name) | .description' | head -n 1
}

source_description() {
  local current
  current="$(source_name)"
  pactl -f json list sources | jq -r --arg name "$current" '.[] | select(.name == $name) | .description' | head -n 1
}

sink_volume() {
  pactl get-sink-volume @DEFAULT_SINK@ 2>/dev/null | first_percent || echo "?"
}

source_volume() {
  pactl get-source-volume @DEFAULT_SOURCE@ 2>/dev/null | first_percent || echo "?"
}

sink_mute() {
  pactl get-sink-mute @DEFAULT_SINK@ 2>/dev/null | awk '{print $2}' || echo "?"
}

source_mute() {
  pactl get-source-mute @DEFAULT_SOURCE@ 2>/dev/null | awk '{print $2}' || echo "?"
}

status_line() {
  local sink desc vol mute src_mute
  desc="$(sink_description)"
  vol="$(sink_volume)"
  mute="$(sink_mute)"
  src_mute="$(source_mute)"
  [[ -n $desc && $desc != "null" ]] || desc="$(sink_name)"
  printf ' Audio · %s · %s · output %s · mic %s' "$desc" "$vol" "$mute" "$src_mute"
}

rofi_menu() {
  local prompt="$1"
  local message="$2"
  rofi -dmenu -i -no-custom \
    -p "$prompt" \
    -mesg "$message" \
    -theme "$THEME" \
    -kb-row-up "Up,Control+p" \
    -kb-row-down "Down,Control+n"
}

choose_output() {
  local current choice id desc
  current="$(sink_name)"
  choice="$(pactl -f json list sinks | jq -r --arg current "$current" '
    .[]
    | select((.ports | length == 0) or ([.ports[]? | .availability != "not available"] | any))
    | "\(.properties."object.id")\t\(if .name == $current then "●" else "○" end)    \(.description // .name)"
  ' | rofi_menu "Output" "$(status_line)")" || return 0
  [[ -n ${choice:-} ]] || return 0
  id="${choice%%$'\t'*}"
  desc="${choice#*$'\t'}"
  if [[ -n $id && $id != "$choice" ]]; then
    wpctl set-default "$id"
    notify "Output: ${desc#*  }"
  fi
}

choose_input() {
  local current choice id desc
  current="$(source_name)"
  choice="$(pactl -f json list sources | jq -r --arg current "$current" '
    .[]
    | select(.properties."media.class" == "Audio/Source")
    | "\(.properties."object.id")\t\(if .name == $current then "●" else "○" end)    \(.description // .name)"
  ' | rofi_menu "Input" "$(status_line)")" || return 0
  [[ -n ${choice:-} ]] || return 0
  id="${choice%%$'\t'*}"
  desc="${choice#*$'\t'}"
  if [[ -n $id && $id != "$choice" ]]; then
    wpctl set-default "$id"
    notify "Input: ${desc#*  }"
  fi
}

main() {
  local choice
  choice="$(cat <<'MENU' | rofi_menu "Audio" "$(status_line)"
  Volume up +5%
  Volume down -5%
  Toggle output mute
  Toggle microphone mute
󰓃  Switch output device
󰍬  Switch input device
  Open pavucontrol
MENU
)" || exit 0

  case "${choice:-}" in
    *"Volume up"*)
      pamixer -i 5
      notify "Volume $(sink_volume)"
      ;;
    *"Volume down"*)
      pamixer -d 5
      notify "Volume $(sink_volume)"
      ;;
    *"Toggle output mute"*)
      wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle
      notify "Output mute: $(sink_mute)"
      ;;
    *"Toggle microphone mute"*)
      wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle
      notify "Mic mute: $(source_mute)"
      ;;
    *"Switch output device"*)
      choose_output
      ;;
    *"Switch input device"*)
      choose_input
      ;;
    *"Open pavucontrol"*)
      if command -v pavucontrol >/dev/null 2>&1; then
        pavucontrol >/dev/null 2>&1 &
      else
        notify-send -u critical "Audio menu" "pavucontrol is not installed"
      fi
      ;;
  esac
}

main
