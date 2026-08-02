local awful = require("awful")
local beautiful = require("beautiful")
local gears = require("gears")

local repo_root = assert(os.getenv("QUATTRO_REPO_ROOT"), "QUATTRO_REPO_ROOT is required")
local event_log_path = assert(os.getenv("WMTEST_EVENT_LOG"), "WMTEST_EVENT_LOG is required")
local wmtest_nonce = assert(os.getenv("WMTEST_NONCE"), "WMTEST_NONCE is required")

_G.WMTEST_NONCE = wmtest_nonce

local function log_event(message)
    local file = assert(io.open(event_log_path, "a"))
    file:write(message, "\n")
    file:close()
end

log_event("config-loaded")

awesome.connect_signal("debug::error", function(err)
    log_event("awesome-error: " .. tostring(err))
end)

beautiful.border_width = 3
beautiful.border_normal = "#ff0000"
beautiful.border_focus = "#00ff00"
beautiful.useless_gap = 0

awful.layout.layouts = { awful.layout.suit.floating }

awful.screen.connect_for_each_screen(function(s)
    awful.tag({ "1" }, s, awful.layout.suit.floating)
    local outputs = {}
    for name in pairs(s.outputs or {}) do outputs[#outputs + 1] = name end
    local geometry = s.geometry
    log_event(string.format("screen index=%d geometry=%d,%d %dx%d outputs=%s",
        s.index, geometry.x, geometry.y, geometry.width, geometry.height, table.concat(outputs, ",")))
end)

local rules = assert(loadfile(repo_root .. "/awesome/.config/awesome/rules.lua"))()
local signals = assert(loadfile(repo_root .. "/awesome/.config/awesome/signals.lua"))()

awful.rules.rules = rules.get({}, {})
signals.setup()

client.connect_signal("manage", function(c)
    log_event("manage-enter")
    local initial = c:geometry()
    log_event(string.format(
        "manage name=%s class=%s instance=%s type=%s geometry=%d,%d %dx%d border=%s",
        tostring(c.name), tostring(c.class), tostring(c.instance), tostring(c.type),
        initial.x, initial.y, initial.width, initial.height, tostring(c.border_width)))
    gears.debug.print_warning(string.format(
        "wmtest-manage name=%s class=%s instance=%s type=%s geometry=%d,%d %dx%d border=%s\n",
        tostring(c.name), tostring(c.class), tostring(c.instance), tostring(c.type),
        initial.x, initial.y, initial.width, initial.height, tostring(c.border_width)))
    gears.timer.start_new(0.2, function()
        if not c.valid then return false end
        local settled = c:geometry()
        log_event(string.format(
            "settled name=%s class=%s instance=%s type=%s geometry=%d,%d %dx%d border=%s skip=%s",
            tostring(c.name), tostring(c.class), tostring(c.instance), tostring(c.type),
            settled.x, settled.y, settled.width, settled.height, tostring(c.border_width),
            tostring(c.skip_taskbar)))
        gears.debug.print_warning(string.format(
            "wmtest-settled name=%s class=%s instance=%s type=%s geometry=%d,%d %dx%d border=%s skip=%s\n",
            tostring(c.name), tostring(c.class), tostring(c.instance), tostring(c.type),
            settled.x, settled.y, settled.width, settled.height, tostring(c.border_width),
            tostring(c.skip_taskbar)))
        return false
    end)
end)

client.connect_signal("property::name", function(c)
    log_event("property-name: " .. tostring(c.name))
end)

client.connect_signal("property::type", function(c)
    log_event("property-type: " .. tostring(c.type))
end)

root.keys({})
root.buttons({})


