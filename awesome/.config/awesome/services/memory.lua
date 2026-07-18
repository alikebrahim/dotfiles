-------------------------------------------------------------------------------
-- services.memory — reads /proc/meminfo, uses MemAvailable.
-- Emits: awesome.emit_signal("service::memory", state)
-------------------------------------------------------------------------------
local gears = require("gears")

local memory = {}
local state = { total_kib = 0, available_kib = 0, used_kib = 0, percentage = 0 }
local _polling = false

local function emit()
    awesome.emit_signal("service::memory", state)
end

local function refresh()
    local file = io.open("/proc/meminfo", "r")
    if not file then return end
    local contents = file:read("*a")
    file:close()

    local total = contents:match("MemTotal:%s+(%d+)")
    local avail = contents:match("MemAvailable:%s+(%d+)")
    state.total_kib = total and tonumber(total) or state.total_kib
    state.available_kib = avail and tonumber(avail) or state.available_kib
    state.used_kib = state.total_kib - state.available_kib
    if state.total_kib > 0 then
        state.percentage = math.floor(100 * state.used_kib / state.total_kib)
    end
    emit()
end

function memory.refresh() refresh() end
function memory.get_state() return state end

local timer = gears.timer {
    timeout = 10,
    autostart = false,
    call_now = false,
    callback = refresh,
}

function memory.set_polling(active)
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

return memory
