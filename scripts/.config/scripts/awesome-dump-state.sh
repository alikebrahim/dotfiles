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
for proc in awesome polybar picom dunst xss-lock; do
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
echo "== Polybar logs, last 10 lines each =="
shopt -s nullglob
logs=(/tmp/polybar-*.log /tmp/polybar-main.log)
if [ "${#logs[@]}" -eq 0 ]; then
  echo "no polybar logs found"
else
  for log in "${logs[@]}"; do
    [ -e "$log" ] || continue
    echo "-- $log --"
    tail -n 10 "$log" || true
  done
fi
