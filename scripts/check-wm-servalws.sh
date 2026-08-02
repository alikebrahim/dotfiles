#!/usr/bin/env bash
# Diagnose Window Manager component status on servalws.
# Checks: current Quickshell/Awesome processes, source links, IPC, D-Bus
# ownership, bridge state, active helpers, and retired-runtime absence.
#
# Run ON servalws:  bash ~/.dotfiles/scripts/check-wm-servalws.sh
# Or from netmaster: ssh servalws 'bash ~/.dotfiles/scripts/check-wm-servalws.sh'

set -euo pipefail

echo "=== Window Manager Diagnostic for $(hostname) ==="
echo "Date: $(date)"
echo ""

# --- 1. Running WM processes -----------------------------------------------
echo "--- 1. Running WM processes ---"
for proc in awesome quickshell picom xss-lock; do
  if pgrep -x "$proc" >/dev/null 2>&1; then
    pid=$(pgrep -x "$proc" | head -1)
    echo "  [RUNNING]  $proc (PID: $pid)"
  else
    echo "  [STOPPED]  $proc"
  fi
done
echo ""

# --- 2. Installed binaries -------------------------------------------------
echo "--- 2. Installed binaries ---"
for bin in awesome quickshell picom feh xss-lock i3lock flameshot xclip busctl jq; do
  path=$(command -v "$bin" 2>/dev/null || true)
  if [[ -n "$path" ]]; then
    echo "  [INSTALLED]  $bin -> $path"
  else
    echo "  [MISSING]    $bin"
  fi
done
echo ""

# --- 3. Config files: symlink status ---------------------------------------
echo "--- 3. Config files (symlink from dotfiles?) ---"
for cfg in \
  "$HOME/.config/awesome/rc.lua" \
  "$HOME/.config/awesome/theme.lua" \
  "$HOME/.config/awesome/keys.lua" \
  "$HOME/.config/awesome/rules.lua" \
  "$HOME/.config/awesome/signals.lua" \
  "$HOME/.config/awesome/dynamism.lua" \
  "$HOME/.config/picom/picom.conf" \
  "$HOME/.config/quickshell/shell.qml" \
  "$HOME/.config/quickshell/services/DbusOwnershipService.qml" \
  "$HOME/.config/quickshell/awesome-integration/bridge.lua" \
; do
  if [[ -L "$cfg" ]]; then
    target=$(readlink -f "$cfg")
    if [[ -e "$target" ]]; then
      echo "  [SYMLINK OK]  $cfg"
    else
      echo "  [BROKEN LINK] $cfg -> $target (target missing)"
    fi
  elif [[ -f "$cfg" ]]; then
    echo "  [REAL FILE]   $cfg (NOT symlinked from dotfiles)"
  elif [[ -d "$cfg" ]]; then
    echo "  [DIR]         $cfg (real directory, not symlink)"
  else
    echo "  [MISSING]     $cfg"
  fi
done
echo ""

# --- 4. AwesomeWM config check ---------------------------------------------
echo "--- 4. AwesomeWM config validity ---"
if command -v awesome >/dev/null 2>&1; then
  if [[ -d "$HOME/.config/awesome" ]]; then
    cd "$HOME/.config/awesome"
    if awesome -k 2>&1; then
      echo "  [PASS] awesome -k"
    else
      echo "  [FAIL] awesome -k returned errors"
    fi
  else
    echo "  [SKIP] ~/.config/awesome not found"
  fi
else
  echo "  [SKIP] awesome not installed"
fi
echo ""

# --- 5. Current helper package ---------------------------------------------
echo "--- 5. Current awesome_wm_scripts package ---"
SCRIPTS_DIR="$HOME/.config/scripts"
if [[ -d "$SCRIPTS_DIR" ]]; then
  echo "  Helpers present in ~/.config/scripts/:"
  for script in "$SCRIPTS_DIR"/*.sh; do
    [[ -f "$script" ]] || continue
    name=$(basename "$script")
    if [[ -L "$script" ]]; then
      link_status="symlink"
    else
      link_status="real file"
    fi
    if [[ -x "$script" ]]; then
      exec_status="executable"
    else
      exec_status="NOT executable"
    fi
    echo "    $name: $link_status, $exec_status"
  done
else
  echo "  [MISSING] ~/.config/scripts/ directory not found"
fi
echo ""

# --- 6. Quickshell ownership and bridge ------------------------------------
echo "--- 6. Quickshell IPC, ownership, and bridge ---"
if command -v quickshell >/dev/null 2>&1; then
  quickshell --path "$HOME/.config/quickshell/shell.qml" ipc call shell status 2>&1 \
    || echo "  [FAIL] Quickshell shell IPC unavailable"
else
  echo "  [MISSING] quickshell"
fi
if command -v busctl >/dev/null 2>&1; then
  for name in org.freedesktop.Notifications org.kde.StatusNotifierWatcher; do
    echo "  -- $name --"
    busctl --user --no-pager status "$name" 2>&1 | head -n 8 || true
  done
fi
STATE_PATH="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/quickshell-awesome/state.json"
if [[ -r "$STATE_PATH" ]]; then
  if command -v jq >/dev/null 2>&1; then
    jq '{producerGeneration,publishedAtMs,primaryOutput,focusedOutput,workspaceIndex,workspaceSynchronized}' "$STATE_PATH" 2>&1 || true
  else
    echo "  [PRESENT] $STATE_PATH"
  fi
else
  echo "  [MISSING] $STATE_PATH"
fi
echo ""

# --- 7. Retired runtime absence --------------------------------------------
echo "--- 7. Retired runtime absence ---"
for proc in rofi polybar dunst; do
  if pgrep -x "$proc" >/dev/null 2>&1; then
    echo "  [STALE PROCESS] $proc"
  else
    echo "  [ABSENT] $proc process"
  fi
done
for path in "$HOME/.config/rofi" "$HOME/.config/polybar" "$HOME/.config/dunst"; do
  if [[ -e "$path" || -L "$path" ]]; then
    echo "  [STALE TARGET] $path"
  else
    echo "  [ABSENT] $path"
  fi
done
echo ""

# --- 8. Bling vendor --------------------------------------------------------
echo "--- 8. Awesome bling vendor ---"
BLING="$HOME/.config/awesome/vendor/bling"
if [[ -d "$BLING" ]]; then
  echo "  bling: [PRESENT] $(find "$BLING" -name '*.lua' | wc -l) lua files"
else
  echo "  bling: [MISSING] (dynamism.lua requires it for scratchpad)"
fi
echo ""

# --- 9. Background image ---------------------------------------------------
echo "--- 9. Background image (feh) ---"
BG="$HOME/Pictures/background.png"
if [[ -f "$BG" ]]; then
  echo "  background.png: [PRESENT]"
else
  echo "  background.png: [MISSING] (rc.lua references it for feh)"
fi
echo ""

echo "=== Diagnostic complete ==="
