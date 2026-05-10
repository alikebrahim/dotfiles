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

notify() {
  notify-send "Bluetooth" "$1" -t 1800
}

controller_exists() {
  bluetoothctl show >/dev/null 2>&1
}

ctl_field() {
  local field="$1"
  bluetoothctl show 2>/dev/null | awk -F': ' -v f="$field" '$1 ~ f {print $2; exit}'
}

power_state() { ctl_field 'Powered'; }
pairable_state() { ctl_field 'Pairable'; }
discoverable_state() { ctl_field 'Discoverable'; }
discovering_state() { ctl_field 'Discovering'; }

paired_macs() {
  bluetoothctl devices Paired 2>/dev/null | awk '/^Device /{print $2}' | sort -u
}

all_macs() {
  bluetoothctl devices 2>/dev/null | awk '/^Device /{print $2}' | sort -u
}

device_info() {
  local mac="$1"
  bluetoothctl info "$mac" 2>/dev/null || true
}

device_field() {
  local mac="$1" field="$2"
  device_info "$mac" | awk -F': ' -v f="$field" '$1 ~ f {print $2; exit}'
}

device_alias() {
  local mac="$1" alias
  alias="$(device_field "$mac" 'Alias')"
  [[ -n $alias ]] || alias="$mac"
  printf '%s' "$alias"
}

device_connected() { device_field "$1" 'Connected'; }
device_paired() { device_field "$1" 'Paired'; }
device_trusted() { device_field "$1" 'Trusted'; }

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
    printf ' Bluetooth · no controller'
    return
  fi
  printf ' Bluetooth · power %s · connected %s · pairable %s · discoverable %s' \
    "$(power_state)" "$(connected_count)" "$(pairable_state)" "$(discoverable_state)"
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

device_label() {
  local mac="$1" alias connected paired trusted icon
  alias="$(device_alias "$mac")"
  connected="$(device_connected "$mac")"
  paired="$(device_paired "$mac")"
  trusted="$(device_trusted "$mac")"
  icon="○"
  [[ $connected == "yes" ]] && icon="●"
  printf '%s    %s · paired %s · trusted %s\t%s\n' "$icon" "$alias" "${paired:-?}" "${trusted:-?}" "$mac"
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
    bluetoothctl "$what" off >/dev/null
    notify "$what off"
  else
    rfkill unblock bluetooth
    bluetoothctl power on >/dev/null || true
    bluetoothctl "$what" on >/dev/null
    notify "$what on"
  fi
}

scan_devices() {
  rfkill unblock bluetooth
  bluetoothctl power on >/dev/null || true

  # Keep the interaction inside Rofi: show a temporary scan view, then reopen
  # the refreshed controls list automatically. Avoid `exec` here because rofi
  # exits non-zero when it is closed programmatically, and set -e would stop the
  # script before the refresh menu opens.
  (
    sleep 0.2
    bluetoothctl --timeout 8 scan on >/dev/null 2>&1 || true
    pkill -u "$USER" -x rofi 2>/dev/null || true
  ) &
  local scan_pid=$!

  set +e
  printf '󰑓  Scanning for devices...\n󰌑  This window will refresh automatically\n' | rofi_menu "Bluetooth" " Bluetooth · scanning for 8 seconds..."
  set -e

  wait "$scan_pid" || true
  "$0"
  exit 0
}

pair_trust_connect() {
  local mac="$1" alias
  alias="$(device_alias "$mac")"
  rfkill unblock bluetooth
  bluetoothctl power on >/dev/null || true
  bluetoothctl pair "$mac"
  bluetoothctl trust "$mac"
  bluetoothctl connect "$mac"
  notify "Paired, trusted, and connected $alias"
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
󰆴  Remove pairing"
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

  choice="$(printf '%s\n' "$rows" | rofi_menu "$alias" " $alias · $mac · connected ${connected:-?} · paired ${paired:-?} · trusted ${trusted:-?}")" || return 0

  case "${choice:-}" in
    *"Pair + trust + connect"*) pair_trust_connect "$mac" ;;
    *"Connect"*) bluetoothctl connect "$mac" && notify "Connected $alias" ;;
    *"Disconnect"*) bluetoothctl disconnect "$mac" && notify "Disconnected $alias" ;;
    *"Pair"*) bluetoothctl pair "$mac" && notify "Paired $alias" ;;
    *"Remove pairing"*) bluetoothctl remove "$mac" && notify "Removed $alias" ;;
    *"Trust"*) bluetoothctl trust "$mac" && notify "Trusted $alias" ;;
    *"Untrust"*) bluetoothctl untrust "$mac" && notify "Untrusted $alias" ;;
    *"Back"*) exec "$0" ;;
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
    rows="󰂲  Power off
󰂯  Scan for devices"
    [[ $pairable == "yes" ]] && rows="$rows
󰌾  Pairable off" || rows="$rows
󰌾  Pairable on"
    [[ $discoverable == "yes" ]] && rows="$rows
󰌷  Discoverable off" || rows="$rows
󰌷  Discoverable on"
    rows="$rows
$DIVIDER
$(device_rows)"
  else
    rows="  Power on"
  fi

  choice="$(printf '%s\n' "$rows" | rofi_menu "Bluetooth" "$(status_line)")" || exit 0

  case "${choice:-}" in
    *"Power on"*)
      rfkill unblock bluetooth
      bluetoothctl power on
      notify "Power on"
      ;;
    *"Power off"*)
      bluetoothctl power off
      notify "Power off"
      ;;
    *"Scan for devices"*) scan_devices ;;
    *"Pairable on"*) toggle_bool pairable no ;;
    *"Pairable off"*) toggle_bool pairable yes ;;
    *"Discoverable on"*) toggle_bool discoverable no ;;
    *"Discoverable off"*) toggle_bool discoverable yes ;;
    [●○]*""*)
      mac="${choice##*$'\t'}"
      [[ -n $mac && $mac != "$choice" ]] && device_menu "$mac"
      ;;
  esac
}

show_menu
