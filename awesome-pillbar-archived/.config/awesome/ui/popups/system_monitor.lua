-------------------------------------------------------------------------------
-- ui.popups.system_monitor — CPU/RAM/battery detail popup.
-------------------------------------------------------------------------------
local awful = require("awful")
local wibox = require("wibox")
local gears = require("gears")
local beautiful = require("beautiful")
local dpi = require("beautiful.xresources").apply_dpi

local system_monitor = {}

local function stat_row(label, get_value)
    local value = wibox.widget.textbox(" …")
    value.font = beautiful.font
    awesome.connect_signal("service::cpu", function() value.markup = " " .. get_value() end)
    awesome.connect_signal("service::memory", function() value.markup = " " .. get_value() end)
    awesome.connect_signal("service::battery", function() value.markup = " " .. get_value() end)
    return wibox.widget {
        { markup = '<span foreground="' .. (beautiful.bar_pill_fg_muted or beautiful.fg_minimize) .. '">' .. label .. '</span>', font = beautiful.font, widget = wibox.widget.textbox },
        value,
        layout = wibox.layout.align.horizontal,
        forced_height = dpi(20),
    }
end

function system_monitor.new()
    local function kib_to_gib(k) return k and string.format("%.1f GiB", k / 1048576) or "—" end

    local cpu_pct = stat_row("CPU", function()
        local s = require("services.cpu").get_state(); return (s.percentage or 0) .. "%"
    end)
    local load = stat_row("Load", function()
        return require("services.cpu").get_state().loadavg or "—"
    end)
    local mem = stat_row("Memory", function()
        local s = require("services.memory").get_state()
        return kib_to_gib(s.used_kib) .. " / " .. kib_to_gib(s.total_kib)
    end)
    local bat = stat_row("Battery", function()
        local s = require("services.battery").get_state()
        if not s.available then return "not present" end
        return s.percentage .. "%"
    end)
    local bat_state = stat_row("State", function()
        local s = require("services.battery").get_state(); return s.state_str or "unknown"
    end)
    local bat_time = stat_row("Remaining", function()
        local s = require("services.battery").get_state()
        if not s.available then return "—" end
        local seconds = s.state_str == "charging"
            and s.time_to_full_seconds or s.time_to_empty_seconds
        if seconds and seconds > 0 then
            local h = math.floor(seconds / 3600)
            local m = math.floor((seconds % 3600) / 60)
            return string.format("%dh %dm", h, m)
        end
        return "—"
    end)

    local content = wibox.widget {
        { markup = '<span foreground="' .. (beautiful.bar_pill_fg_accent or beautiful.fg_focus) .. '"><b>System</b></span>', font = beautiful.font, widget = wibox.widget.textbox },
        cpu_pct, load,
        mem,
        bat, bat_state, bat_time,
        layout = wibox.layout.fixed.vertical,
        spacing = dpi(6),
    }

    local margin = wibox.container.margin(content, beautiful.popup_padding or dpi(12),
        beautiful.popup_padding or dpi(12), beautiful.popup_padding or dpi(12),
        beautiful.popup_padding or dpi(12))
    local box = wibox.container.background(margin, beautiful.popup_bg, function(cr, w, h)
        gears.shape.rounded_rect(cr, w, h, beautiful.popup_radius or dpi(10))
    end)
    box.forced_width = dpi(300)

    local pop = awful.popup {
        widget = box,
        border_width = beautiful.popup_border_width or dpi(1),
        border_color = beautiful.popup_border,
        visible = false,
        ontop = true,
        placement = function() end,
    }
    return pop
end

return setmetatable(system_monitor, { __call = function(_, ...) return system_monitor.new(...) end })
