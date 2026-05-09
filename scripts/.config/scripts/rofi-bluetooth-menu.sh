#!/bin/bash
set -euo pipefail

THEME="$HOME/.config/rofi/control-menu.rasi"
DIVIDER="────────────"

need() {
  command -v "$1" >/dev/null 2>&1 || {
    notify-send -u critical "Bluetooth menu" "Missing command: $1"
    exit 1
  }
}

for cmd in rofi bluetoothctl rfkill notify-send awk grep; do
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

connected_count() {
  local count=0 mac info
  while read -r mac; do
    [[ -n $mac ]] || continue
    info="$(bluetoothctl info "$mac" 2>/dev/null || true)"
    grep -q 'Connected: yes' <<<"$info" && ((count++)) || true
  done < <(bluetoothctl devices Paired 2>/dev/null | awk '/^Device /{print $2}')
  printf '%s' "$count"
}

status_line() {
  if ! controller_exists; then
    printf ' Bluetooth · no controller'
    return
  fi
  printf ' Bluetooth · power %s · pairable %s · discoverable %s · connected %s' \
    "$(power_state)" "$(pairable_state)" "$(discoverable_state)" "$(connected_count)"
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
  local mac="$1" info alias connected paired trusted icon
  info="$(bluetoothctl info "$mac" 2>/dev/null || true)"
  alias="$(awk -F': ' '/^\s*Alias:/ {print $2; exit}' <<<"$info")"
  [[ -n $alias ]] || alias="$mac"
  connected="$(awk -F': ' '/^\s*Connected:/ {print $2; exit}' <<<"$info")"
  paired="$(awk -F': ' '/^\s*Paired:/ {print $2; exit}' <<<"$info")"
  trusted="$(awk -F': ' '/^\s*Trusted:/ {print $2; exit}' <<<"$info")"
  icon="○"
  [[ $connected == "yes" ]] && icon="●"
  printf '%s    %s · %s · paired %s · trusted %s\t%s\n' "$icon" "$alias" "$mac" "${paired:-?}" "${trusted:-?}" "$mac"
}

device_rows() {
  local mac
  bluetoothctl devices 2>/dev/null | awk '/^Device /{print $2}' | sort -u | while read -r mac; do
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
  notify "Scanning for 8 seconds..."
  bluetoothctl --timeout 8 scan on >/dev/null 2>&1 || true
  exec "$0"
}

device_menu() {
  local mac="$1" info alias connected paired trusted choice rows
  info="$(bluetoothctl info "$mac" 2>/dev/null || true)"
  alias="$(awk -F': ' '/^\s*Alias:/ {print $2; exit}' <<<"$info")"
  [[ -n $alias ]] || alias="$mac"
  connected="$(awk -F': ' '/^\s*Connected:/ {print $2; exit}' <<<"$info")"
  paired="$(awk -F': ' '/^\s*Paired:/ {print $2; exit}' <<<"$info")"
  trusted="$(awk -F': ' '/^\s*Trusted:/ {print $2; exit}' <<<"$info")"

  if [[ $connected == "yes" ]]; then
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
    rows="  Power off
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
    *"Scan for devices"*)
      scan_devices
      ;;
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
