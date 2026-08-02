#!/usr/bin/env bash
set -euo pipefail

echo "== AwesomeWM syntax =="
if command -v awesome >/dev/null 2>&1; then
  awesome -k || true
else
  echo "awesome: not found"
fi

echo
echo "== Monitors =="
if command -v xrandr >/dev/null 2>&1; then
  xrandr --listmonitors || true
  echo
  xrandr --query | awk '/ connected/{print}' || true
else
  echo "xrandr: not found"
fi

echo
echo "== Key processes =="
for proc in awesome quickshell picom xss-lock; do
  echo "-- $proc --"
  pgrep -a "$proc" || echo "not running"
done

echo
echo "== Awesome screens =="
if command -v awesome-client >/dev/null 2>&1; then
  awesome-client 'local awful=require("awful"); local out=""; for s in screen do out=out.."screen="..s.index.." geom="..s.geometry.x..","..s.geometry.y.." "..s.geometry.width.."x"..s.geometry.height.." layout="..(awful.layout.get(s).name or "unknown").." tag="..(s.selected_tag and s.selected_tag.name or "nil").." padding_top="..tostring((s.padding or {}).top).."\n" end; return out' || true
else
  echo "awesome-client: not found"
fi

echo
echo "== Awesome clients =="
if command -v awesome-client >/dev/null 2>&1; then
  awesome-client 'local out=""; for _, c in ipairs(client.get()) do local g=c:geometry(); out=out..(c.class or "nil").." | "..(c.name or "nil").." | screen="..tostring(c.screen.index).." | tag="..(c.first_tag and c.first_tag.name or "nil").." | floating="..tostring(c.floating).." | fullscreen="..tostring(c.fullscreen).." | maximized="..tostring(c.maximized).." | max_h="..tostring(c.maximized_horizontal).." | max_v="..tostring(c.maximized_vertical).." | ontop="..tostring(c.ontop).." | above="..tostring(c.above).." | below="..tostring(c.below).." | minimized="..tostring(c.minimized).." | geom="..g.x..","..g.y.." "..g.width.."x"..g.height.."\n" end; return out' || true
else
  echo "awesome-client: not found"
fi

echo
echo "== Quickshell status =="
if command -v quickshell >/dev/null 2>&1; then
  quickshell --path "$HOME/.config/quickshell/shell.qml" ipc call shell status 2>&1 || true
else
  echo "quickshell: not found"
fi

echo
echo "== Quickshell D-Bus ownership =="
if command -v busctl >/dev/null 2>&1; then
  for name in org.freedesktop.Notifications org.kde.StatusNotifierWatcher; do
    echo "-- $name --"
    busctl --user --no-pager status "$name" 2>&1 | head -n 10 || true
  done
else
  echo "busctl: not found"
fi
