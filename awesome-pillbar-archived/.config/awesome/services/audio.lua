-------------------------------------------------------------------------------
-- services.audio — PipeWire/WirePlumber primary, pactl fallback.
--
-- Emits signal:  awesome.emit_signal("service::audio", state)
-- State shape: { available, volume (0..1), muted }
--
-- All commands run asynchronously. No blocking io.popen.
-------------------------------------------------------------------------------
local awful = require("awful")
local gears = require("gears")
local naughty = require("naughty.core")

local audio = {}
local state = {
    available = false,
    volume = 0,
    muted = false,
}

local MAX_VOLUME = 1.0  -- clamp to 100%; raise to allow amplification
local _fail_logged = false
local _polling = false

local function find_executable(name)
    for directory in ((os.getenv("PATH") or "") .. ":"):gmatch("([^:]*):") do
        if directory == "" then directory = "." end
        local path = directory .. "/" .. name
        local file = io.open(path, "r")
        if file then
            file:close()
            return path
        end
    end
    return nil
end

local wpctl_path = find_executable("wpctl")
local pactl_path = find_executable("pactl")
local _backend = wpctl_path and "wpctl" or (pactl_path and "pactl" or nil)

local function emit()
    awesome.emit_signal("service::audio", state)
end

local function mark_unavailable(reason)
    if not _fail_logged then
        _fail_logged = true
        naughty.notify {
            urgency = "normal",
            title = "Audio service",
            text = "No audio server available",
        }
    end
    state.available = false
    emit()
end

-- Parse "Volume: 0.72" output from `wpctl get-volume @DEFAULT_AUDIO_SINK@`.
local function refresh_wpctl()
    awful.spawn.easy_async({ wpctl_path, "get-volume", "@DEFAULT_AUDIO_SINK@" }, function(stdout, _, _, exitcode)
        if exitcode ~= 0 or not stdout or stdout == "" then
            mark_unavailable()
            return
        end
        _fail_logged = false
        local vol = tonumber(stdout:match("Volume:%s*([%d%.]+)"))
        local muted = stdout:match("%[MUTED%]") ~= nil
        state.volume = vol or state.volume
        state.muted = muted
        state.available = true
        emit()
    end)
end

-- pactl fallback parser.
local function refresh_pactl()
    awful.spawn.easy_async({ pactl_path, "get-sink-volume", "@DEFAULT_SINK@" }, function(stdout, _, _, exitcode)
        if exitcode ~= 0 or not stdout then mark_unavailable(); return end
        _fail_logged = false
        local pct = stdout:match("/%s*(%d+)%%%s*/")
        state.volume = pct and (tonumber(pct) / 100) or state.volume
        awful.spawn.easy_async({ pactl_path, "get-sink-mute", "@DEFAULT_SINK@" }, function(mout, _, _, mute_rc)
            if mute_rc ~= 0 or not mout then mark_unavailable(); return end
            state.available = true
            state.muted = mout:match("Mute:%s*yes") ~= nil
            emit()
        end)
    end)
end

local function refresh_backend()
    if _backend == "wpctl" then
        refresh_wpctl()
    elseif _backend == "pactl" then
        refresh_pactl()
    else
        mark_unavailable()
    end
end

function audio.refresh()
    refresh_backend()
end

--- Set absolute volume (0..1).
function audio.set_volume(percent)
    percent = math.max(0, math.min(percent, MAX_VOLUME))
    state.volume = percent
    emit()

    local command
    if _backend == "wpctl" then
        command = { wpctl_path, "set-volume", "@DEFAULT_AUDIO_SINK@", string.format("%.2f", percent) }
    elseif _backend == "pactl" then
        command = { pactl_path, "set-sink-volume", "@DEFAULT_SINK@", math.floor(percent * 100 + 0.5) .. "%" }
    else
        mark_unavailable()
        return
    end

    awful.spawn.easy_async(command, function(_, _, _, rc)
        if rc == 0 then audio.refresh() else mark_unavailable() end
    end)
end

--- Change volume by a delta in percentage points (e.g. 0.05 for 5%).
function audio.change_volume(delta)
    audio.set_volume(state.volume + delta)
end

function audio.toggle_mute()
    local command
    if _backend == "wpctl" then
        command = { wpctl_path, "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle" }
    elseif _backend == "pactl" then
        command = { pactl_path, "set-sink-mute", "@DEFAULT_SINK@", "toggle" }
    else
        mark_unavailable()
        return
    end

    awful.spawn.easy_async(command, function(_, _, _, rc)
        if rc == 0 then audio.refresh() else mark_unavailable() end
    end)
end

function audio.get_state() return state end

-- Periodic refresh is a fallback safety net; hardware-key changes update state
-- immediately. The timer is active only while the pill bar is visible.
local timer = gears.timer {
    timeout = 30,
    autostart = false,
    call_now = false,
    callback = function() audio.refresh() end,
}

function audio.set_polling(active)
    active = active and true or false
    if active == _polling then return end
    _polling = active

    if active then
        audio.refresh()
        timer:start()
    else
        timer:stop()
    end
end

return audio
