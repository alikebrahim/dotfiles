-------------------------------------------------------------------------------
-- ui.bar.workspaces — taglist in a pill, preserving existing behaviour.
--
-- Uses awful.widget.taglist with a widget_template so tag states
-- (selected/occupied/empty/urgent) are styled explicitly. The existing
-- mouse bindings are kept (awful.button lists below).
-------------------------------------------------------------------------------
local awful = require("awful")
local wibox = require("wibox")
local gears = require("gears")
local beautiful = require("beautiful")
local dpi = require("beautiful.xresources").apply_dpi
local pill = require("ui.bar.pill")
local keys = require("keys")

local workspaces = {}

-- Standard taglist buttons (matches the user's existing intent: LMB switch,
-- Mod+LMB toggle, scroll to cycle).
local function taglist_buttons()
    return gears.table.join(
        awful.button({}, 1, function(t) keys.view_tag_index_all_screens(t.index) end),
        awful.button({ beautiful.modkey or "Mod4" }, 1, function(t)
            if client.focus then client.focus:move_to_tag(t) end
        end),
        awful.button({}, 3, function(t) keys.toggle_tag_index_all_screens(t.index) end),
        awful.button({ beautiful.modkey or "Mod4" }, 3, function(t)
            if client.focus then client.focus:toggle_tag(t) end
        end),
        awful.button({}, 4, function() keys.view_workspace_relative_all_screens(-1) end),
        awful.button({}, 5, function() keys.view_workspace_relative_all_screens(1) end)
    )
end

function workspaces.new(s)
    local tl = awful.widget.taglist {
        screen = s,
        filter = awful.widget.taglist.filter.all,
        buttons = taglist_buttons(),
        layout = { spacing = dpi(10), layout = wibox.layout.fixed.horizontal },
        widget_template = {
            {
                { id = "text_role", widget = wibox.widget.textbox },
                widget = wibox.container.margin,
                margins = dpi(2),
            },
            id = "background_role",
            widget = wibox.container.background,
            -- Per-state styling at the tag level.
            create_callback = function(self, t, index, objects)
                self:update(t)
            end,
            update_callback = function(self, t, index, objects)
                self:update(t)
            end,
            -- Tag-level shape (slightly smaller than the outer pill).
            shape = function(cr, w, h)
                gears.shape.rounded_rect(cr, w, h, dpi(4))
            end,
            update = function(self, t)
                local b = beautiful
                local fg, bg
                if t.selected then
                    bg = b.bar_pill_bg_active or b.bar_pill_bg
                    fg = b.bar_pill_fg_accent or b.fg_focus
                elseif t.urgent then
                    bg = b.bar_urgent or b.bg_urgent
                    fg = b.fg_urgent or b.bg
                elseif #t:clients() > 0 then
                    bg = "#00000000"
                    fg = b.bar_pill_fg or b.fg_normal
                else
                    bg = "#00000000"
                    fg = b.bar_pill_fg_muted or b.fg_minimize
                end
                self.bg = bg
                self:get_children_by_id("text_role")[1].markup =
                    '<span foreground="' .. fg .. '">' .. (t.name or t.index) .. '</span>'
            end,
        },
    }

    local p = pill {
        child = tl,
        padding_x = dpi(8),
        padding_y = dpi(4),
        hover = true,
    }
    return p
end

return setmetatable(workspaces, { __call = function(_, ...) return workspaces.new(...) end })
