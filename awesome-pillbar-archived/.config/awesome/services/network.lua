-------------------------------------------------------------------------------
-- services.network — NetworkManager via nmcli (terse mode).
-- Emits: awesome.emit_signal("service::network", state)
-------------------------------------------------------------------------------
local awful = require("awful")
local gears = require("gears")

local network = {}
local _polling = false
local _refresh_generation = 0
local state = {
    available = false,
    enabled = true,
    connected = false,
    ssid = "",
    strength = 0,
    security = "",
    device = "",
    networks = {},
}

local function emit()
    awesome.emit_signal("service::network", state)
end

local function split_terse(line)
    local fields = {}
    local current = {}
    local escaped = false

    for index = 1, #line do
        local char = line:sub(index, index)
        if escaped then
            table.insert(current, char)
            escaped = false
        elseif char == "\\" then
            escaped = true
        elseif char == ":" then
            table.insert(fields, table.concat(current))
            current = {}
        else
            table.insert(current, char)
        end
    end
    if escaped then table.insert(current, "\\") end
    table.insert(fields, table.concat(current))
    return fields
end

local function clear_wifi_state()
    state.connected = false
    state.ssid = ""
    state.strength = 0
    state.security = ""
    state.networks = {}
end

local function mark_unavailable()
    state.available = false
    state.enabled = false
    state.device = ""
    clear_wifi_state()
    emit()
end

local function begin_mutation()
    _refresh_generation = _refresh_generation + 1
    mark_unavailable()
end

local function refresh_wifi(generation, rescan)
    awful.spawn.easy_async({
        "nmcli", "-t", "-f", "ACTIVE,SSID,SIGNAL,SECURITY",
        "device", "wifi", "list", "--rescan", rescan and "yes" or "no",
    }, function(stdout, _, _, rc)
        if generation ~= _refresh_generation then return end
        clear_wifi_state()
        if rc ~= 0 or not stdout then
            mark_unavailable()
            return
        end

        for line in stdout:gmatch("[^\r\n]+") do
            local parts = split_terse(line)
            local active = parts[1]
            local ssid = parts[2]
            local signal = tonumber(parts[3]) or 0
            local security = parts[4] or ""
            if ssid and ssid ~= "" then
                table.insert(state.networks, {
                    ssid = ssid,
                    signal = signal,
                    security = security,
                })
                if active == "yes" or active == "*" then
                    state.connected = true
                    state.ssid = ssid
                    state.strength = signal
                    state.security = security
                end
            end
        end
        emit()
    end)
end

local function refresh_status(generation, rescan)
    awful.spawn.easy_async({ "nmcli", "-t", "-f", "DEVICE,TYPE,STATE", "device", "status" },
        function(stdout, _, _, rc)
            if generation ~= _refresh_generation then return end
            if rc ~= 0 or not stdout then
                mark_unavailable()
                return
            end

            state.device = ""
            for line in stdout:gmatch("[^\r\n]+") do
                local parts = split_terse(line)
                if parts[2] == "wifi" then
                    state.device = parts[1] or ""
                    if parts[3] == "connected" then break end
                end
            end
            refresh_wifi(generation, rescan)
        end)
end

function network.refresh(force_scan)
    _refresh_generation = _refresh_generation + 1
    local generation = _refresh_generation

    awful.spawn.easy_async({ "nmcli", "radio", "wifi" }, function(stdout, _, _, rc)
        if generation ~= _refresh_generation then return end
        if rc ~= 0 or not stdout then
            mark_unavailable()
            return
        end

        state.available = true
        state.enabled = stdout:match("^enabled") ~= nil
        if not state.enabled then
            state.device = ""
            clear_wifi_state()
            emit()
            return
        end
        refresh_status(generation, force_scan == true)
    end)
end

function network.set_enabled(on)
    begin_mutation()
    awful.spawn.easy_async({ "nmcli", "radio", "wifi", on and "on" or "off" },
        function(_, _, _, rc)
            if rc == 0 then network.refresh() else mark_unavailable() end
        end)
end

function network.scan() network.refresh(true) end

function network.connect_known(connection_name)
    if not connection_name or connection_name == "" then return end
    begin_mutation()
    awful.spawn.easy_async({ "nmcli", "connection", "up", connection_name }, function(_, _, _, rc)
        if rc == 0 then network.refresh() else mark_unavailable() end
    end)
end

function network.disconnect()
    if not state.device or state.device == "" then return end
    local device = state.device
    begin_mutation()
    awful.spawn.easy_async({ "nmcli", "device", "disconnect", device }, function(_, _, _, rc)
        if rc == 0 then network.refresh() else mark_unavailable() end
    end)
end

function network.open_settings()
    awful.spawn({ "nm-connection-editor" }, false)
end

function network.get_state() return state end

local timer = gears.timer {
    timeout = 60,
    autostart = false,
    call_now = false,
    callback = function() network.refresh() end,
}

function network.set_polling(active)
    active = active and true or false
    if active == _polling then return end
    _polling = active

    if active then
        network.refresh()
        timer:start()
    else
        timer:stop()
        _refresh_generation = _refresh_generation + 1
    end
end

return network
