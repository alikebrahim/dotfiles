#!/usr/bin/env bash
# switch-to-quickshell.sh — bidirectional Polybar/Dunst/Rofi ↔ Quickshell cutover.
#
# Usage:
#   ./switch-to-quickshell.sh qs    Enable Quickshell, disable Polybar/Dunst/Rofi keybinds
#   ./switch-to-quickshell.sh pdr   Restore Polybar/Dunst/Rofi, disable Quickshell
#
# Design constraints:
#   - No deletions — only comment/uncomment lines, with explicit markers.
#   - Idempotent per mode: running `qs` twice is safe.
#   - Marker format per file type:
#       Lua:  -- QS_MARKER <tag>
#       QML:  // QS_MARKER <tag>
#       qmldir: # QS_MARKER
#   - Files modified live in the dotfiles repo.

set -euo pipefail

MODE="${1:-}"
if [[ "$MODE" != "qs" && "$MODE" != "pdr" ]]; then
    echo "Usage: $0 qs|pdr"
    echo "  qs  — switch to Quickshell"
    echo "  pdr — switch back to Polybar/Dunst/Rofi"
    exit 1
fi

DOTFILES="$(cd "$(dirname "$0")/.." && pwd)"
RC_LUA="${DOTFILES}/awesome/.config/awesome/rc.lua"
KEYS_LUA="${DOTFILES}/awesome/.config/awesome/keys.lua"
QMLDIR="${DOTFILES}/quickshell/.config/quickshell/services/qmldir"
SHELL_QML="${DOTFILES}/quickshell/.config/quickshell/shell.qml"

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'
log()  { echo -e "${GREEN}[switch]${NC} $*"; }
warn() { echo -e "${RED}[switch]${NC} $*"; }
die()  { warn "$@"; exit 1; }

require_file() { [[ -f "$1" ]] || die "File not found: $1"; }

# ---- helpers ---------------------------------------------------------------

# Comment out an entire line containing PATTERN, appending "-- QS_MARKER".
# PATTERN is a basic grep regex; it can appear anywhere in the line.
comment_line_lua() {
    local file="$1" pattern="$2"
    if grep -q "QS_MARKER" "$file" 2>/dev/null && grep "QS_MARKER" "$file" | grep -q "$pattern"; then
        return 0  # already handled
    fi
    sed -i "s/^\([[:space:]]*\)\(.*${pattern}.*\)$/\1-- \2  -- QS_MARKER/" "$file"
}

# Reverse of comment_line_lua.
uncomment_line_lua() {
    local file="$1" pattern="$2"
    sed -i "s/^\([[:space:]]*\)-- \([[:space:]]*.*${pattern}.*\)-- QS_MARKER[[:space:]]*$/\1\2/" "$file"
}

# ---- rc.lua ----------------------------------------------------------------

modify_rc_lua() {
    local mode="$1"
    require_file "$RC_LUA"

    if [[ "$mode" == "qs" ]]; then
        log "rc.lua: commenting Polybar + Dunst, uncommenting Quickshell autostart..."
        comment_line_lua "$RC_LUA" 'run_once_process("dunst"'
        comment_line_lua "$RC_LUA" 'spawn_shell.*polybar'
        sed -i 's/^\([[:space:]]*\)-- \([[:space:]]*run_once_process("quickshell".*\)$/\1\2/' "$RC_LUA"

        if ! grep -q "QS_MARKER bridge" "$RC_LUA" 2>/dev/null; then
            log "rc.lua: inserting bridge require+setup..."
            sed -i '/^local keys = require("keys")$/a\
\
-- Quickshell AwesomeWM bridge  -- QS_MARKER bridge\
local bridge_loaded, bridge = pcall(require, "bridge")\
if bridge_loaded then bridge.setup()\
else gears.debug.print_warning("bridge.lua not loaded")\
end  -- QS_MARKER bridge end' "$RC_LUA"
        fi
    else
        log "rc.lua: restoring Polybar + Dunst..."
        uncomment_line_lua "$RC_LUA" 'run_once_process("dunst"'
        uncomment_line_lua "$RC_LUA" 'spawn_shell.*polybar'
        sed -i 's/^\([[:space:]]*\)\(run_once_process("quickshell".*\)$/\1-- \2/' "$RC_LUA"

        if grep -q "QS_MARKER bridge" "$RC_LUA" 2>/dev/null; then
            log "rc.lua: removing bridge block..."
            sed -i '/-- QS_MARKER bridge$/,/-- QS_MARKER bridge end$/d' "$RC_LUA"
        fi
    fi
}

