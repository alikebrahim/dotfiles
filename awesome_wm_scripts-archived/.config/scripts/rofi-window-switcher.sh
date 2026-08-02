#!/usr/bin/env bash
set -euo pipefail

# Window switcher for AwesomeWM with [WS:SCREEN] context labels.
#
# Queries awesome-client for all clients in a single Lua call, formats each as:
#   [WS:SCREEN] Class — Title
# where WS is the workspace index and SCREEN is L/R/C based on screen geometry.
# On selection, switches to the window's workspace (synced across all screens),
# focuses the screen, and raises the client.
#
# Bound to Mod+Tab in keys.lua.

THEME="$HOME/.config/rofi/window-switcher.rasi"

need() {
  command -v "$1" >/dev/null 2>&1 || {
    notify-send -u critical "Window Switcher" "Missing command: $1" 2>/dev/null || true
    exit 1
  }
}

for cmd in rofi awesome-client; do
  need "$cmd"
done

# Query AwesomeWM for all clients in a single Lua evaluation.
# Returns lines of: window_id \x1f class \x1f title \x1f workspace_label
#   \x1f workspace_index \x1f screen_index \x1f screen_label \x1f indicators
# Uses \x1f (unit separator) as field delimiter to survive titles with pipes/spaces.
query_windows() {
  awesome-client <<'LUA'
-- Build screen label map (L/R/C) in one pass
local screens = {}
for s in screen do
    table.insert(screens, {idx = s.index, x = s.geometry.x})
end
table.sort(screens, function(a, b) return a.x < b.x end)

local label_map = {}
if #screens <= 1 then
    for _, s in ipairs(screens) do label_map[s.idx] = "C" end
else
    for i, s in ipairs(screens) do
        if i == 1 then label_map[s.idx] = "L"
        elseif i == #screens then label_map[s.idx] = "R"
        else label_map[s.idx] = "C" end
    end
end

-- Build window list
local parts = {}
for _, c in ipairs(client.get()) do
    local class = tostring(c.class or "")
    if c.valid and c.type ~= "desktop" and c.type ~= "dock"
        and class:lower() ~= "scratchpad" then
        local ws_label = "S"
        local ws_index = 0
        local first_tag = c.first_tag
        if first_tag then
            ws_index = tonumber(first_tag.index) or 0
            ws_label = ws_index > 0 and tostring(ws_index) or "S"
        end
        local sidx = c.screen and c.screen.index or 0
        local label = label_map[sidx] or "C"
        local indicators = ""
        if c.maximized then indicators = indicators .. "M" end
        if c.fullscreen then indicators = indicators .. "F" end
        if c.minimized then indicators = indicators .. "H" end
        table.insert(parts, string.format(
            "%s\x1f%s\x1f%s\x1f%s\x1f%d\x1f%d\x1f%s\x1f%s",
            tostring(c.window),
            class ~= "" and class or "unknown",
            tostring(c.name or "(untitled)"),
            ws_label,
            ws_index,
            sidx,
            label,
            indicators
        ))
    end
end
return table.concat(parts, "\n")
LUA
}

# Parse awesome-client output: strips the `   string "..."` wrapper.
# awesome-client prepends leading whitespace + "string " and wraps content in
# double-quotes. The content may span multiple lines (newlines in the Lua
# string become real newlines in the output).
parse_awesome_output() {
  sed 's/^ *string //; s/^"//; s/"$//'
}

# Focus a window by its X window ID via awesome-client.
focus_window() {
  local win_id="$1" ws_idx="$2"

  if [[ ! $win_id =~ ^[0-9]+$ || ! $ws_idx =~ ^[0-9]+$ ]]; then
    notify-send -u critical "Window Switcher" "Invalid window metadata" 2>/dev/null || true
    return 1
  fi

  local response
  response="$(awesome-client <<LUA
local awful = require("awful")
local win_id = ${win_id}
local ws_idx = ${ws_idx}

-- Find the client by window ID
local target = nil
for _, c in ipairs(client.get()) do
    if c.valid and c.window == win_id then
        target = c
        break
    end
end

if not target or not target.valid then return "ERR:not-found" end

-- Switch to the client's workspace on all screens (synced desktop model)
if ws_idx > 0 then
    for s in screen do
        local tag = s.tags[ws_idx]
        if tag then tag:view_only() end
    end
end

-- Reveal, focus, and raise the selected client.
target.minimized = false
if target.screen and target.screen.valid then
    awful.screen.focus(target.screen)
end
target.urgent = false
client.focus = target
target:raise()
return "OK:focused"
LUA
  )"

  if [[ $response != *"OK:focused"* ]]; then
    notify-send -u critical "Window Switcher" "${response:-Window activation failed}" 2>/dev/null || true
    return 1
  fi
}

# Build the rofi input list from awesome-client output.
# Output: display_line \x1e win_id \x1e ws_idx
# \x1e (record separator) splits display text from hidden metadata.
build_window_list() {
  local raw
  raw=$(query_windows 2>/dev/null | parse_awesome_output) || return 1

  [ -z "$raw" ] && return 0

  while IFS= read -r line; do
    [ -z "$line" ] && continue
    IFS=$'\x1f' read -r win_id class title ws_label ws_idx screen_idx screen_label indicators <<< "$line"

    # Build prefix: [WS:SCREEN] with optional state indicators
    local prefix="[${ws_label}:${screen_label}]"
    [ -n "$indicators" ] && prefix="${prefix} ${indicators}"

    # Truncate long titles for readability
    local short_title="$title"
    [ ${#title} -gt 60 ] && short_title="${title:0:57}..."

    printf '%s %s — %s\x1e%s\x1e%s\n' "$prefix" "$class" "$short_title" "$win_id" "$ws_idx"
  done <<< "$raw"
}

# --- Main ---

choice=$(build_window_list | rofi -dmenu -i -no-custom \
  -theme "$THEME" \
  -kb-row-up "Up,Control+p" \
  -kb-row-down "Down,Control+n" \
  -display-columns 1 \
  -display-column-separator $'\x1e' \
  2>/dev/null) || exit 0

[ -z "$choice" ] && exit 0

# Extract hidden metadata after \x1e
IFS=$'\x1e' read -r display win_id ws <<< "$choice"
[ -z "$win_id" ] && exit 0

focus_window "$win_id" "$ws"
