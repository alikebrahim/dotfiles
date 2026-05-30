local retro_themes = require("modules.retro_themes")

local M = {}

-- Helper function to compact a path for top-bar display
local function compact_path(path)
    if not path or path == "" then
        return "~"
    end

    local home = os.getenv("HOME")
    if home and string.sub(path, 1, #home) == home then
        path = "~" .. string.sub(path, #home + 1)
    end

    local max_len = 36
    if #path > max_len then
        path = "…" .. string.sub(path, #path - max_len + 2)
    end

    return path
end

local function clamp_title(s, max_width)
    if not s or s == "" then
        return "shell"
    end
    if #s <= max_width then
        return s
    end
    return string.sub(s, 1, math.max(1, max_width - 1)) .. "…"
end

local function palette()
    return retro_themes.get_active()
end

function M.setup(wezterm)
    wezterm.on("format-tab-title", function(tab, tabs, panes, config, hover, max_width)
        local colors = palette()
        local title = tab.tab_title

        if not title or title == "" then
            title = tab.active_pane and tab.active_pane.title or "shell"
        end

        local prefix = tostring(tab.tab_index + 1) .. ":"
        local padding = 2
        local overhead = #prefix + padding
        local desired_width = math.max(max_width, 14)
        desired_width = math.min(desired_width, config.tab_max_width or desired_width)
        title = clamp_title(title, desired_width - overhead)

        local bg = colors.inactive_bg
        local fg = colors.muted
        local intensity = "Normal"

        if tab.is_active then
            bg = colors.active
            fg = colors.background
            intensity = "Bold"
        elseif hover then
            bg = colors.selection_bg
            fg = colors.foreground
        end

        return {
            { Background = { Color = bg } },
            { Foreground = { Color = fg } },
            { Attribute = { Intensity = intensity } },
            { Text = " " .. prefix .. title .. " " },
        }
    end)

    wezterm.on("update-status", function(window, pane)
        local colors = palette()

        -- Workspace name or current mode
        local stat = window:active_workspace()
        local stat_color = colors.active
        
        if window:active_key_table() then
            stat = window:active_key_table()
            stat_color = colors.metric
        end
        
        if window:leader_is_active() then
            stat = "LDR"
            stat_color = colors.alert
        end

        -- Active pane current working directory
        local cwd = pane:get_current_working_dir()
        if cwd then
            if type(cwd) == "userdata" then
                cwd = compact_path(cwd.file_path)
            else
                -- 20230712-072601-f4abf8fd or earlier version
                cwd = compact_path(cwd)
            end
        else
            cwd = "~"
        end

        -- Time
        local time = wezterm.strftime("%H:%M")

        -- Left status: classic bracketed workspace/mode label.
        window:set_left_status(wezterm.format({
            { Foreground = { Color = colors.muted } },
            { Text = " [" },
            { Foreground = { Color = stat_color } },
            { Attribute = { Intensity = "Bold" } },
            { Text = stat },
            "ResetAttributes",
            { Foreground = { Color = colors.muted } },
            { Text = "] |" },
        }))

        -- Right status: classic text, active pane CWD, no modern icons.
        window:set_right_status(wezterm.format({
            { Foreground = { Color = colors.muted } },
            { Text = " [" },
            { Foreground = { Color = colors.metric } },
            { Text = cwd },
            { Foreground = { Color = colors.muted } },
            { Text = "] :: " },
            { Foreground = { Color = colors.foreground } },
            { Text = time },
            { Text = " " },
        }))
    end)
end

return M