# ---- keys.lua --------------------------------------------------------------

modify_keys_lua() {
    local mode="$1"
    require_file "$KEYS_LUA"

    if [[ "$mode" == "qs" ]]; then
        log "keys.lua: commenting Rofi keybinds, inserting Quickshell IPC..."

        comment_line_lua "$KEYS_LUA" 'rofi -show drun'
        comment_line_lua "$KEYS_LUA" 'rofi -show window'
        comment_line_lua "$KEYS_LUA" 'rofi-audio-menu'
        comment_line_lua "$KEYS_LUA" 'awful.layout.inc'
        comment_line_lua "$KEYS_LUA" 'rofi-power-menu'
        comment_line_lua "$KEYS_LUA" 'rofi-wifi-menu'
        comment_line_lua "$KEYS_LUA" 'rofi-bluetooth-menu'
        comment_line_lua "$KEYS_LUA" 'theme-select'

        # Insert IPC keybinds after their commented originals.
        # Use a marker line in the file as insertion anchor.

        if ! grep -q "QS_MARKER launcher" "$KEYS_LUA" 2>/dev/null; then
            sed -i '/rofi -show drun.*QS_MARKER/a\
  awful.key({ modkey }, "space", function() awful.spawn("quickshell ipc call launcher toggle") end, { description = "application launcher", group = "launcher" }),  -- QS_MARKER launcher' "$KEYS_LUA"
        fi
        if ! grep -q "QS_MARKER window-switcher" "$KEYS_LUA" 2>/dev/null; then
            sed -i '/rofi -show window.*QS_MARKER/a\
  awful.key({ modkey }, "Tab", function() awful.spawn("quickshell ipc call windowSwitcher toggle") end, { description = "window switcher", group = "launcher" }),  -- QS_MARKER window-switcher' "$KEYS_LUA"
        fi
        if ! grep -q "QS_MARKER quickpanel" "$KEYS_LUA" 2>/dev/null; then
            sed -i '/rofi-audio-menu.*QS_MARKER/a\
  awful.key({ modkey, "Shift" }, "a", function() awful.spawn("quickshell ipc call quickPanel toggle") end, { description = "quick control panel", group = "launcher" }),  -- QS_MARKER quickpanel' "$KEYS_LUA"
        fi
        if ! grep -q "QS_MARKER quickapps" "$KEYS_LUA" 2>/dev/null; then
            sed -i '/awful.layout.inc.*QS_MARKER/a\
  awful.key({ modkey, "Shift" }, "space", function() awful.spawn("quickshell ipc call quickApps toggle") end, { description = "quick apps menu", group = "launcher" }),  -- QS_MARKER quickapps' "$KEYS_LUA"
        fi
        if ! grep -q "QS_MARKER fullpanel" "$KEYS_LUA" 2>/dev/null; then
            sed -i '/QS_MARKER launcher$/a\
  awful.key({ modkey }, "c", function() awful.spawn("quickshell ipc call fullPanel toggle") end, { description = "full control panel", group = "launcher" }),  -- QS_MARKER fullpanel' "$KEYS_LUA"
        fi
        if ! grep -q "QS_MARKER notif-center" "$KEYS_LUA" 2>/dev/null; then
            sed -i '/QS_MARKER fullpanel$/a\
  awful.key({ modkey }, "n", function() awful.spawn("quickshell ipc call notificationCenter toggle") end, { description = "notification center", group = "launcher" }),  -- QS_MARKER notif-center' "$KEYS_LUA"
        fi
    else
        log "keys.lua: restoring original Rofi keybinds..."
        uncomment_line_lua "$KEYS_LUA" 'rofi -show drun'
        uncomment_line_lua "$KEYS_LUA" 'rofi -show window'
        uncomment_line_lua "$KEYS_LUA" 'rofi-audio-menu'
        uncomment_line_lua "$KEYS_LUA" 'awful.layout.inc'
        uncomment_line_lua "$KEYS_LUA" 'rofi-power-menu'
        uncomment_line_lua "$KEYS_LUA" 'rofi-wifi-menu'
        uncomment_line_lua "$KEYS_LUA" 'rofi-bluetooth-menu'
        uncomment_line_lua "$KEYS_LUA" 'theme-select'

        log "keys.lua: removing Quickshell IPC keybinds..."
        sed -i '/-- QS_MARKER \(launcher\|window-switcher\|quickpanel\|quickapps\|fullpanel\|notif-center\)$/d' "$KEYS_LUA"
    fi
}

