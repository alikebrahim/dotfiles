-- AwesomeWM -> Quickshell state bridge.
--
-- Writes a small, hand-built JSON file to $XDG_RUNTIME_DIR whenever
-- tag/focus-relevant state changes, so Quickshell's BridgeState.qml can
-- pick it up live via FileView{watchChanges:true} (the same mechanism
-- already proven for theme_tokens.json).
--
-- Deliberately does NOT use any JSON library. lgi.Json's serializer is
-- broken on this host's installed GIR version (confirmed:
-- "bad argument #-1 to 'ctor' (number expected, got nil)" on a basic
-- object-builder round-trip), and cjson/dkjson aren't installed. The
-- state shape here is small and flat enough that plain string
-- concatenation is correct and far simpler than debugging a broken
-- GObject-introspection binding. See revamp/ambiguities.md #8.
local awful = require("awful")

local bridge = {}

local STATE_PATH = (os.getenv("XDG_RUNTIME_DIR") or "/tmp") .. "/awesome-bridge-state.json"

-- Escape the handful of free-text fields (client names/classes) that can
-- contain characters JSON needs escaped. Tag names/indices are always
-- plain ASCII digits in this config, so they're written unescaped.
local function json_escape(s)
    if s == nil then
        return ""
    end
    s = tostring(s)
    s = s:gsub("\\", "\\\\")
    s = s:gsub('"', '\\"')
    s = s:gsub("\n", "\\n")
    s = s:gsub("\r", "\\r")
    s = s:gsub("\t", "\\t")
    -- Strip other control characters outright rather than risk emitting
    -- invalid JSON for something a window title could theoretically contain.
    s = s:gsub("[\1-\31]", "")
    return s
end

local function json_string(s)
    return '"' .. json_escape(s) .. '"'
end

local function json_bool(b)
    return b and "true" or "false"
end

local function screen_sort_index(s)
    local g = s.geometry
    return g.x, g.y
end

local function sorted_screens()
    local screens = {}
    for s in screen do
        table.insert(screens, s)
    end
    table.sort(screens, function(a, b)
        local ax, ay = screen_sort_index(a)
        local bx, by = screen_sort_index(b)
        if ax ~= bx then return ax < bx end
        return ay < by
    end)
    return screens
end

-- Build the JSON payload as a plain string. Shape:
-- {
--   "screens": [
--     {
--       "index": 1,
--       "primary": true,
--       "tags": [
--         {"index":1,"name":"1","active":true,"urgent":false,"clientCount":2},
--         ...
--       ]
--     },
--     ...
--   ],
--   "focused": {
--     "hasClient": true,
--     "name": "some window title",
--     "class": "some-app-class",
--     "screen": 1
--   }
-- }
local function build_state_json()
    local parts = {}
    table.insert(parts, '{"screens":[')

    local screens = sorted_screens()
    for si, s in ipairs(screens) do
        if si > 1 then table.insert(parts, ",") end
        table.insert(parts, '{"index":' .. s.index .. ',"primary":' .. json_bool(s == screen.primary) .. ',"tags":[')

        for ti, tag in ipairs(s.tags) do
            if ti > 1 then table.insert(parts, ",") end
            local tag_clients = tag:clients()
            local client_count = #tag_clients
            -- AwesomeWM tags have no native `urgent` property (urgency is
            -- tracked per-client via the `urgent` property/signal, not on
            -- the tag itself). Derive it: a tag is urgent if any client on
            -- it is urgent.
            local tag_urgent = false
            local client_parts = {}
            for ci, c in ipairs(tag_clients) do
                if c.urgent then
                    tag_urgent = true
                end
                -- Per-client detail array, added for the WindowSwitcher
                -- surface (Mod+Tab, revamp/plan.md) which needs to list
                -- and search actual open windows, not just a per-tag
                -- count. Kept minimal: name/class/urgent only, matching
                -- what the "focused" object already exposes below.
                if ci > 1 then table.insert(client_parts, ",") end
                table.insert(client_parts, string.format(
                    '{"name":%s,"class":%s,"urgent":%s}',
                    json_string(c.name),
                    json_string(c.class),
                    json_bool(c.urgent or false)
                ))
            end
            table.insert(parts, string.format(
                '{"index":%d,"name":%s,"active":%s,"urgent":%s,"clientCount":%d,"clients":[%s]}',
                ti,
                json_string(tag.name),
                json_bool(tag.selected),
                json_bool(tag_urgent),
                client_count,
                table.concat(client_parts)
            ))
        end

        table.insert(parts, "]}")
    end

    table.insert(parts, '],"focused":')

    local c = client.focus
    if c and c.valid then
        table.insert(parts, string.format(
            '{"hasClient":true,"name":%s,"class":%s,"screen":%d}',
            json_string(c.name),
            json_string(c.class),
            c.screen and c.screen.index or 0
        ))
    else
        table.insert(parts, '{"hasClient":false,"name":"","class":"","screen":0}')
    end

    table.insert(parts, "}")

    return table.concat(parts)
end

-- Atomic write: write to a temp file in the same directory, then rename
-- over the target. This avoids Quickshell's FileView ever observing a
-- half-written file (rename is atomic on the same filesystem, and
-- $XDG_RUNTIME_DIR is always a tmpfs so cross-device rename isn't a risk
-- here).
local function write_state()
    local tmp_path = STATE_PATH .. ".tmp"
    local f = io.open(tmp_path, "w")
    if not f then
        return
    end
    f:write(build_state_json())
    f:close()
    os.rename(tmp_path, STATE_PATH)
end

function bridge.setup()
    -- Tag selection changes (workspace switch on any screen).
    tag.connect_signal("property::selected", function()
        write_state()
    end)

    -- Focus changes.
    client.connect_signal("focus", function()
        write_state()
    end)
    client.connect_signal("unfocus", function()
        write_state()
    end)

    -- Client list changes (open/close affects clientCount per tag).
    client.connect_signal("manage", function()
        write_state()
    end)
    client.connect_signal("unmanage", function()
        write_state()
    end)
    client.connect_signal("tagged", function()
        write_state()
    end)
    client.connect_signal("untagged", function()
        write_state()
    end)
    -- Per-client urgency changes (feeds the derived tag_urgent flag above).
    client.connect_signal("property::urgent", function()
        write_state()
    end)

    -- Screen layout changes (monitor plug/unplug affects the screens array).
    screen.connect_signal("added", function()
        write_state()
    end)
    screen.connect_signal("removed", function()
        write_state()
    end)

    -- Write an initial state immediately on startup so Quickshell doesn't
    -- have to wait for the first signal to get real data.
    write_state()
end

return bridge
