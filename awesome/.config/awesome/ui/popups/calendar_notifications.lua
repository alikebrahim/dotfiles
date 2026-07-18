-------------------------------------------------------------------------------
-- ui.popups.calendar_notifications — tabbed centre popup.
--
-- Two tabs: Calendar and Notifications. Single-column layout, scrollable
-- notification list with height cap. Styled buttons and cards.
--
-- Signals:
--   awesome.emit_signal("pill::toggle_popup", "info", anchor, screen)
--   awesome.emit_signal("pill::toggle_popup", "info_notifs", anchor, screen)
-------------------------------------------------------------------------------
local awful = require("awful")
local wibox = require("wibox")
local gears = require("gears")
local beautiful = require("beautiful")
local dpi = require("beautiful.xresources").apply_dpi
local notifs = require("services.notifications")

local calendar_notifications = {}

local POPUP_WIDTH = dpi(360)
local MAX_NOTIF_HEIGHT = dpi(320)

-- ── helpers ──────────────────────────────────────────────────────────────

local function esc(text)
    return tostring(text or "")
        :gsub("&", "&amp;")
        :gsub("<", "&lt;")
        :gsub(">", "&gt;")
end

local function styled_button(label_text, on_click)
    local w = wibox.widget.textbox()
    w.font = beautiful.font
    w.markup = '<span foreground="' .. (beautiful.popup_fg or beautiful.fg_normal) .. '">' .. label_text .. '</span>'
    local padded = wibox.container.margin(w, dpi(10), dpi(10), dpi(5), dpi(5))
    local bg = wibox.container.background(padded, beautiful.popup_card_bg or "#363A40CC", function(cr, w, h)
        gears.shape.rounded_rect(cr, w, h, dpi(7))
    end)
    bg:buttons(gears.table.join(awful.button({}, 1, on_click)))
    bg:connect_signal("mouse::enter", function()
        bg.bg = beautiful.popup_button_bg_hover or "#434950EE"
    end)
    bg:connect_signal("mouse::leave", function()
        bg.bg = beautiful.popup_card_bg or "#363A40CC"
    end)
    return bg
end

-- ── calendar tab ─────────────────────────────────────────────────────────

local function make_calendar()
    local current_date = os.date("*t")
    local cal = wibox.widget.calendar.month(current_date)
    cal.font = beautiful.font
    cal.fn_embed = function(parent_widget, flag, date)
        local b = wibox.container.background()
        b:setup { parent_widget, widget = wibox.container.place }
        if flag == "focus" then
            b.bg = beautiful.bar_pill_fg_accent or beautiful.fg_focus
            b.fg = beautiful.bg_normal or "#1e1e2e"
            b.shape = function(cr, w, h) gears.shape.rounded_rect(cr, w, h, dpi(4)) end
        elseif flag == "header" then
            b.fg = beautiful.popup_fg or beautiful.fg_normal
        elseif flag == "weekday" then
            b.fg = beautiful.bar_pill_fg_muted or "#928d6f"
        else
            b.fg = beautiful.popup_fg or beautiful.fg_normal
        end
        return b
    end

    local label_w = wibox.widget.textbox()
    label_w.font = beautiful.font
    local function month_label()
        return os.date("%B %Y", os.time { year = current_date.year, month = current_date.month, day = 1 })
    end
    label_w.markup = "<b>" .. month_label() .. "</b>"

    local function nav(delta)
        current_date.month = current_date.month + delta
        if current_date.month > 12 then current_date.month = 1; current_date.year = current_date.year + 1 end
        if current_date.month < 1 then current_date.month = 12; current_date.year = current_date.year - 1 end
        cal:set_date { year = current_date.year, month = current_date.month, day = current_date.day }
        label_w.markup = "<b>" .. month_label() .. "</b>"
    end

    local function go_today()
        current_date = os.date("*t")
        cal:set_date(current_date)
        label_w.markup = "<b>" .. month_label() .. "</b>"
    end

    local header = wibox.widget {
        styled_button("‹", function() nav(-1) end),
        { label_w, widget = wibox.container.place },
        styled_button("›", function() nav(1) end),
        layout = wibox.layout.align.horizontal,
    }

    return wibox.widget {
        header,
        cal,
        styled_button("Today", go_today),
        layout = wibox.layout.fixed.vertical,
        spacing = dpi(8),
    }
end

-- ── notifications tab ────────────────────────────────────────────────────

