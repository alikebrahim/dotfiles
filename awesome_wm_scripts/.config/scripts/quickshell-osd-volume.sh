#!/usr/bin/env bash
set -euo pipefail

QS_CONFIG="/home/alikebrahim/.dotfiles/quickshell_work/.config/shell.qml"

usage() {
  printf 'Usage: %s <percent> [muted]\n' "${0##*/}" >&2
  printf 'Example: %s 73 false\n' "${0##*/}" >&2
}

if [[ $# -lt 1 || $# -gt 2 ]]; then
  usage
  exit 2
fi

percent="$1"
muted="${2:-false}"

case "$percent" in
  ''|*[!0-9]*)
    printf 'Invalid percent: %s\n' "$percent" >&2
    exit 2
    ;;
esac

if (( percent < 0 )); then percent=0; fi
if (( percent > 100 )); then percent=100; fi

case "${muted,,}" in
  true|1|yes|muted|on) muted=true ;;
  false|0|no|unmuted|off) muted=false ;;
  *)
    printf 'Invalid muted value: %s\n' "$muted" >&2
    exit 2
    ;;
esac

if ! command -v quickshell >/dev/null 2>&1; then
  exit 0
fi

quickshell ipc -p "$QS_CONFIG" call osd showVolume "$percent" "$muted" >/dev/null 2>&1 || exit 0
