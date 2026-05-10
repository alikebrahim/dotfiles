#!/bin/bash
set -euo pipefail

THEME="$HOME/.config/rofi/control-menu.rasi"

need() {
  command -v "$1" >/dev/null 2>&1 || {
    notify-send -u critical "Audio menu" "Missing command: $1" 2>/dev/null || true
    exit 1
  }
}

for cmd in rofi wpctl pactl pamixer jq notify-send; do
  need "$cmd"
done

notify() {
  notify-send "Audio" "$1" -t 1600
}

shorten() {
  local value="$1" max="${2:-44}"
  value="${value/ Built-in Audio/}"
  value="${value/ Analog Stereo/}"
  value="${value/ Digital Stereo/}"
  if (( ${#value} > max )); then
    printf '%s…' "${value:0:max}"
  else
    printf '%s' "$value"
  fi
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

sink_count() {
  pactl -f json list sinks 2>/dev/null | jq 'length' 2>/dev/null || echo 0
}

source_count() {
  pactl -f json list sources 2>/dev/null | jq '[.[] | select(.properties."media.class" == "Audio/Source")] | length' 2>/dev/null || echo 0
}

sink_description() {
  local current
  current="$(sink_name)"
  [[ -n $current ]] || return 0
  pactl -f json list sinks 2>/dev/null | jq -r --arg name "$current" '.[] | select(.name == $name) | .description' | head -n 1
}

source_description() {
  local current
  current="$(source_name)"
  [[ -n $current ]] || return 0
  pactl -f json list sources 2>/dev/null | jq -r --arg name "$current" '.[] | select(.name == $name) | .description' | head -n 1
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

mute_label() {
  case "$1" in
    yes) printf 'muted' ;;
    no) printf 'on' ;;
    *) printf '?' ;;
  esac
}

status_line() {
  local desc vol mute mic_mute sinks sources
  desc="$(sink_description)"
  [[ -n $desc && $desc != "null" ]] || desc="$(sink_name)"
  [[ -n $desc ]] || desc="no output"
  desc="$(shorten "$desc" 38)"
  vol="$(sink_volume)"
  mute="$(mute_label "$(sink_mute)")"
  mic_mute="$(mute_label "$(source_mute)")"
  sinks="$(sink_count)"
  sources="$(source_count)"
  printf ' Audio · %s · %s · output %s · mic %s · devices %s/%s' "$desc" "$vol" "$mute" "$mic_mute" "$sinks" "$sources"
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
  local current choice id desc rows
  current="$(sink_name)"
  rows="$(pactl -f json list sinks 2>/dev/null | jq -r --arg current "$current" '
    .[]
    | select((.ports | length == 0) or ([.ports[]? | .availability != "not available"] | any))
    | "\(.properties."object.id")\t\(if .name == $current then "●" else "○" end)    \(.description // .name)"
  ')"
  if [[ -z $rows ]]; then
    notify-send -u critical "Audio" "No output devices found"
    return 1
  fi
  choice="$(printf '%s\n' "$rows" | rofi_menu "Output" "$(status_line)")" || return 0
  [[ -n ${choice:-} ]] || return 0
  id="${choice%%$'\t'*}"
  desc="${choice#*$'\t'}"
  if [[ -n $id && $id != "$choice" ]]; then
    wpctl set-default "$id"
    notify "Output: $(shorten "${desc#*  }" 60)"
  fi
}

choose_input() {
  local current choice id desc rows
  current="$(source_name)"
  rows="$(pactl -f json list sources 2>/dev/null | jq -r --arg current "$current" '
    .[]
    | select(.properties."media.class" == "Audio/Source")
    | "\(.properties."object.id")\t\(if .name == $current then "●" else "○" end)    \(.description // .name)"
  ')"
  if [[ -z $rows ]]; then
    notify-send -u critical "Audio" "No input devices found"
    return 1
  fi
  choice="$(printf '%s\n' "$rows" | rofi_menu "Input" "$(status_line)")" || return 0
  [[ -n ${choice:-} ]] || return 0
  id="${choice%%$'\t'*}"
  desc="${choice#*$'\t'}"
  if [[ -n $id && $id != "$choice" ]]; then
    wpctl set-default "$id"
    notify "Input: $(shorten "${desc#*  }" 60)"
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
      notify "Output $(mute_label "$(sink_mute)")"
      ;;
    *"Toggle microphone mute"*)
      wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle
      notify "Mic $(mute_label "$(source_mute)")"
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
