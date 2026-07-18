#!/bin/bash
set -euo pipefail

THEME="$HOME/.config/rofi/control-menu.rasi"
DIVIDER="────────────"

need() {
  command -v "$1" >/dev/null 2>&1 || {
    notify-send -u critical "Bluetooth menu" "Missing command: $1" 2>/dev/null || true
    exit 1
  }
}

for cmd in rofi bluetoothctl rfkill notify-send awk grep sort; do
  need "$cmd"
done

notify() { notify-send "Bluetooth" "$1" -t 1800; }

controller_exists() { bluetoothctl show >/dev/null 2>&1; }

ctl_field() {
  local field="$1"
  bluetoothctl show 2>/dev/null | awk -F': ' -v f="$field" '$1 ~ f {print $2; exit}'
}

power_state()       { ctl_field 'Powered'; }
pairable_state()    { ctl_field 'Pairable'; }
discoverable_state() { ctl_field 'Discoverable'; }

paired_macs() {
  bluetoothctl devices Paired 2>/dev/null | awk '/^Device /{print $2}' | sort -u
}

all_macs() {
  bluetoothctl devices 2>/dev/null | awk '/^Device /{print $2}' | sort -u
}

device_info()  { bluetoothctl info "$1" 2>/dev/null || true; }
device_field() { device_info "$1" | awk -F': ' -v f="$2" '$1 ~ f {print $2; exit}'; }

device_alias() {
  local mac="$1" alias
  alias="$(device_field "$mac" 'Alias')"
  [[ -n $alias ]] || alias="$mac"
  printf '%s' "$alias"
}

device_connected()  { device_field "$1" 'Connected'; }
device_paired()     { device_field "$1" 'Paired'; }
device_trusted()    { device_field "$1" 'Trusted'; }

# Map BlueZ icon name to nerd font glyph
device_type_icon() {
  case "$1" in
    audio-headphones|audio-headset) printf '' ;;
    audio-card|audio-speakers)      printf '󰓃' ;;
    input-keyboard)                 printf '󰌌' ;;
    input-mouse)                    printf '󰍽' ;;
    input-gaming)                   printf '' ;;
    input-tablet)                   printf '' ;;
    phone)                          printf '' ;;
    modem)                          printf '' ;;
    camera-photo)                   printf '' ;;
    computer)                       printf '' ;;
    network-wireless)               printf '󰖩' ;;
    *)                              printf '' ;;
  esac
}

device_battery() {
  local pct
  pct="$(device_field "$1" 'Battery Percentage' | grep -oE '[0-9]+' || true)"
  [[ -n $pct ]] && printf '%s%%' "$pct" || printf ''
}

connected_count() {
  local count=0 mac
  while read -r mac; do
    [[ -n $mac ]] || continue
    [[ "$(device_connected "$mac")" == "yes" ]] && ((count++)) || true
  done < <(paired_macs)
  printf '%s' "$count"
}

status_line() {
  if ! controller_exists; then
    printf ' no controller'; return
  fi
  local power cnt pairable
  power="$(power_state)"
  cnt="$(connected_count)"
  pairable="$(pairable_state)"
  [[ $power == "yes" ]] && printf ' on   󰂱 %s device   󰌾 %s' "$cnt" "$pairable" \
    || printf ' off'
}

rofi_menu() {
  rofi -dmenu -i -no-custom \
    -p "$1" -mesg "$2" -theme "$THEME" \
    -kb-row-up "Up,Control+p" -kb-row-down "Down,Control+n" \
    -theme-str 'window { width: 600px; }'
}

device_label() {
  local mac="$1" alias connected paired trusted icon type_icon battery
  alias="$(device_alias "$mac")"
  connected="$(device_connected "$mac")"
  paired="$(device_paired "$mac")"
  trusted="$(device_trusted "$mac")"

  type_icon="$(device_type_icon "$(device_field "$mac" 'Icon')")"
  battery="$(device_battery "$mac")"
  [[ -n $battery ]] && battery=" · $battery"

  icon="○"
  [[ $connected == "yes" ]] && icon="●"

  printf '%s  %s  %s · paired %s · trusted %s%s\t%s\n' \
    "$icon" "$type_icon" "$alias" "${paired:-?}" "${trusted:-?}" "$battery" "$mac"
}

device_rows() {
  local mac
  all_macs | while read -r mac; do
    [[ -n $mac ]] && device_label "$mac"
  done
}

toggle_bool() {
  local what="$1" current="$2"
  if [[ $current == "yes" ]]; then
    bluetoothctl "$what" off >/dev/null; notify "$what off"
  else
    rfkill unblock bluetooth; bluetoothctl power on >/dev/null || true
    bluetoothctl "$what" on >/dev/null; notify "$what on"
  fi
}

