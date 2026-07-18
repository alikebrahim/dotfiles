#!/usr/bin/env bash
# lock-dispatcher.sh — read lock-settings.json, dispatch the right locker.
#
# Drop-in replacement for xss-lock's locker command.  Reads the "backend"
# field from ~/.config/quickshell/lock-settings.json and launches either
# i3lock (the current production locker) or the Quickshell-native lock
# screen (quickshell -p lock.qml).
#
# The FullPanel's AwesomeWM/Workspace card toggles the backend field in
# lock-settings.json — this script just reads it and acts, keeping the
# dispatch logic simple and testable independently of Quickshell itself.
#
# xss-lock invocation (in rc.lua or an autostart script):
#   xss-lock --transfer-sleep-lock -- /path/to/lock-dispatcher.sh

set -euo pipefail

SETTINGS="${HOME}/.config/quickshell/lock-settings.json"
DEFAULT_BACKEND="i3lock"

backend="${DEFAULT_BACKEND}"

if [[ -f "${SETTINGS}" ]] && command -v python3 >/dev/null 2>&1; then
    backend="$(python3 -c "
import json, sys
try:
    with open('${SETTINGS}') as f:
        d = json.load(f)
    print(d.get('backend', '${DEFAULT_BACKEND}'))
except Exception:
    print('${DEFAULT_BACKEND}')
" 2>/dev/null)" || backend="${DEFAULT_BACKEND}"
fi

case "${backend}" in
    quickshell|qs)
        exec quickshell -p "${HOME}/.dotfiles/quickshell/.config/quickshell/lock.qml"
        ;;
    i3lock|*)
        exec i3lock -c 1e1e2e --nofork
        ;;
esac