# ---- qmldir ----------------------------------------------------------------

modify_qmldir() {
    local mode="$1"
    require_file "$QMLDIR"

    if [[ "$mode" == "qs" ]]; then
        if ! grep -q "^singleton Notifications" "$QMLDIR" 2>/dev/null; then
            log "qmldir: registering Notifications singleton..."
            echo "singleton Notifications 1.0 Notifications.qml  # QS_MARKER" >> "$QMLDIR"
        fi
    else
        log "qmldir: removing Notifications singleton..."
        sed -i '/# QS_MARKER$/d' "$QMLDIR"
    fi
}

# ---- shell.qml -------------------------------------------------------------

modify_shell_qml() {
    local mode="$1"
    require_file "$SHELL_QML"

    if [[ "$mode" == "qs" ]]; then
        if ! grep -q "QS_MARKER notif-import" "$SHELL_QML" 2>/dev/null; then
            log "shell.qml: adding Notifications imports..."
            sed -i '/^import "modules\/Bar"$/a\
import "modules/Notifications"  // QS_MARKER notif-import' "$SHELL_QML"
            # Add Toast + NotificationCenter instances before closing brace of ShellRoot
            sed -i '/^}$/i\
\
    Toast { id: toast }  // QS_MARKER notif-toast\
    NotificationCenter { id: notificationCenter }  // QS_MARKER notif-center' "$SHELL_QML"
        fi
    else
        log "shell.qml: removing Notifications imports..."
        sed -i '/\/\/ QS_MARKER notif-/d' "$SHELL_QML"
    fi
}

# ---- main ------------------------------------------------------------------

echo ""
log "switch-to-quickshell.sh — mode: ${MODE}"
log "================================================"

modify_rc_lua    "$MODE"
modify_keys_lua  "$MODE"
modify_qmldir    "$MODE"
modify_shell_qml "$MODE"

# ---- deploy via stow -------------------------------------------------------

log "Deploying via stow..."
cd "$DOTFILES"
stow -R awesome 2>&1 | grep -v "^$" || true
stow -R quickshell 2>&1 | grep -v "^$" || true

# ---- process management ----------------------------------------------------

if [[ "$MODE" == "qs" ]]; then
    log "Stopping Polybar..."
    pkill polybar 2>/dev/null || true
    sleep 0.5

    # Dunst stays down — config already commented out, QS Notifications
    # takes over on next awesome restart. Kill it now so notification
    # D-Bus name is free when quickshell starts.
    log "Stopping Dunst..."
    pkill dunst 2>/dev/null || true
    sleep 0.5

    log "Starting Quickshell..."
    # Kill any lingering quickshell first, then start fresh
    pkill quickshell 2>/dev/null || true
    sleep 0.5
    DISPLAY="${DISPLAY:-:0}" quickshell -p "$DOTFILES/quickshell/.config/quickshell/shell.qml" &
    sleep 1

    if pgrep -x quickshell >/dev/null; then
        log "Quickshell is running (pid: $(pgrep -x quickshell | head -1))"
    else
        warn "Quickshell may have failed to start — check logs at ~/.local/state/quickshell/"
    fi
else
    log "Stopping Quickshell..."
    pkill quickshell 2>/dev/null || true
    sleep 0.5

    # Dunst and Polybar will re-launch on next awesome restart (their
    # autostart lines are uncommented). Start them now so the user
    # doesn't need to restart immediately.
    log "Starting Dunst..."
    pkill dunst 2>/dev/null || true; sleep 0.3
    dunst &
    sleep 0.5

    log "Starting Polybar..."
    pkill polybar 2>/dev/null || true; sleep 0.3
    bash /home/alikebrahim/.config/polybar/launch.sh &
    sleep 1

    log "Polybar and Dunst restarted."
fi

echo ""
log "Configuration and processes switched to ${MODE^^}."
log ""
log "Keybinds require an Awesome restart to take effect:"
log "  Mod+Shift+R   (reload AwesomeWM)"
log ""
log "To revert: $0 $( [[ "$MODE" == "qs" ]] && echo "pdr" || echo "qs" )"
log ""
