local M = {}

-- Helper function to get the basename from a path
local function basename(s)
    return string.gsub(s, "(.*[/\\])(.*)", "%2")
end

-- Status bar colors
local COLORS = {
    WORKSPACE = "#f7768e",
    KEY_TABLE = "#7dcfff",
    LEADER = "#bb9af7",
    COMMAND = "#e0af68",
}

function M.setup(wezterm)
    wezterm.on("update-status", function(window, pane)
        -- Workspace name or current mode
        local stat = window:active_workspace()
        local stat_color = COLORS.WORKSPACE
        
        if window:active_key_table() then
            stat = window:active_key_table()
            stat_color = COLORS.KEY_TABLE
        end
        
        if window:leader_is_active() then
            stat = "LDR"
            stat_color = COLORS.LEADER
        end

        -- Current working directory
        local cwd = pane:get_current_working_dir()
        if cwd then
            if type(cwd) == "userdata" then
                cwd = basename(cwd.file_path)
            else
                -- 20230712-072601-f4abf8fd or earlier version
                cwd = basename(cwd)
            end
        else
            cwd = ""
        end

        -- Current command
        local cmd = pane:get_foreground_process_name()
        -- CWD and CMD could be nil (e.g. viewing log using Ctrl-Alt-l)
        cmd = cmd and basename(cmd) or ""

        -- Time and date
        local time = "@" .. wezterm.strftime("%H:%M:%S")
        local day = wezterm.strftime("%a")
        local month = wezterm.strftime("%b %-d")
        local date = day .. ", " .. month

        -- Left status (left of the tab line)
        window:set_left_status(wezterm.format({
            { Foreground = { Color = stat_color } },
            { Text = "  " },
            { Text = wezterm.nerdfonts.oct_table .. "  " .. stat },
            { Text = " |" },
        }))

        -- Right status
        window:set_right_status(wezterm.format({
            -- Wezterm has a built-in nerd fonts
            -- https://wezfurlong.org/wezterm/config/lua/wezterm/nerdfonts.html
            { Text = wezterm.nerdfonts.md_folder .. "  " .. cwd },
            { Text = " | " },
            { Foreground = { Color = COLORS.COMMAND } },
            { Text = wezterm.nerdfonts.fa_code .. "  " .. cmd },
            "ResetAttributes",
            { Text = " | " },
            {
                Text = wezterm.nerdfonts.fa_clock_o .. " " .. date .. " " .. time,
            },
            { Text = "  " },
        }))
    end)
end

return M