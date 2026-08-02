-------------------------------------------------------------------------------
-- services.battery — UPower. Discovers the battery path; no hard-coded BAT0.
-- Emits: awesome.emit_signal("service::battery", state)
-------------------------------------------------------------------------------
local awful = require("awful")
local gears = require("gears")

local battery = {}
local _polling = false
local state = {
    available = false,
    percentage = 100,
    state_str = "unknown",
    time_to_empty_seconds = 0,
    time_to_full_seconds = 0,
    energy_rate = 0,
    warning_level = 0,
}

local function emit()
    awesome.emit_signal("service::battery", state)
end

local function parse_duration(stdout, label)
    local value, unit = stdout:match(label .. ":%s*([%d%.]+)%s+(%a+)")
    value = tonumber(value)
    if not value then return 0 end
    if unit:match("^hour") then return math.floor(value * 3600) end
    if unit:match("^minute") then return math.floor(value * 60) end
    if unit:match("^second") then return math.floor(value) end
    return 0
end

local function refresh()
    -- Use the DisplayDevice aggregate — covers laptops + UPS cleanly.
    awful.spawn.easy_async("upower -i /org/freedesktop/UPower/devices/DisplayDevice", function(stdout, _, _, rc)
        if rc ~= 0 or not stdout or stdout == "" then state.available = false; emit(); return end
        state.available = true
        local pct = stdout:match("percentage:%s*(%d+)")
        state.percentage = pct and tonumber(pct) or state.percentage
        local st = stdout:match("state:%s*([%w%-]+)")
        state.state_str = st or state.state_str
        state.time_to_empty_seconds = parse_duration(stdout, "time to empty")
        state.time_to_full_seconds = parse_duration(stdout, "time to full")
        local er = stdout:match("energy rate:%s*([%d%.]+)")
        state.energy_rate = er and tonumber(er) or 0
        local wl = stdout:match("warning%-level:%s*(%w+)")
        state.warning_level = (wl == "critical") and 3 or (wl == "low") and 2 or 0
        emit()
    end)
end

function battery.refresh() refresh() end
function battery.get_state() return state end

local timer = gears.timer {
    timeout = 45,
    autostart = false,
    call_now = false,
    callback = function() refresh() end,
}

function battery.set_polling(active)
    active = active and true or false
    if active == _polling then return end
    _polling = active

    if active then
        refresh()
        timer:start()
    else
        timer:stop()
    end
end

return battery
