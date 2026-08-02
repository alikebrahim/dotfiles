#!/usr/bin/env bash
# Polybar module: AwesomeWM workspaces (single-screen, no duplication)
# Queries awesome-client for the primary screen's tags and outputs
# color-coded workspace indicators with click-to-switch.
#
# Uses switch-ws.sh helper for click actions (no xdotool needed).

set -euo pipefail

ACTIVE_FG="${POLYBAR_WS_ACTIVE:-#a6e3a1}"
OCCUPIED_FG="${POLYBAR_WS_OCCUPIED:-#cdd6f4}"
EMPTY_FG="${POLYBAR_WS_EMPTY:-#585b70}"
SWITCHER="$HOME/.config/polybar/switch-ws.sh"

while true; do
    output=""
    state=$(awesome-client '
local s = screen.primary
local out = ""
for i, t in ipairs(s.tags) do
    local sel = t.selected and 1 or 0
    local occ = (#t:clients() > 0) and 1 or 0
    out = out .. t.name .. ":" .. sel .. ":" .. occ .. "|"
end
return out
' 2>/dev/null | sed -n '/^   string "/{s/^   string "//;s/"$//;p}' | sed 's/\\"/"/g')

    IFS='|' read -ra entries <<< "$state"
    for entry in "${entries[@]}"; do
        [[ -z "$entry" ]] && continue
        IFS=':' read -r name sel occ <<< "$entry"

        if [[ "$sel" == "1" ]]; then
            fg="$ACTIVE_FG"
        elif [[ "$occ" == "1" ]]; then
            fg="$OCCUPIED_FG"
        else
            fg="$EMPTY_FG"
        fi

        output+="%{F${fg}}%{A1:${SWITCHER} ${name}:}  ${name}  %{A}%{F-} "
    done

    echo "$output"
    sleep 0.5
done
