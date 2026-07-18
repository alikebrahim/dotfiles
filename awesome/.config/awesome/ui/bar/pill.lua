-------------------------------------------------------------------------------
-- ui.bar.pill — the single reusable rounded pill primitive.
--
-- All four bar groups are built from this. State-driven styling keeps colours
-- in the theme, not in widget files.
--
-- API:
--   local pill_widget, bg_container = pill {
--       child       = <widget>,            -- single child OR a layout
--       bg          = beautiful.bar_pill_bg,
--       fg          = beautiful.bar_pill_fg,
--       radius      = beautiful.bar_pill_radius,
--       padding_x   = beautiful.bar_pill_padding_x,
--       padding_y   = beautiful.bar_pill_padding_y,
--       border      = beautiful.bar_pill_border,
--       border_width= beautiful.bar_pill_border_width,
--       hover       = true,                -- enable hover state
--       buttons     = { ... },             -- awful.button list
--       spacing     = beautiful.bar_pill_spacing,
--   }
--
--   bg_container:set_state("normal" | "hover" | "active" | "urgent")
-------------------------------------------------------------------------------
local wibox = require("wibox")
local gears = require("gears")
local beautiful = require("beautiful")
local dpi = require("beautiful.xresources").apply_dpi

local pill = {}

--- Resolve the colour set for a logical state from the theme.
local function state_colors(state)
    local b = beautiful
    if state == "hover" then
        return {
            bg = b.bar_pill_bg_hover or b.bar_pill_bg,
            border = b.bar_pill_border or b.bar_pill_border,
            fg = b.bar_pill_fg,
        }
    elseif state == "active" then
        return {
            bg = b.bar_pill_bg_active or b.bar_pill_bg,
            border = b.bar_pill_border_active or b.bar_pill_border,
            fg = b.bar_pill_fg_accent or b.bar_pill_fg,
        }
    elseif state == "urgent" then
        return {
            bg = b.bar_urgent or b.bg_urgent,
            border = b.bar_urgent or b.bg_urgent,
            fg = b.fg_urgent or b.bg,
        }
    end
    -- normal
    return {
        bg = b.bar_pill_bg,
        border = b.bar_pill_border,
        fg = b.bar_pill_fg,
    }
end

function pill.new(opts)
    opts = opts or {}
    local b = beautiful

    local child = opts.child
    local spacing = opts.spacing or b.bar_pill_spacing or dpi(8)
    local radius = opts.radius or b.bar_pill_radius or dpi(8)
    local pad_x = opts.padding_x or b.bar_pill_padding_x or dpi(10)
    local pad_y = opts.padding_y or b.bar_pill_padding_y or dpi(4)
    local height = opts.height or b.bar_pill_height

    -- If child is a list of widgets, wrap in a fixed horizontal layout.
    local content
    if type(child) == "table" and child.is_widget then
        content = child
    elseif type(child) == "table" and child[1] ~= nil then
        content = wibox.layout.fixed.horizontal()
        content.spacing = spacing
        for _, w in ipairs(child) do
            content:add(w)
        end
    elseif child then
        content = child
    else
        content = wibox.widget.textbox("")
    end

    -- Apply padding via margins.
    local padded = wibox.container.margin(content, pad_x, pad_x, pad_y, pad_y)

    -- The background container drives state.
    local bg_container = wibox.container.background(padded)
    local _state = "normal"

    function bg_container:set_state(state)
        _state = state
        local c = state_colors(state)
        self.bg = c.bg
        self.fg = c.fg
        self.border_width = (state == "active") and (opts.border_width or dpi(1)) or (opts.border_width or b.bar_pill_border_width or 0)
        self.border_color = c.border
        self.shape = function(cr, w, h)
            gears.shape.rounded_rect(cr, w, h, radius)
        end
        self:emit_signal("widget::redraw_needed")
    end

    -- Initial state.
    bg_container:set_state("normal")
    if height then
        bg_container.forced_height = height
    end

    -- Hover handling: only flip to hover if not active/urgent.
    if opts.hover ~= false then
        bg_container:connect_signal("mouse::enter", function()
            if _state == "normal" then bg_container:set_state("hover") end
        end)
        bg_container:connect_signal("mouse::leave", function()
            if _state == "hover" then bg_container:set_state("normal") end
        end)
    end

    -- Buttons.
    if opts.buttons and #opts.buttons > 0 then
        bg_container:buttons(opts.buttons)
    end

    return bg_container, bg_container
end

return setmetatable(pill, { __call = function(_, ...) return pill.new(...) end })
