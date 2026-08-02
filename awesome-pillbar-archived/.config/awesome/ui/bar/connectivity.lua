-------------------------------------------------------------------------------
-- ui.bar.connectivity — right pill: audio · Wi-Fi · Bluetooth.
--
-- Left-click  → rofi menu (audio / wifi / bluetooth)
-- Middle-click → toggle mute / wifi on-off / bt on-off
-- Scroll      → volume ±5% (audio only)
-- Right-click → pavucontrol / nm-connection-editor / Bluetooth rofi menu
-------------------------------------------------------------------------------
local awful = require("awful")
local wibox = require("wibox")
local gears = require("gears")
local beautiful = require("beautiful")
local dpi = require("beautiful.xresources").apply_dpi
local pill = require("ui.bar.pill")
local audio_svc = require("services.audio")
local net_svc = require("services.network")
local bt_svc = require("services.bluetooth")

local connectivity = {}

--- Shared helpers -----------------------------------------------------------

local ROFI_DIR = "/home/alikebrahim/.config/scripts"

local function escape_markup(text)
    return tostring(text or "")
        :gsub("&", "&amp;")
        :gsub("<", "&lt;")
        :gsub(">", "&gt;")
end

local function seg_markup(icon, text, fg)
    local open = fg and ('<span foreground="' .. fg .. '">') or ""
    local close = fg and '</span>' or ""
    return open .. icon .. " " .. escape_markup(text) .. close
end

local function truncate_utf8(text, max_chars)
    local length = utf8.len(text)
    if not length or length <= max_chars then return text end
    local next_byte = utf8.offset(text, max_chars + 1)
    return text:sub(1, next_byte - 1) .. "…"
end

local function attach_tooltip(widget, text)
    widget._pill_tooltip = awful.tooltip {
        objects = { widget },
        text = text,
    }
end

--- Audio segment ------------------------------------------------------------

local function audio_segment(s)
    local w = wibox.widget.textbox()
    w.font = beautiful.font
    w.markup = seg_markup("󰕾", "?%", nil)

    awesome.connect_signal("service::audio", function(st)
        if not st.available then
            w.markup = seg_markup("󰕾", "--", beautiful.bar_pill_fg_muted)
            return
        end
        local icon = st.muted and "󰸈" or "󰕾"
        local pct = math.floor((st.volume or 0) * 100) .. "%"
        local fg = st.muted and beautiful.bar_pill_fg_muted or nil
        w.markup = seg_markup(icon, pct, fg)
    end)

    local seg = wibox.container.margin(w, dpi(4), dpi(4), 0, 0)
    seg:buttons(gears.table.join(
        awful.button({}, 1, function()
            awful.spawn(ROFI_DIR .. "/rofi-audio-menu.sh", false)
        end),
        awful.button({}, 2, function() audio_svc.toggle_mute() end),
        awful.button({}, 4, function() audio_svc.change_volume(0.05) end),
        awful.button({}, 5, function() audio_svc.change_volume(-0.05) end),
        awful.button({}, 3, function() awful.spawn("pavucontrol", false) end)
    ))
    attach_tooltip(seg, "Audio: click for menu · middle to mute · scroll for volume · right for mixer")
    return seg
end

--- Wi-Fi segment ------------------------------------------------------------

local function wifi_segment(s)
    local w = wibox.widget.textbox()
    w.font = beautiful.font
    w.markup = seg_markup("󰖪", "off", beautiful.bar_pill_fg_muted)

    awesome.connect_signal("service::network", function(st)
        if not st.available or not st.enabled then
            w.markup = seg_markup("󰖪", "off", beautiful.bar_pill_fg_muted)
            return
        end
        if st.connected then
            local ssid = truncate_utf8(st.ssid or "", 12)
            w.markup = seg_markup("󰖩", ssid, nil)
        else
            w.markup = seg_markup("󰖪", "—", beautiful.bar_pill_fg_muted)
        end
    end)

    local seg = wibox.container.margin(w, dpi(4), dpi(4), 0, 0)
    seg:buttons(gears.table.join(
        awful.button({}, 1, function()
            awful.spawn(ROFI_DIR .. "/rofi-wifi-menu.sh", false)
        end),
        awful.button({}, 2, function()
            local state = net_svc.get_state()
            if state.available then
                net_svc.set_enabled(not state.enabled)
            else
                net_svc.refresh()
            end
        end),
        awful.button({}, 3, function() net_svc.open_settings() end)
    ))
    attach_tooltip(seg, "Wi-Fi: click for menu · middle to toggle · right for connections")
    return seg
end

--- Bluetooth segment --------------------------------------------------------

local function bluetooth_segment(s)
    local w = wibox.widget.textbox()
    w.font = beautiful.font
    w.markup = seg_markup("󰂯", "off", beautiful.bar_pill_fg_muted)

    awesome.connect_signal("service::bluetooth", function(st)
        if not st.available or not st.powered then
            w.markup = seg_markup("󰂯", "off", beautiful.bar_pill_fg_muted)
            return
        end
        local connected = 0
        for _, d in ipairs(st.devices) do
            if d.connected then connected = connected + 1 end
        end
        if connected > 0 then
            w.markup = seg_markup("󰂱", tostring(connected),
                beautiful.bar_pill_fg_accent or beautiful.fg_focus)
        else
            w.markup = seg_markup("󰂯", "on", nil)
        end
    end)

    local seg = wibox.container.margin(w, dpi(4), dpi(4), 0, 0)
    seg:buttons(gears.table.join(
        awful.button({}, 1, function()
            awful.spawn(ROFI_DIR .. "/rofi-bluetooth-menu.sh", false)
        end),
        awful.button({}, 2, function()
            local state = bt_svc.get_state()
            if state.available then
                bt_svc.set_power(not state.powered)
            else
                bt_svc.refresh()
            end
        end),
        awful.button({}, 3, function()
            awful.spawn(ROFI_DIR .. "/rofi-bluetooth-menu.sh", false)
        end)
    ))
    attach_tooltip(seg, "Bluetooth: click or right-click for menu · middle to toggle")
    return seg
end

--- Public API ---------------------------------------------------------------

function connectivity.new(s)
    local p, bg = pill {
        child = {
            audio_segment(s),
            wifi_segment(s),
            bluetooth_segment(s),
        },
        spacing = dpi(6),
        hover = true,
    }
    return p, bg
end

return setmetatable(connectivity, {
    __call = function(_, ...) return connectivity.new(...) end
})
