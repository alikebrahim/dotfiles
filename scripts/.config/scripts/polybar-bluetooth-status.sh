#!/bin/bash
set -euo pipefail

command -v bluetoothctl >/dev/null 2>&1 || exit 0
[[ -d /sys/class/bluetooth ]] || exit 0

if ! bluetoothctl show >/tmp/polybar-bluetooth-show.$$ 2>/dev/null; then
  rm -f /tmp/polybar-bluetooth-show.$$
  exit 0
fi

if ! grep -q 'Powered: yes' /tmp/polybar-bluetooth-show.$$; then
  rm -f /tmp/polybar-bluetooth-show.$$
  printf '󰂲\n'
  exit 0
fi
rm -f /tmp/polybar-bluetooth-show.$$

mapfile -t paired < <(bluetoothctl devices Paired 2>/dev/null | awk '/^Device /{print $2}')
connected=()

for mac in "${paired[@]}"; do
  info="$(bluetoothctl info "$mac" 2>/dev/null || true)"
  if grep -q 'Connected: yes' <<<"$info"; then
    alias="$(awk -F': ' '/^\s*Alias:/ {print $2; exit}' <<<"$info")"
    [[ -n $alias ]] || alias="$mac"
    connected+=("$alias")
  fi
done

case "${#connected[@]}" in
  0) printf '\n' ;;
  1) printf ' %s\n' "${connected[0]}" ;;
  *) printf ' %s\n' "${#connected[@]}" ;;
esac