scan_devices() {
  local scan_pid
  rfkill unblock bluetooth; bluetoothctl power on >/dev/null || true

  (
    sleep 0.2
    bluetoothctl --timeout 8 scan on >/dev/null 2>&1 || true
    pkill -u "$USER" -x rofi 2>/dev/null || true
  ) &
  scan_pid=$!

  set +e
  printf '󰑓  Scanning for devices...\n󰌑  Press Esc to cancel\n' | \
    rofi -dmenu -i -no-custom -p "Bluetooth" -mesg " Scanning for 8 seconds..." \
      -theme "$THEME" -theme-str 'window { width: 460px; }' \
      -kb-row-up "Up,Control+p" -kb-row-down "Down,Control+n"
  set -e

  wait "$scan_pid" || true
  exec "$0"
}

pair_trust_connect() {
  local mac="$1" alias
  alias="$(device_alias "$mac")"
  rfkill unblock bluetooth; bluetoothctl power on >/dev/null || true
  bluetoothctl pair "$mac"; bluetoothctl trust "$mac"; bluetoothctl connect "$mac"
  notify "Paired, trusted, and connected $alias"
}

remove_device() {
  local mac="$1" alias
  alias="$(device_alias "$mac")"
  bluetoothctl remove "$mac" && notify "Removed $alias"
}

device_menu() {
  local mac="$1" alias connected paired trusted choice rows
  alias="$(device_alias "$mac")"
  connected="$(device_connected "$mac")"
  paired="$(device_paired "$mac")"
  trusted="$(device_trusted "$mac")"

  if [[ $paired != "yes" ]]; then
    rows="󰐕  Pair + trust + connect"
  elif [[ $connected == "yes" ]]; then
    rows="󰌙  Disconnect"
  else
    rows="󰌹  Connect"
  fi

  if [[ $paired == "yes" ]]; then
    rows="$rows
󰆴  Remove device"
  else
    rows="$rows
󰐕  Pair"
  fi

  if [[ $trusted == "yes" ]]; then
    rows="$rows
󰓎  Untrust"
  else
    rows="$rows
󰓎  Trust"
  fi

  rows="$rows
󰌑  Back"

  choice="$(printf '%s\n' "$rows" | rofi_menu "$alias" \
    " $alias · $mac · connected ${connected:-?} · paired ${paired:-?} · trusted ${trusted:-?}")" || return 0

  case "${choice:-}" in
    *"Pair + trust + connect"*) pair_trust_connect "$mac" ;;
    *"Connect"*)       bluetoothctl connect "$mac" && notify "Connected $alias" ;;
    *"Disconnect"*)    bluetoothctl disconnect "$mac" && notify "Disconnected $alias" ;;
    *"Pair"*)          bluetoothctl pair "$mac" && notify "Paired $alias" ;;
    *"Remove"*)        remove_device "$mac" ;;
    *"Trust"*)         bluetoothctl trust "$mac" && notify "Trusted $alias" ;;
    *"Untrust"*)       bluetoothctl untrust "$mac" && notify "Untrusted $alias" ;;
    *"Back"*)          exec "$0" ;;
  esac
}

show_menu() {
  local power pairable discoverable choice rows mac

  if ! controller_exists; then
    notify-send -u critical "Bluetooth" "No Bluetooth controller found"
    exit 1
  fi

  power="$(power_state)"
  pairable="$(pairable_state)"
  discoverable="$(discoverable_state)"

  if [[ $power == "yes" ]]; then
    rows="󰂲  Turn Bluetooth off
󰂯  Scan for devices"
    [[ $pairable == "yes" ]] && rows="$rows
󰌾  Pairable · on" || rows="$rows
󰌾  Pairable · off"
    [[ $discoverable == "yes" ]] && rows="$rows
󰌷  Discoverable · on" || rows="$rows
󰌷  Discoverable · off"
    rows="$rows
$DIVIDER
$(device_rows)"
  else
    rows="  Turn Bluetooth on"
  fi

  choice="$(printf '%s\n' "$rows" | rofi_menu "Bluetooth" "$(status_line)")" || exit 0

  case "${choice:-}" in
    *"Turn Bluetooth on"*)
      rfkill unblock bluetooth; bluetoothctl power on; notify "Power on"
      ;;
    *"Turn Bluetooth off"*)
      bluetoothctl power off; notify "Power off"
      ;;
    *"Scan"*)     scan_devices ;;
    *"Pairable"*) toggle_bool pairable "$(pairable_state)" ;;
    *"Discoverable"*) toggle_bool discoverable "$(discoverable_state)" ;;
    *)
      # Device rows end with a tab-separated MAC address.
      mac="${choice##*$'\t'}"
      [[ -n $mac && $mac != "$choice" ]] && device_menu "$mac"
      ;;
  esac
}

show_menu
