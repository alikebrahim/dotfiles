local awful = require("awful")
local beautiful = require("beautiful")
local gears = require("gears")
local bling = require("vendor.bling")

local dynamism = {}

function dynamism.setup()
    -- 1. Helper: Scratchpad Utility
    -- Pressing Mod + ` (grave) will toggle a persistent dropdown terminal.
    dynamism.term_scratch = bling.module.scratchpad {
        command = "wezterm start --class scratchpad",
        rule = { class = "scratchpad" },
        sticky = true,
        autoclose = true,
        floating = true,
        -- Bling scratchpad expects absolute pixels, not percentages.
        -- Use a safe centered geometry for the current forced-1080p layout.
        geometry = { x = 360, y = 90, height = 600, width = 1200 },
        reapply = true,
        dont_focus_before_spawn =  true,
    }

    -- 2. Flash Focus (STAYING DISABLED TO PREVENT CORRUPTION)
    -- bling.module.flash_focus.enable()

    -- 3. Window Swallowing (DISABLED: RE-CAUSED SCREEN CORRUPTION ON NVIDIA)
    -- bling.module.window_swallowing.enable()
end

return dynamism
