#!/bin/bash
set -euo pipefail

THEME="$HOME/.config/rofi/control-menu.rasi"

need() {
  command -v "$1" >/dev/null 2>&1 || {
    notify-send -u critical "Audio menu" "Missing command: $1" 2>/dev/null || true
    exit 1
  }
}
has() { command -v "$1" >/dev/null 2>&1; }

for cmd in rofi wpctl notify-send; do
  need "$cmd"
done

notify() { notify-send "Audio" "$1" -t 1600; }

shorten() {
  local value="$1" max="${2:-38}"
  value="${value/ Built-in Audio/}"
  value="${value/ Analog Stereo/}"
  value="${value/ Digital Stereo/}"
  (( ${#value} > max )) && printf '%s…' "${value:0:max}" || printf '%s' "$value"
}

first_percent() { grep -oE '[0-9]+%' | head -n 1; }

sink_name()      { pactl get-default-sink 2>/dev/null || true; }
source_name()    { pactl get-default-source 2>/dev/null || true; }
sink_volume()    { pactl get-sink-volume @DEFAULT_SINK@ 2>/dev/null | first_percent || echo "?"; }
source_volume()  { pactl get-source-volume @DEFAULT_SOURCE@ 2>/dev/null | first_percent || echo "?"; }
sink_mute()      { pactl get-sink-mute @DEFAULT_SINK@ 2>/dev/null | awk '{print $2}' || echo "?"; }
source_mute()    { pactl get-source-mute @DEFAULT_SOURCE@ 2>/dev/null | awk '{print $2}' || echo "?"; }

mute_label() {
  case "$1" in yes) printf 'muted';; no) printf 'on';; *) printf '?';; esac
}

sink_description() {
  local current
  current="$(sink_name)"
  [[ -n $current ]] || return 0
  pactl -f json list sinks 2>/dev/null | jq -r --arg name "$current" \
    '.[] | select(.name == $name) | .description' | head -n 1
}

source_description() {
  local current
  current="$(source_name)"
  [[ -n $current ]] || return 0
  pactl -f json list sources 2>/dev/null | jq -r --arg name "$current" \
    '.[] | select(.name == $name) | .description' | head -n 1
}

status_line() {
  local desc vol mic_mute
  desc="$(sink_description)"
  [[ -n $desc && $desc != "null" ]] || desc="$(sink_name)"
  [[ -n $desc ]] || desc="unknown"
  desc="$(shorten "$desc")"
  vol="$(sink_volume)"
  mic_mute="$(mute_label "$(source_mute)")"
  printf '󰕾 %s · %s     mic %s' "$desc" "$vol" "$mic_mute"
}

rofi_menu() {
  rofi -dmenu -i -no-custom \
    -p "$1" -mesg "$2" -theme "$THEME" \
    -kb-row-up "Up,Control+p" -kb-row-down "Down,Control+n" \
    -theme-str 'window { width: 420px; }'
}

# ── volume submenu ──────────────────────────────────────────────────────────

volume_submenu() {
  local vol mute choice
  vol="$(sink_volume)"
  mute="$(sink_mute)"
  local mute_txt mute_icon
  if [[ $mute == "yes" ]]; then
    mute_txt="Unmute output"
    mute_icon=""
  else
    mute_txt="Mute output"
    mute_icon=""
  fi

  choice="$(printf '%s\n' \
    "  Volume up +5%" \
    "  Volume down -5%" \
    "$mute_icon  $mute_txt" \
    | rofi_menu "Volume" "$(status_line)")" || return 0

  case "${choice:-}" in
    *"Volume up"*)
      pamixer -i 5 2>/dev/null || wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+
      notify "Volume $(sink_volume)"
      ;;
    *"Volume down"*)
      pamixer -d 5 2>/dev/null || wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-
      notify "Volume $(sink_volume)"
      ;;
    *"Mute output"*)
      wpctl set-mute @DEFAULT_AUDIO_SINK@ 1
      notify "Output muted"
      ;;
    *"Unmute output"*)
      wpctl set-mute @DEFAULT_AUDIO_SINK@ 0
      notify "Output $(sink_volume)"
      ;;
  esac
}

