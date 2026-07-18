-------------------------------------------------------------------------------
-- ui.bar.init — orchestrates the transparent host bar with four pills.
--
-- Per the brief: the host wibox spans the screen for struts but is fully
-- transparent (#00000000). Only the four pills are visible. The centre pill
-- is physically centered using a place container.
--
-- Popups are shared across screens and only one is open at a time.
--
-- Bar visibility tracks screen.primary changes (primary_changed, list,
-- property::outputs) so the bar appears on the correct monitor at login even
-- when RandR settles asynchronously.
-------------------------------------------------------------------------------
local awful = require("awful")
local wibox = require("wibox")
local gears = require("gears")
local beautiful = require("beautiful")
local dpi = require("beautiful.xresources").apply_dpi

local workspaces = require("ui.bar.workspaces")
local datetime = require("ui.bar.datetime")
local connectivity = require("ui.bar.connectivity")
local resources = require("ui.bar.resources")

local popup_manager = require("ui.helpers.popup")
local cal_notif = require("ui.popups.calendar_notifications")
local system_monitor = require("ui.popups.system_monitor")
local status_services = require("services")

local bar = {}
local _bars = {}
local _bar_visible = false
local _last_primary = nil

local function apply_bar_visibility()
    if _last_primary and _last_primary ~= screen.primary then
        popup_manager:hide_all()
    end
    _last_primary = screen.primary

    local any_visible = false
    for s, wb in pairs(_bars) do
        wb.visible = _bar_visible and s == screen.primary
        any_visible = any_visible or wb.visible
        awful.layout.arrange(s)
    end
    status_services.set_active(any_visible)
    if not _bar_visible then
        popup_manager:hide_all()
    end
end

function bar.init()
    local cal_pop = cal_notif()
    local sm_pop = system_monitor()
    local active_bg = nil
    local screen_contexts = {}

    local function reset_active_bg()
        if active_bg then active_bg:set_state("normal") end
        active_bg = nil
    end

    local function resolve_anchor_geometry(anchor, source_screen)
        if type(anchor) == "table" and anchor.x and anchor.y
            and anchor.width and anchor.height then
            return anchor
        end
        local geometry = source_screen.workarea or source_screen.geometry
        return {
            x = geometry.x + geometry.width - dpi(200),
            y = source_screen.geometry.y,
            width = dpi(190),
            height = beautiful.bar_height or dpi(30),
        }
    end

    popup_manager:register("info", cal_pop, nil, reset_active_bg)
    popup_manager:register("resources", sm_pop, nil, reset_active_bg)

    awful.screen.connect_for_each_screen(function(s)
        -- Left: workspaces
        local ws_pill = workspaces(s)

        -- Centre: datetime
        local dt_pill, dt_bg = datetime(s)

        -- Right pills. Resources come first, connectivity is far-right.
        local conn_pill = connectivity(s)
        local res_pill, res_bg = resources(s)

        local right_group = wibox.layout.fixed.horizontal()
        right_group.spacing = beautiful.bar_group_spacing or dpi(8)
        right_group:add(res_pill)
        right_group:add(conn_pill)

        local left_group = ws_pill
        local centre_group = dt_pill

        local left_slot = wibox.container.margin(
            wibox.container.place(left_group, "left", "center"),
            dpi(10), 0, 0, 0
        )

        local centre_slot = wibox.container.place(centre_group, "center", "center")

        local right_slot = wibox.container.margin(
            wibox.container.place(right_group, "right", "center"),
            0, dpi(10), 0, 0
        )

        local bar_layout = wibox.layout.align.horizontal()
        bar_layout:set_first(left_slot)
        bar_layout:set_second(centre_slot)
        bar_layout:set_third(right_slot)
        bar_layout:set_expand("outside")

        local wb = awful.wibar {
            position = "top",
            screen = s,
            height = beautiful.bar_height or dpi(30),
            bg = "#00000000",
            fg = beautiful.fg_normal,
            opacity = 1,
            stretch = true,
            border_width = 0,
            visible = false,
        }
        wb:set_widget(bar_layout)
        _bars[s] = wb
        screen_contexts[s] = { datetime_bg = dt_bg, resources_bg = res_bg }

        -- Clean up on screen removal.
        s:connect_signal("removed", function()
            popup_manager:hide_all()
            screen_contexts[s] = nil
            _bars[s] = nil
        end)
    end)

    -- A single popup signal handler routes to the originating screen. Keeping
    -- this outside the per-screen callback avoids stale handlers after hotplug.
    awesome.connect_signal("pill::toggle_popup", function(name, anchor_widget, source_screen)
        local context = screen_contexts[source_screen]
        if not context then return end

        local popup_name
        local source_bg
        if name == "info" or name == "info_notifs" then
            popup_name = "info"
            source_bg = context.datetime_bg
            if name == "info_notifs" and cal_pop.set_tab then
                cal_pop:set_tab("notifications")
            end
        elseif name == "resources" then
            popup_name = "resources"
            source_bg = context.resources_bg
        end

        if not popup_name then return end
        if popup_manager:is_open(popup_name) then
            popup_manager:hide_all()
            return
        end

        local anchor_geometry = popup_name == "resources"
            and resolve_anchor_geometry(anchor_widget, source_screen) or nil
        popup_manager:toggle(popup_name, anchor_geometry, source_screen)
        if popup_manager:is_open(popup_name) then
            active_bg = source_bg
            source_bg:set_state("active")
        end
    end)

    -- Apply visibility now, then re-apply on screen geometry/primary changes.
    apply_bar_visibility()

    -- Track screen primary changes so the bar appears on the correct monitor
    -- even when RandR settles asynchronously after login.
    screen.connect_signal("primary_changed", apply_bar_visibility)
    screen.connect_signal("list", apply_bar_visibility)
    screen.connect_signal("property::outputs", apply_bar_visibility)

    -- Staggered delayed re-application to cover async RandR settling.
    gears.timer.delayed_call(apply_bar_visibility)
    local t2 = gears.timer { timeout = 0.5, single_shot = true, call_now = false,
        callback = apply_bar_visibility }
    t2:start()
    local t3 = gears.timer { timeout = 2.0, single_shot = true, call_now = false,
        callback = apply_bar_visibility }
    t3:start()

    -- Bar toggle (Alt+Space).
    if not bar._toggle_connected then
        bar._toggle_connected = true
        awesome.connect_signal("pillbar::toggle", function()
            _bar_visible = not _bar_visible
            apply_bar_visibility()
        end)
    end
end

return bar
