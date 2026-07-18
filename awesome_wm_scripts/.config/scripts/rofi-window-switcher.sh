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
# Returns lines of: window_id \x1f class \x1f title \x1f workspace \x1f screen_index \x1f screen_label
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
    if c.valid and c.type ~= "desktop" and c.type ~= "dock" then
        local ws = "S"
        local first_tag = c.first_tag
        if first_tag then ws = tostring(first_tag.index) end
        local sidx = c.screen and c.screen.index or 0
        local label = label_map[sidx] or "C"
        local indicators = ""
        if c.maximized then indicators = indicators .. "M" end
        if c.fullscreen then indicators = indicators .. "F" end
        if c.minimized then indicators = indicators .. "H" end
        table.insert(parts, string.format(
            "%s\x1f%s\x1f%s\x1f%s\x1f%d\x1f%s\x1f%s",
            tostring(c.window),
            tostring(c.class),
            tostring(c.name),
            ws,
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

  awesome-client <<LUA
local win_id = "${win_id}"
local ws_idx = ${ws_idx}

-- Find the client by window ID
local target = nil
for _, c in ipairs(client.get()) do
    if c.valid and tostring(c.window) == win_id then
        target = c
        break
    end
end

if not target then return end

-- Switch to the client's workspace on all screens (synced desktop model)
if ws_idx > 0 then
    for s in screen do
        local tag = s.tags[ws_idx]
        if tag then tag:view_only() end
    end
end

-- Focus the screen and client
if target.screen and target.screen.valid then
    awful.screen.focus(target.screen)
end
target.urgent = false
client.focus = target
target:raise()
LUA
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
    IFS=$'\x1f' read -r win_id class title ws screen_idx screen_label indicators <<< "$line"

    # Build prefix: [WS:SCREEN] with optional state indicators
    local prefix="[${ws}:${screen_label}]"
    [ -n "$indicators" ] && prefix="${prefix} ${indicators}"

    # Truncate long titles for readability
    local short_title="$title"
    [ ${#title} -gt 60 ] && short_title="${title:0:57}..."

    printf '%s %s — %s\x1e%s\x1e%s\n' "$prefix" "$class" "$short_title" "$win_id" "$ws"
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

focus_window "$win_id" "$ws" 2>/dev/null || true