# ── device switching ────────────────────────────────────────────────────────

choose_output() {
  if ! has jq; then notify-send "Audio" "Install jq for device selection"; return; fi
  local current choice id desc rows
  current="$(sink_name)"
  rows="$(pactl -f json list sinks 2>/dev/null | jq -r --arg current "$current" '
    .[]
    | select((.ports | length == 0) or ([.ports[]? | .availability != "not available"] | any))
    | "\(.properties."object.id")\t\(if .name == $current then "●" else "○" end)    \(.description // .name)"
  ')"
  [[ -n $rows ]] || { notify-send -u critical "Audio" "No output devices found"; return 1; }
  choice="$(printf '%s\n' "$rows" | rofi_menu "Output" "$(status_line)")" || return 0
  [[ -n ${choice:-} ]] || return 0
  id="${choice%%$'\t'*}"
  if [[ -n $id && $id != "$choice" ]]; then
    wpctl set-default "$id"
    notify "Output: $(shorten "${choice#*  }" 60)"
  fi
}

choose_input() {
  if ! has jq; then notify-send "Audio" "Install jq for device selection"; return; fi
  local current choice id desc rows
  current="$(source_name)"
  rows="$(pactl -f json list sources 2>/dev/null | jq -r --arg current "$current" '
    .[]
    | select(.properties."media.class" == "Audio/Source")
    | "\(.properties."object.id")\t\(if .name == $current then "●" else "○" end)    \(.description // .name)"
  ')"
  [[ -n $rows ]] || { notify-send -u critical "Audio" "No input devices found"; return 1; }
  choice="$(printf '%s\n' "$rows" | rofi_menu "Input" "$(status_line)")" || return 0
  [[ -n ${choice:-} ]] || return 0
  id="${choice%%$'\t'*}"
  if [[ -n $id && $id != "$choice" ]]; then
    wpctl set-default "$id"
    notify "Input: $(shorten "${choice#*  }" 60)"
  fi
}

# ── main menu ───────────────────────────────────────────────────────────────

main() {
  local vol mute_icon mic_mute mic_icon output_desc input_desc choice rows
  vol="$(sink_volume)"
  mute_icon=""
  [[ "$(sink_mute)" == "yes" ]] && mute_icon=""
  mic_mute="$(mute_label "$(source_mute)")"
  mic_icon=""
  [[ $mic_mute == "muted" ]] && mic_icon=""

  output_desc="$(sink_description)"
  [[ -n $output_desc && $output_desc != "null" ]] || output_desc="$(sink_name)"
  [[ -n $output_desc ]] || output_desc="unknown"
  output_desc="$(shorten "$output_desc" 32)"

  input_desc="$(source_description)"
  [[ -n $input_desc && $input_desc != "null" ]] || input_desc="$(source_name)"
  [[ -n $input_desc ]] || input_desc="unknown"
  input_desc="$(shorten "$input_desc" 32)"

  rows="$mute_icon  Volume · $vol"
  rows="$rows
$mic_icon  Mic · $mic_mute"
  rows="$rows
󰓃  Output · $output_desc"
  if has jq; then
    rows="$rows
󰍬  Input · $input_desc"
  fi
  rows="$rows
────────────
  Audio settings"

  choice="$(printf '%s\n' "$rows" | rofi_menu "Audio" "$(status_line)")" || exit 0

  case "${choice:-}" in
    *"Volume"*)  volume_submenu ;;
    *"Mic"*)
      wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle
      notify "Mic $(mute_label "$(source_mute)")"
      ;;
    *"Output"*)  choose_output ;;
    *"Input"*)   choose_input ;;
    *"Audio settings"*)
      pavucontrol >/dev/null 2>&1 &
      ;;
  esac
}

main
