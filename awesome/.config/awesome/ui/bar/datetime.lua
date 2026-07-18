-------------------------------------------------------------------------------
-- ui.bar.datetime — centre pill: date + time + optional unread dot.
--
-- Left click: toggle calendar/notification popup.
-- Right click: open popup on notifications tab.
-------------------------------------------------------------------------------
local awful = require("awful")
local wibox = require("wibox")
local gears = require("gears")
local beautiful = require("beautiful")
local dpi = require("beautiful.xresources").apply_dpi
local pill = require("ui.bar.pill")
local notifs = require("services.notifications")

local datetime = {}

local function make_widget(s)
    local clock = wibox.widget.textclock(" <b>%H:%M</b> ", 60)
    clock.font = beautiful.font
    local date = wibox.widget.textclock("<span foreground='" ..
        (beautiful.bar_pill_fg_muted or beautiful.fg_minimize) ..
        "'>%A, %d %b</span>  ", 60)
    date.font = beautiful.font

    -- Unread dot.
    local dot = wibox.widget.textbox()
    dot.visible = false

    local content = wibox.layout.fixed.horizontal()
    content.spacing = dpi(6)
    content:add(date)
    content:add(clock)
    content:add(dot)

    local function refresh_dot()
        if notifs.unread > 0 then
            dot.visible = true
            dot.markup = '<span foreground="' .. (beautiful.bar_urgent or beautiful.bg_urgent) ..
                '">●</span>'
        else
            dot.visible = false
            dot.markup = ""
        end
    end
    refresh_dot()
    awesome.connect_signal("service::notifications", refresh_dot)

    -- The pill; its active state is driven by the popup manager via the returned bg.
    local p, bg = pill {
        child = content,
        hover = true,
        buttons = gears.table.join(
            awful.button({}, 1, function()
                -- anchor = the pill itself
                awesome.emit_signal("pill::toggle_popup", "info", p, s)
            end),
            awful.button({}, 3, function()
                awesome.emit_signal("pill::toggle_popup", "info_notifs", p, s)
            end)
        ),
    }
    return p, bg
end

return setmetatable(datetime, { __call = function(_, ...) return make_widget(...) end })
