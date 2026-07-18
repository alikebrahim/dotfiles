local awful = require("awful")
local bling = require("vendor.bling")

local dynamism = {}

function dynamism.setup()
    -- Scratchpad: Mod + ` toggles a persistent dropdown editor.
    dynamism.term_scratch = bling.module.scratchpad {
        command = [[sh -c 'dir="${XDG_RUNTIME_DIR:-$HOME/.cache/awesome}"; install -d -m 700 "$dir"; file="$(mktemp "$dir/scratch-XXXXXX")" || exit; exec wezterm start --class scratchpad -- nvim +startinsert "$file"']],
        rule = { class = "scratchpad" },
        sticky = true,
        autoclose = true,
        floating = true,
        geometry = { x = 360, y = 90, height = 600, width = 1200 },
        reapply = true,
        dont_focus_before_spawn = true,
    }
end

return dynamism
