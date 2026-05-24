#!/usr/bin/env bash
set -euo pipefail

THEME="$HOME/.config/rofi/keybinds.rasi"

if ! command -v rofi >/dev/null 2>&1; then
  notify-send -u critical "Keybinds" "rofi is not installed" 2>/dev/null || true
  exit 1
fi

rows=$(cat <<'EOF'
━━━━ 󰍜 LAUNCH ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Launch        Super+Enter             Terminal
Launch        Super+Shift+Enter       Browser
Launch        Super+Space             Apps launcher
Launch        Super+Tab               Window switcher
Launch        Super+F                 Files
Launch        Super+Grave             Scratchpad terminal

━━━━ 󰕮 SYSTEM CONTROLS ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
System        Super+Shift+A           Audio controls
System        Super+Shift+W           Wi-Fi controls
System        Super+Shift+B           Bluetooth controls
System        Super+Esc               Power menu
System        Super+P                 Display manager
System        Super+Ctrl+T            Theme selector
System        Super+U                 Refresh monitors/UI

━━━━ 󰆾 WINDOW FOCUS / CLIENTS ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Window        Super+H                 Focus left / previous screen edge
Window        Super+J                 Focus down
Window        Super+K                 Focus up
Window        Super+L                 Focus right / next screen edge
Window        Super+M                 Toggle maximize
Window        Super+T                 Toggle floating
Window        Super+Ctrl+T            Toggle titlebar on focused window
Window        Super+Q                 Close focused window
Mouse         Super+Left Click        Move focused window
Mouse         Super+Right Click       Resize focused window

━━━━ 󰓩 SCREENS / WORKSPACES ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Screen        Super+Shift+H           Move window to previous screen
Screen        Super+Shift+L           Move window to next screen
Workspace     Super+Ctrl+J            Previous workspace
Workspace     Super+Ctrl+K            Next workspace
Workspace     Super+Shift+J           Move window to previous workspace and follow
Workspace     Super+Shift+K           Move window to next workspace and follow
Workspace     Super+1..5              View workspace 1..5
Workspace     Super+Shift+1..5        Move window to workspace 1..5

━━━━ 󰄀 SCREENSHOTS ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Screenshot    Print                   Interactive screenshot
Screenshot    Super+Print             Full screenshot
Screenshot    Super+Shift+S           Region screenshot

━━━━ 󰘳 AWESOMEWM ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Awesome       Super+S                 Show this help
Awesome       Super+Shift+Space       Next layout
Awesome       Super+Shift+R           Reload Awesome
Awesome       Super+Shift+Q           Quit Awesome
EOF
)

printf '%s\n' "$rows" | rofi -dmenu -i -no-custom \
  -p "Keybinds" \
  -mesg "󰌌 AwesomeWM shortcuts · type to filter by key, category, or action" \
  -theme "$THEME" \
  -kb-row-up "Up,Control+p" \
  -kb-row-down "Down,Control+n" >/dev/null
