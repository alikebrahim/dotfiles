-------------------------------------------------------------------------------
-- services.cpu — reads /proc/stat, computes utilisation from two samples.
-- Emits: awesome.emit_signal("service::cpu", state)
-------------------------------------------------------------------------------
local gears = require("gears")

local cpu = {}
local state = { percentage = 0, loadavg = "" }

local prev_total, prev_idle = 0, 0
local _polling = false

local function emit()
    awesome.emit_signal("service::cpu", state)
end

local function read_all(path)
    local file = io.open(path, "r")
    if not file then return nil end
    local contents = file:read("*a")
    file:close()
    return contents
end

local function sample(cb)
    local stat = read_all("/proc/stat")
    if not stat then return end

    local line = stat:match("(cpu%s+[^\n]+)")
    if not line then return end

    local nums = {}
    for value in line:gmatch("%d+") do
        table.insert(nums, tonumber(value))
    end

    local user = nums[1] or 0
    local nice = nums[2] or 0
    local system = nums[3] or 0
    local idle = nums[4] or 0
    local iowait = nums[5] or 0
    local irq = nums[6] or 0
    local softirq = nums[7] or 0
    local steal = nums[8] or 0
    local idle_total = idle + iowait
    local total = user + nice + system + idle_total + irq + softirq + steal

    local loadavg = read_all("/proc/loadavg")
    if loadavg then
        state.loadavg = loadavg:match("^(%S+%s+%S+%s+%S+)") or state.loadavg
    end

    cb(total, idle_total)
end

local function compute()
    sample(function(total, idle)
        local td, id = total - prev_total, idle - prev_idle
        if td > 0 then
            state.percentage = math.floor(100 * (1 - (id / td)))
        end
        prev_total, prev_idle = total, idle
        emit()
    end)
end

function cpu.refresh() compute() end
function cpu.get_state() return state end

local timer = gears.timer {
    timeout = 10,
    autostart = false,
    call_now = false,
    callback = compute,
}

local warmup_timer = gears.timer {
    timeout = 0.5,
    single_shot = true,
    autostart = false,
    call_now = false,
    callback = function()
        if _polling then compute() end
    end,
}

function cpu.set_polling(active)
    active = active and true or false
    if active == _polling then return end
    _polling = active

    if active then
        sample(function(total, idle)
            prev_total, prev_idle = total, idle
        end)
        if warmup_timer.started then warmup_timer:stop() end
        warmup_timer:start()
        timer:start()
    else
        if warmup_timer.started then warmup_timer:stop() end
        timer:stop()
    end
end

return cpu
