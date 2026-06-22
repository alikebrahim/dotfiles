#!/usr/bin/env bash
# Diagnose Window Manager component status on servalws.
# Checks: running processes, installed binaries, config symlinks,
#          awesome config validity, script references, theme system.
#
# Run ON servalws:  bash ~/.dotfiles/static/check-wm-servalws.sh
# Or from netmaster: ssh servalws 'bash ~/.dotfiles/static/check-wm-servalws.sh'

set -euo pipefail

echo "=== Window Manager Diagnostic for $(hostname) ==="
echo "Date: $(date)"
echo ""

# --- 1. Running WM processes -----------------------------------------------
echo "--- 1. Running WM processes ---"
for proc in awesome picom dunst polybar; do
  if pgrep -x "$proc" >/dev/null 2>&1; then
    pid=$(pgrep -x "$proc" | head -1)
    echo "  [RUNNING]  $proc (PID: $pid)"
  else
    echo "  [STOPPED]  $proc"
  fi
done
# rofi is on-demand, not persistent — check if installed instead
echo ""

# --- 2. Installed binaries -------------------------------------------------
echo "--- 2. Installed binaries ---"
for bin in awesome picom dunst polybar rofi feh xss-lock i3lock flameshot; do
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
  "$HOME/.config/dunst/dunstrc" \
  "$HOME/.config/polybar/config.ini" \
  "$HOME/.config/polybar/colors.ini" \
  "$HOME/.config/polybar/launch.sh" \
  "$HOME/.config/rofi/config.rasi" \
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

# --- 5. awesome_wm_scripts: referenced vs orphaned -------------------------
echo "--- 5. awesome_wm_scripts: referenced vs orphaned ---"

# Scripts referenced by awesome rc.lua or keys.lua
AWESOME_REFS=(
  x11-session-env.sh
  x11-monitor-setup.sh
  rofi-keybinds.sh
  rofi-display-manager.sh
  wm-stabilize.sh
  rofi-power-menu.sh
  rofi-audio-menu.sh
  rofi-wifi-menu.sh
  rofi-bluetooth-menu.sh
  screenshot-flameshot.sh
)

# Scripts referenced by polybar config
POLYBAR_REFS=(
  rofi-calendar.sh
  rofi-audio-menu.sh
  rofi-wifi-menu.sh
  polybar-bluetooth-status.sh
  rofi-bluetooth-menu.sh
  rofi-power-menu.sh
)

# All known referenced scripts (unique)
declare -A REFERENCED
for s in "${AWESOME_REFS[@]}" "${POLYBAR_REFS[@]}"; do
  REFERENCED["$s"]=1
done

SCRIPTS_DIR="$HOME/.config/scripts"
if [[ -d "$SCRIPTS_DIR" ]]; then
  echo "  Scripts present in ~/.config/scripts/:"
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
    if [[ -n "${REFERENCED[$name]:-}" ]]; then
      ref_status="REFERENCED"
    else
      ref_status="ORPHANED (not referenced by awesome or polybar)"
    fi
    echo "    $name: $link_status, $exec_status, $ref_status"
  done
else
  echo "  [MISSING] ~/.config/scripts/ directory not found"
fi
echo ""

# --- 6. Theme system -------------------------------------------------------
echo "--- 6. Theme system ---"
THEME_NAME_FILE="$HOME/active_theme.name"
if [[ -f "$THEME_NAME_FILE" ]]; then
  if [[ -L "$THEME_NAME_FILE" ]]; then
    echo "  active_theme.name: [SYMLINK] -> $(readlink -f "$THEME_NAME_FILE")"
  else
    echo "  active_theme.name: [REAL FILE]"
  fi
  echo "  Active theme: $(cat "$THEME_NAME_FILE")"
else
  echo "  active_theme.name: [MISSING]"
fi

for tool in theme-select theme-apply; do
  path="$HOME/awesomewm-bin/$tool"
  if [[ -x "$path" ]]; then
    if [[ -L "$path" ]]; then
      echo "  $tool: [EXECUTABLE, symlink]"
    else
      echo "  $tool: [EXECUTABLE, real file]"
    fi
  elif [[ -f "$path" ]]; then
    echo "  $tool: [NOT EXECUTABLE]"
  else
    echo "  $tool: [MISSING]"
  fi
done

# Check theme library
THEME_LIB="$HOME/.dotfiles/themes/library"
if [[ -d "$THEME_LIB" ]]; then
  available=$(ls -1 "$THEME_LIB" 2>/dev/null | tr '\n' ' ')
  echo "  Available themes: $available"
else
  echo "  [MISSING] themes library at $THEME_LIB"
fi
echo ""

# --- 7. polybar launch script ----------------------------------------------
echo "--- 7. Polybar launch script ---"
LAUNCH="$HOME/.config/polybar/launch.sh"
if [[ -f "$LAUNCH" ]]; then
  if [[ -x "$LAUNCH" ]]; then
    echo "  launch.sh: [EXECUTABLE]"
  else
    echo "  launch.sh: [NOT EXECUTABLE]"
  fi
  if [[ -L "$LAUNCH" ]]; then
    echo "  launch.sh: [SYMLINK] -> $(readlink -f "$LAUNCH")"
  else
    echo "  launch.sh: [REAL FILE]"
  fi
else
  echo "  launch.sh: [MISSING]"
fi
echo ""

# --- 8. Bling vendor -------------------------------------------------------
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
