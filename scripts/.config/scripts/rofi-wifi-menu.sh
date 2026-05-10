#!/bin/bash
set -euo pipefail

THEME="$HOME/.config/rofi/control-menu.rasi"

need() {
  command -v "$1" >/dev/null 2>&1 || {
    notify-send -u critical "Wi-Fi menu" "Missing command: $1" 2>/dev/null || true
    exit 1
  }
}

for cmd in rofi nmcli rfkill notify-send awk sort sed; do
  need "$cmd"
done

notify() {
  notify-send "Wi-Fi" "$1" -t 1800
}

wifi_iface() {
  nmcli -t -f DEVICE,TYPE device status | awk -F: '$2 == "wifi" {print $1; exit}'
}

wifi_radio() {
  nmcli -t -f WIFI general 2>/dev/null | tail -n 1
}

current_ssid() {
  nmcli -t -f ACTIVE,SSID dev wifi list --rescan no 2>/dev/null | awk -F: '$1 == "yes" {print $2; exit}'
}

current_signal() {
  nmcli -t -f ACTIVE,SIGNAL dev wifi list --rescan no 2>/dev/null | awk -F: '$1 == "yes" {print $2; exit}'
}

known_connection() {
  local ssid="$1"
  nmcli -t -f NAME connection show | awk -F: -v ssid="$ssid" '$1 == ssid {found=1} END {exit !found}'
}

rfkill_state() {
  rfkill list wifi 2>/dev/null | awk -F': ' '
    /Soft blocked/ {soft=$2}
    /Hard blocked/ {hard=$2}
    END {
      if (soft == "yes" || hard == "yes") printf " · blocked soft %s hard %s", soft, hard
    }'
}

status_line() {
  local iface radio ssid sig status rf
  iface="$(wifi_iface)"
  radio="$(wifi_radio)"
  ssid="$(current_ssid)"
  sig="$(current_signal)"
  rf="$(rfkill_state)"

  [[ -n $iface ]] || iface="no interface"
  if [[ $radio == "disabled" ]]; then
    status="off"
  elif [[ -n $ssid ]]; then
    status="connected $ssid"
    [[ -n $sig ]] && status="$status · ${sig}%"
  else
    status="disconnected"
  fi

  printf '󰖩 Wi-Fi · %s · %s%s' "$iface" "$status" "$rf"
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

network_rows() {
  local iface="$1"
  [[ -n $iface ]] || return 0
  nmcli -t -f ACTIVE,SSID,SIGNAL,SECURITY dev wifi list ifname "$iface" --rescan no 2>/dev/null |
    awk -F: '
      $2 != "" {
        active=$1; ssid=$2; signal=$3; sec=$4;
        if (!(ssid in best) || signal + 0 > best[ssid] + 0) {
          best[ssid]=signal; security[ssid]=sec; is_active[ssid]=active;
        }
      }
      END {
        for (ssid in best) {
          icon=(is_active[ssid] == "yes") ? "●" : "○";
          sec=security[ssid]; lock=(sec == "" || sec == "--") ? "open" : "locked";
          printf "%s  󰖩  %s · %s%% · %s\n", icon, ssid, best[ssid], lock;
        }
      }' | sort -k4 -nr
}

password_prompt() {
  local ssid="$1"
  rofi -dmenu -password -p "Password" -mesg "󰖩 $ssid" -theme "$THEME" </dev/null
}

manual_connect() {
  local iface ssid password
  iface="$(wifi_iface)"
  [[ -n $iface ]] || { notify-send -u critical "Wi-Fi" "No Wi-Fi interface found"; return 1; }
  ssid="$(rofi -dmenu -p "SSID" -mesg "󰀦 Manual hidden network" -theme "$THEME" </dev/null)" || return 0
  [[ -n $ssid ]] || return 0
  password="$(password_prompt "$ssid")" || password=""
  rfkill unblock wifi
  nmcli radio wifi on
  if [[ -n $password ]]; then
    nmcli dev wifi connect "$ssid" password "$password" ifname "$iface" && notify "Connected to $ssid"
  else
    nmcli dev wifi connect "$ssid" ifname "$iface" && notify "Connected to $ssid"
  fi
}

connect_ssid() {
  local row="$1" iface ssid security password
  iface="$(wifi_iface)"
  [[ -n $iface ]] || { notify-send -u critical "Wi-Fi" "No Wi-Fi interface found"; return 1; }
  ssid="$(printf '%s' "$row" | sed -E 's/^[●○]  󰖩  //; s/ · [0-9]+% · .*$//')"
  security="$(printf '%s' "$row" | sed -E 's/^.* · [0-9]+% · //')"
  [[ -n $ssid ]] || return 0

  rfkill unblock wifi
  nmcli radio wifi on

  if known_connection "$ssid"; then
    nmcli connection up id "$ssid" && notify "Connected to $ssid"
    return
  fi

  if [[ $security == "open" || $security == "--" ]]; then
    nmcli dev wifi connect "$ssid" ifname "$iface" && notify "Connected to $ssid"
  else
    password="$(password_prompt "$ssid")" || return 0
    [[ -n $password ]] || return 0
    nmcli dev wifi connect "$ssid" password "$password" ifname "$iface" && notify "Connected to $ssid"
  fi
}

rescan_networks() {
  local iface="$1"
  rfkill unblock wifi
  nmcli radio wifi on

  (
    sleep 0.2
    nmcli dev wifi rescan ifname "$iface" >/dev/null 2>&1 || true
    sleep 1
    pkill -u "$USER" -x rofi 2>/dev/null || true
  ) &
  local scan_pid=$!

  set +e
  printf '󰑓  Scanning for networks...\n󰌑  This window will refresh automatically\n' | rofi_menu "Wi-Fi" "󰖩 Wi-Fi · scanning..."
  set -e

  wait "$scan_pid" || true
  "$0"
  exit 0
}

show_menu() {
  local iface radio ssid rows choice
  iface="$(wifi_iface)"
  radio="$(wifi_radio)"
  ssid="$(current_ssid)"

  if [[ -z $iface ]]; then
    notify-send -u critical "Wi-Fi" "No Wi-Fi interface found"
    exit 1
  fi

  if [[ $radio == "disabled" ]]; then
    rows="󰖩  Turn Wi-Fi on
󰀦  Manual hidden network"
  else
    rows="󰖩  Rescan networks"
    if [[ -n $ssid ]]; then
      rows="$rows
󰤭  Disconnect Wi-Fi"
    fi
    rows="$rows
󰖪  Turn Wi-Fi off
󰀦  Manual hidden network
$(network_rows "$iface")"
  fi

  choice="$(printf '%s\n' "$rows" | rofi_menu "Wi-Fi" "$(status_line)")" || exit 0

  case "${choice:-}" in
    *"Turn Wi-Fi on"*)
      rfkill unblock wifi
      nmcli radio wifi on
      notify "Wi-Fi on"
      exec "$0"
      ;;
    *"Turn Wi-Fi off"*)
      nmcli radio wifi off
      notify "Wi-Fi off"
      ;;
    *"Rescan networks"*)
      rescan_networks "$iface"
      ;;
    *"Manual hidden network"*)
      manual_connect
      ;;
    *"Disconnect Wi-Fi"*)
      nmcli device disconnect "$iface" && notify "Disconnected $iface"
      ;;
    [●○]*"󰖩"*)
      connect_ssid "$choice"
      ;;
  esac
}

show_menu
