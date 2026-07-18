-------------------------------------------------------------------------------
-- ui.helpers.popup — popup manager + anchor positioning.
--
-- Responsibilities:
--   * Only one major popup open at a time (exclusivity).
--   * Position a popup beneath an anchor geometry via awful.placement.next_to,
--     clamped to the screen workarea, flipping above on bottom overflow.
--   * Calendar popup uses deterministic top-center placement.
--   * Track active popup so its pill can be styled via on_open/on_close.
-------------------------------------------------------------------------------
local awful = require("awful")
local dpi = require("beautiful.xresources").apply_dpi

local popup_manager = {}
popup_manager._registered = {}   -- name -> popup wibox
popup_manager._active = nil      -- name of currently open popup
popup_manager._anchors = {}      -- name -> {on_open, on_close}

-------------------------------------------------------------------------------
-- Placement
-------------------------------------------------------------------------------
local function place_top_center(pop, s)
    local wa = s.workarea or s.geometry
    local margin_top = dpi(6)
    local geo = pop:geometry()
    local width = geo.width or pop.width or pop.forced_width or dpi(360)
    pop:geometry {
        x = wa.x + math.floor((wa.width - width) / 2),
        y = wa.y + margin_top,
    }
end

local function place_near_anchor(pop, s, anchor)
    local workarea = s.workarea or s.geometry
    local margin = dpi(4)
    local pop_geo = pop:geometry()
    local width = pop_geo.width or pop.width or pop.forced_width or dpi(360)
    local height = pop_geo.height or pop.height or pop.forced_height or dpi(320)
    local anchor_center = anchor.x + anchor.width / 2

    local x = math.floor(anchor_center - width / 2)
    x = math.max(workarea.x + margin,
        math.min(x, workarea.x + workarea.width - width - margin))

    local y = anchor.y + anchor.height + margin
    if y + height > workarea.y + workarea.height - margin then
        y = anchor.y - height - margin
    end
    y = math.max(workarea.y + margin,
        math.min(y, workarea.y + workarea.height - height - margin))

    pop:geometry { x = x, y = y }
end

-------------------------------------------------------------------------------
-- Public API
-------------------------------------------------------------------------------

function popup_manager:register(name, popup_wibox, on_open, on_close)
    self._registered[name] = popup_wibox
    self._anchors[name] = { on_open = on_open, on_close = on_close }
end

function popup_manager:toggle(name, anchor_geometry, s)
    s = s or mouse.screen
    if self._active == name then
        self:hide_all()
        return
    end
    self:hide_all()
    local pop = self._registered[name]
    if not pop then return end

    pop.screen = s
    pop.visible = true

    if name == "info" then
        place_top_center(pop, s)
    elseif anchor_geometry then
        local placed = awful.placement.next_to(pop, {
            geometry = anchor_geometry,
            preferred_positions = "bottom",
            preferred_anchors = "middle",
            honor_workarea = true,
            margins = dpi(4),
        })
        local workarea = s.workarea or s.geometry
        if not placed or pop.y + pop.height > workarea.y + workarea.height then
            placed = awful.placement.next_to(pop, {
                geometry = anchor_geometry,
                preferred_positions = "top",
                preferred_anchors = "middle",
                honor_workarea = true,
                margins = dpi(4),
            })
        end
        if not placed then place_near_anchor(pop, s, anchor_geometry) end
    end

    self._active = name
    local cb = self._anchors[name]
    if cb and cb.on_open then cb.on_open() end
end

function popup_manager:hide_all()
    if not self._active then return end
    local pop = self._registered[self._active]
    if pop then pop.visible = false end
    local cb = self._anchors[self._active]
    if cb and cb.on_close then cb.on_close() end
    self._active = nil
end

function popup_manager:is_open(name)
    return self._active == name
end

function popup_manager:active()
    return self._active
end

return popup_manager
