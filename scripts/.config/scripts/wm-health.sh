#!/usr/bin/env bash
set -u

# wm-health.sh - concise AwesomeWM/X11 desktop health report.
# Built from the older awesome-dump-state diagnostic pattern, expanded for the
# full AwesomeWM + Polybar + picom + Dunst + keyring stack.

section() {
  printf '\n== %s ==\n' "$1"
}

run() {
  printf '$ %s\n' "$*"
  "$@" 2>&1 || true
}

have() {
  command -v "$1" >/dev/null 2>&1
}

show_env_subset() {
  grep -E '^(DISPLAY|XAUTHORITY|XDG_SESSION_TYPE|XDG_CURRENT_DESKTOP|XDG_SESSION_DESKTOP|DESKTOP_SESSION|WAYLAND_DISPLAY|ELECTRON_OZONE_PLATFORM_HINT|OZONE_PLATFORM|MOZ_ENABLE_WAYLAND|GDK_BACKEND|QT_QPA_PLATFORM|QT_QPA_PLATFORMTHEME|CLUTTER_BACKEND|GNOME_KEYRING_CONTROL|SSH_AUTH_SOCK)=' || true
}

section "Session env"
printf '%s\n' "-- shell --"
env | sort | show_env_subset

awesome_pid="$(pgrep -u "$USER" -x awesome | head -n 1 || true)"
printf '\n%s\n' "-- awesome process --"
if [[ -n "$awesome_pid" && -r "/proc/$awesome_pid/environ" ]]; then
  tr '\0' '\n' < "/proc/$awesome_pid/environ" | sort | show_env_subset
else
  echo "awesome process env unavailable"
fi

printf '\n%s\n' "-- systemd user --"
if have systemctl; then
  systemctl --user show-environment 2>/dev/null | sort | show_env_subset
else
  echo "systemctl not found"
fi

section "Display layout"
if have xrandr; then
  printf '%s\n' "-- monitors --"
  xrandr --listmonitors 2>&1 || true
  printf '\n%s\n' "-- connected outputs --"
  xrandr --query 2>/dev/null | awk '/ connected/ { print }' || true
  printf '\n%s\n' "-- primary --"
  xrandr --query 2>/dev/null | awk '/ connected primary/ { print $1; found=1 } END { if (!found) print "none" }' || true
else
  echo "xrandr not found"
fi

section "AwesomeWM"
if have awesome; then
  run awesome --version | head -n 3
  run awesome -k
else
  echo "awesome not found"
fi
printf '\n%s\n' "-- process --"
pgrep -a awesome || echo "not running"

if have awesome-client; then
  printf '\n%s\n' "-- screens --"
  awesome-client 'local awful=require("awful"); local out=""; for s in screen do local g=s.geometry; out=out.."screen="..s.index.." geom="..g.x..","..g.y.." "..g.width.."x"..g.height.." layout="..(awful.layout.get(s).name or "unknown").." tag="..(s.selected_tag and s.selected_tag.name or "nil").." padding_top="..tostring((s.padding or {}).top).."\n" end; return out' 2>&1 || true
  printf '\n%s\n' "-- clients --"
  awesome-client 'local out=""; for _, c in ipairs(client.get()) do local g=c:geometry(); out=out..(c.class or "nil").." | "..(c.name or "nil").." | screen="..tostring(c.screen.index).." | floating="..tostring(c.floating).." | fullscreen="..tostring(c.fullscreen).." | maximized="..tostring(c.maximized).." | geom="..g.x..","..g.y.." "..g.width.."x"..g.height.."\n" end; return out' 2>&1 || true
fi

section "Polybar"
pgrep -a polybar || echo "not running"
printf '\n%s\n' "-- log: /tmp/polybar-main.log --"
if [[ -f /tmp/polybar-main.log ]]; then
  tail -n 40 /tmp/polybar-main.log
else
  echo "missing"
fi

section "picom"
pgrep -a picom || echo "not running"
if have picom; then
  run picom --version | head -n 5
  printf '\n%s\n' "-- diagnostics excerpt --"
  timeout 5s picom --diagnostics 2>&1 | head -n 80 || true
else
  echo "picom not found"
fi

section "Dunst / notifications"
pgrep -a dunst || echo "dunst not running"
printf '\n%s\n' "-- notification bus owner --"
if have busctl; then
  busctl --user list 2>/dev/null | grep -E 'org.freedesktop.Notifications|dunst|awesome' || true
else
  echo "busctl not found"
fi
if have dunstctl; then
  printf '\n%s\n' "-- dunst paused --"
  dunstctl is-paused 2>&1 || true
fi

section "Rofi"
if have rofi; then
  rofi -version 2>&1 || true
else
  echo "rofi not found"
fi

section "Keyring / Polkit"
printf '%s\n' "-- secrets bus --"
if have busctl; then
  busctl --user list 2>/dev/null | grep -Ei 'secret|gnome-keyring' || true
  busctl --user status org.freedesktop.secrets 2>/dev/null | head -n 20 || true
else
  echo "busctl not found"
fi
printf '\n%s\n' "-- keyring processes --"
pgrep -a gnome-keyring || echo "gnome-keyring-daemon not running"
printf '\n%s\n' "-- polkit/auth processes --"
pgrep -a polkit || true
ps -u "$USER" -o pid,comm,args 2>/dev/null | grep -Ei 'polkit|agent|auth' | grep -v grep || true

section "Dependencies"
for cmd in jq pactl wpctl pamixer nmcli rfkill bluetoothctl brightnessctl flameshot notify-send xclip xrandr awesome awesome-client polybar polybar-msg picom dunst dunstctl rofi busctl systemctl pkexec; do
  if have "$cmd"; then
    printf 'ok      %s -> %s\n' "$cmd" "$(command -v "$cmd")"
  else
    printf 'missing %s\n' "$cmd"
  fi
done