local function make_notifications()
    local notif_list = wibox.layout.fixed.vertical()
    notif_list.spacing = dpi(6)

    local function time_ago(ts)
        local diff = os.time() - ts
        if diff < 60 then return "now" end
        if diff < 3600 then return math.floor(diff / 60) .. "m" end
        if diff < 86400 then return math.floor(diff / 3600) .. "h" end
        return os.date("%b %d", ts)
    end

    local function render_notifs()
        notif_list:reset()
        if #notifs.history == 0 then
            notif_list:add(wibox.widget {
                markup = '<span foreground="' .. (beautiful.bar_pill_fg_muted or "#928d6f") .. '">No notifications</span>',
                font = beautiful.font,
                widget = wibox.widget.textbox,
            })
            return
        end
        for _, e in ipairs(notifs.history) do
            local urgency_color = (e.urgency == "critical")
                and (beautiful.bar_urgent or beautiful.bg_urgent)
                or (beautiful.bar_pill_fg_accent or beautiful.fg_focus)
            local title = esc(e.title)
            if #title > 42 then title = title:sub(1, 41) .. "…" end
            local msg = esc(e.message)
            if #msg > 80 then msg = msg:sub(1, 79) .. "…" end
            local app = esc(e.app_name or "")
            local time = time_ago(e.time or os.time())

            local card = wibox.widget {
                {
                    {
                        markup = '<span foreground="' .. (beautiful.bar_pill_fg_muted or "#928d6f") .. '" size="small">' .. app .. ' · ' .. time .. '</span>',
                        font = beautiful.font,
                        widget = wibox.widget.textbox,
                    },
                    {
                        markup = '<span foreground="' .. urgency_color .. '"><b>' .. title .. '</b></span>',
                        font = beautiful.font,
                        widget = wibox.widget.textbox,
                    },
                    {
                        markup = '<span foreground="' .. (beautiful.popup_fg or beautiful.fg_normal) .. '">' .. msg .. '</span>',
                        font = beautiful.font,
                        widget = wibox.widget.textbox,
                    },
                    layout = wibox.layout.fixed.vertical,
                    spacing = dpi(2),
                },
                widget = wibox.container.margin,
                margins = dpi(8),
            }

            local card_bg = wibox.container.background(card, beautiful.popup_card_bg or "#363A40CC", function(cr, w, h)
                gears.shape.rounded_rect(cr, w, h, dpi(7))
            end)
            notif_list:add(card_bg)
        end
    end

    render_notifs()
    awesome.connect_signal("service::notifications", render_notifs)

    local scroll_area = wibox.widget {
        notif_list,
        layout = wibox.container.scroll.vertical,
        maximum_height = MAX_NOTIF_HEIGHT,
        step = dpi(40),
        speed = 5,
    }

    local footer = styled_button("Clear all", function() notifs.clear_all() end)

    return wibox.widget {
        scroll_area,
        footer,
        layout = wibox.layout.fixed.vertical,
        spacing = dpi(8),
    }
end

-- ── popup assembly ───────────────────────────────────────────────────────

function calendar_notifications.new()
    local cal_widget = make_calendar()
    local notif_widget = make_notifications()

    -- Tab state
    local active_tab = "calendar"

    local tab_cal = styled_button("Calendar", function() end)
    local tab_notif = styled_button("Notifications", function() end)

    local content_switcher = wibox.layout.fixed.vertical()

    local function refresh_tabs()
        local cal_fg = (active_tab == "calendar")
            and (beautiful.bar_pill_fg_accent or beautiful.fg_focus)
            or (beautiful.popup_fg or beautiful.fg_normal)
        local notif_fg = (active_tab == "notifications")
            and (beautiful.bar_pill_fg_accent or beautiful.fg_focus)
            or (beautiful.popup_fg or beautiful.fg_normal)
        tab_cal.children[1].children[1].markup = '<span foreground="' .. cal_fg .. '"><b>Calendar</b></span>'
        tab_notif.children[1].children[1].markup = '<span foreground="' .. notif_fg .. '"><b>Notifications</b></span>'
    end

    local function switch_tab(tab)
        active_tab = tab
        content_switcher:reset()
        if tab == "calendar" then
            content_switcher:add(cal_widget)
        else
            content_switcher:add(notif_widget)
            notifs.mark_read()
        end
        refresh_tabs()
    end

    -- Re-bind tab buttons (styled_button takes a static callback, so we
    -- replace the buttons)
    tab_cal:buttons(gears.table.join(awful.button({}, 1, function() switch_tab("calendar") end)))
    tab_notif:buttons(gears.table.join(awful.button({}, 1, function() switch_tab("notifications") end)))

    local tab_bar = wibox.widget {
        tab_cal,
        tab_notif,
        layout = wibox.layout.flex.horizontal,
        spacing = dpi(4),
    }

    local inner = wibox.widget {
        tab_bar,
        {
            widget = wibox.widget.separator,
            orientation = "horizontal",
            forced_height = dpi(1),
            color = beautiful.popup_border or "#665C54",
        },
        content_switcher,
        layout = wibox.layout.fixed.vertical,
        spacing = dpi(8),
    }

    local box = wibox.container.background(inner, beautiful.popup_bg or "#30343AEE", function(cr, w, h)
        gears.shape.rounded_rect(cr, w, h, beautiful.popup_radius or dpi(10))
    end)
    box.fg = beautiful.popup_fg or beautiful.fg_normal
    local padded = wibox.container.margin(box, beautiful.popup_padding or dpi(12),
        beautiful.popup_padding or dpi(12), beautiful.popup_padding or dpi(12),
        beautiful.popup_padding or dpi(12))

    -- Hard width constraint so content never exceeds POPUP_WIDTH.
    local constrained = wibox.container.constraint(padded, "exact", POPUP_WIDTH, nil)

    local pop = awful.popup {
        widget = constrained,
        border_width = beautiful.popup_border_width or dpi(1),
        border_color = beautiful.popup_border or "#665C54",
        visible = false,
        ontop = true,
        placement = function() end,
    }

    function pop:set_tab(tab)
        switch_tab(tab)
    end

    -- Initialize on calendar tab
    switch_tab("calendar")

    return pop
end

return setmetatable(calendar_notifications, { __call = function(_, ...) return calendar_notifications.new(...) end })
