-------------------------------------------------------------------------------
-- services.bluetooth — BlueZ via bluetoothctl.
-- Emits: awesome.emit_signal("service::bluetooth", state)
-- Addresses validated before interpolation.
-------------------------------------------------------------------------------
local awful = require("awful")
local gears = require("gears")

local bluetooth = {}
local ADDR = "^%x%x:%x%x:%x%x:%x%x:%x%x:%x%x$"
local _polling = false
local _refresh_generation = 0
local _scan_generation = 0
local scan_timer

local state = {
    available = false,
    powered = false,
    scanning = false,
    devices = {},
}

local function emit()
    awesome.emit_signal("service::bluetooth", state)
end

local function stop_scan_state()
    _scan_generation = _scan_generation + 1
    state.scanning = false
    if scan_timer and scan_timer.started then scan_timer:stop() end
end

local function mark_unavailable()
    state.available = false
    state.powered = false
    state.devices = {}
    stop_scan_state()
    emit()
end

function bluetooth.refresh()
    _refresh_generation = _refresh_generation + 1
    local generation = _refresh_generation

    awful.spawn.easy_async({ "bluetoothctl", "show" }, function(stdout, _, _, rc)
        if generation ~= _refresh_generation then return end
        if rc ~= 0 or not stdout or stdout == "" then
            mark_unavailable()
            return
        end

        state.available = true
        state.powered = stdout:match("Powered:%s*yes") ~= nil
        if not state.powered then
            state.devices = {}
            stop_scan_state()
            emit()
            return
        end

        awful.spawn.easy_async({ "bluetoothctl", "devices", "Paired" }, function(paired_out, _, _, paired_rc)
            if generation ~= _refresh_generation then return end
            if paired_rc ~= 0 or not paired_out then
                mark_unavailable()
                return
            end

            local devices = {}
            for line in paired_out:gmatch("[^\r\n]+") do
                local addr, name = line:match("Device%s+(%x%x:%x%x:%x%x:%x%x:%x%x:%x%x)%s+(.+)")
                if addr then
                    table.insert(devices, {
                        address = addr,
                        name = name or "?",
                        paired = true,
                        connected = false,
                        trusted = false,
                    })
                end
            end

            awful.spawn.easy_async({ "bluetoothctl", "devices", "Connected" },
                function(connected_out, _, _, connected_rc)
                    if generation ~= _refresh_generation then return end
                    if connected_rc ~= 0 or not connected_out then
                        mark_unavailable()
                        return
                    end

                    local connected = {}
                    for line in connected_out:gmatch("[^\r\n]+") do
                        local addr = line:match("Device%s+(%x%x:%x%x:%x%x:%x%x:%x%x:%x%x)")
                        if addr then connected[addr] = true end
                    end
                    for _, device in ipairs(devices) do
                        device.connected = connected[device.address] == true
                    end
                    state.devices = devices
                    state.available = true
                    emit()
                end)
        end)
    end)
end

function bluetooth.set_power(on)
    _refresh_generation = _refresh_generation + 1
    mark_unavailable()
    awful.spawn.easy_async({ "bluetoothctl", "power", on and "on" or "off" },
        function(_, _, _, rc)
            if rc == 0 then bluetooth.refresh() else mark_unavailable() end
        end)
end

scan_timer = gears.timer {
    timeout = 10,
    single_shot = true,
    autostart = false,
    call_now = false,
    callback = function()
        if state.scanning then bluetooth.scan(false) end
    end,
}

function bluetooth.scan(on)
    _scan_generation = _scan_generation + 1
    local generation = _scan_generation
    state.scanning = on
    emit()

    awful.spawn.easy_async({ "bluetoothctl", "scan", on and "on" or "off" },
        function(_, _, _, rc)
            if generation ~= _scan_generation then return end
            if rc ~= 0 then
                mark_unavailable()
            elseif not on then
                bluetooth.refresh()
            end
        end)

    -- Bounded scan: auto-stop after 10s.
    if on then
        if scan_timer.started then scan_timer:stop() end
        scan_timer:start()
    else
        if scan_timer.started then scan_timer:stop() end
    end
end

function bluetooth.connect(addr)
    if not addr or not addr:match(ADDR) then return end
    _refresh_generation = _refresh_generation + 1
    mark_unavailable()
    awful.spawn.easy_async({ "bluetoothctl", "connect", addr }, function(_, _, _, rc)
        if rc == 0 then bluetooth.refresh() else mark_unavailable() end
    end)
end

function bluetooth.disconnect(addr)
    if not addr or not addr:match(ADDR) then return end
    _refresh_generation = _refresh_generation + 1
    mark_unavailable()
    awful.spawn.easy_async({ "bluetoothctl", "disconnect", addr }, function(_, _, _, rc)
        if rc == 0 then bluetooth.refresh() else mark_unavailable() end
    end)
end

function bluetooth.get_state() return state end

local timer = gears.timer {
    timeout = 60,
    autostart = false,
    call_now = false,
    callback = function() bluetooth.refresh() end,
}

function bluetooth.set_polling(active)
    active = active and true or false
    if active == _polling then return end
    _polling = active

    if active then
        bluetooth.refresh()
        timer:start()
    else
        timer:stop()
        _refresh_generation = _refresh_generation + 1
        local was_scanning = state.scanning
        stop_scan_state()
        if was_scanning then
            awful.spawn.easy_async({ "bluetoothctl", "scan", "off" }, function() end)
        end
    end
end

return bluetooth
