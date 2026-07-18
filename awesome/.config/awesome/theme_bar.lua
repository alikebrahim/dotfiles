-------------------------------------------------------------------------------
-- Bar-specific theme aliases.
--
-- This module does NOT introduce a new palette. It reads the already-initialised
-- `beautiful` values (sourced from theme/colors.lua) and adds bar/pill/popup
-- aliases. Translucency uses RGBA (#RRGGBBAA) where #E6 = 90% opacity.
--
-- Usage (after beautiful.init in rc.lua):
--   require("theme_bar").apply()
-------------------------------------------------------------------------------
local beautiful = require("beautiful")
local dpi = require("beautiful.xresources").apply_dpi

local theme_bar = {}

function theme_bar.apply()
    local b = beautiful

    --- Geometry (dpi-scaled)
    b.bar_height          = b.bar_height          or dpi(30)
    b.bar_pill_height     = b.bar_pill_height     or dpi(26)
    b.bar_outer_margin    = b.bar_outer_margin    or dpi(5)
    b.bar_group_spacing   = b.bar_group_spacing   or dpi(8)

    --- Pill colours — lightly translucent derivatives of the existing palette.
    -- Keep enough opacity for readability, but let the wallpaper breathe.
    b.bar_pill_bg         = b.bar_pill_bg         or "#30343AE6"
    -- Hover: slightly brighter and a touch more opaque.
    b.bar_pill_bg_hover   = b.bar_pill_bg_hover   or "#3A3F46F0"
    -- Active/open: grey highlight, still translucent.
    b.bar_pill_bg_active  = b.bar_pill_bg_active  or "#434950EE"
    b.bar_pill_fg         = b.bar_pill_fg         or b.fg_normal      -- #d3c6aa
    b.bar_pill_fg_muted   = b.bar_pill_fg_muted   or "#928d6f"        -- readable muted (fg_normal @ ~60% luminance)
    b.bar_pill_fg_accent  = b.bar_pill_fg_accent  or b.fg_focus       -- #7fbbb3
    b.bar_pill_border         = b.bar_pill_border         or b.border_normal
    b.bar_pill_border_active  = b.bar_pill_border_active  or b.border_focus
    b.bar_pill_border_width   = b.bar_pill_border_width   or 0
    b.bar_pill_radius         = b.bar_pill_radius         or dpi(8)
    b.bar_pill_padding_x      = b.bar_pill_padding_x      or dpi(10)
    b.bar_pill_padding_y      = b.bar_pill_padding_y      or dpi(4)
    b.bar_pill_spacing        = b.bar_pill_spacing        or dpi(12)

    --- Reused semantic colours (no new hues).
    b.bar_urgent          = b.bar_urgent          or b.bg_urgent       -- #e67e80
    b.bar_good            = b.bar_good            or "#a7c080"          -- colors.color2
    b.bar_warn            = b.bar_warn            or "#dbbc7f"          -- colors.color3

    --- Popup theme — neutral grey/taupe, separate from the green accent.
    b.popup_bg            = b.popup_bg            or "#30343AEE"
    b.popup_fg            = b.popup_fg            or b.fg_normal
    b.popup_fg_muted      = b.popup_fg_muted      or "#A8A08A"
    b.popup_title_fg      = b.popup_title_fg      or b.fg_normal
    b.popup_card_bg       = b.popup_card_bg       or "#363A40CC"
    b.popup_button_bg     = b.popup_button_bg     or "#3A3F46CC"
    b.popup_button_bg_hover = b.popup_button_bg_hover or "#434950EE"
    b.popup_button_fg     = b.popup_button_fg     or b.fg_normal
    b.popup_slider_bar    = b.popup_slider_bar    or "#4A5057"
    b.popup_slider_fill   = b.popup_slider_fill   or "#A8A08A"
    b.popup_slider_handle = b.popup_slider_handle or b.fg_normal
    b.popup_border        = b.popup_border        or "#665C54"
    b.popup_border_width  = b.popup_border_width  or dpi(1)
    b.popup_radius        = b.popup_radius        or dpi(10)
    b.popup_padding       = b.popup_padding       or dpi(12)
    b.popup_spacing       = b.popup_spacing       or dpi(8)
end

return theme_bar
