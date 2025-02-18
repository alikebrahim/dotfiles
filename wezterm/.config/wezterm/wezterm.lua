local wezterm = require("wezterm")
local config = {}
local act = wezterm.action
if wezterm.config_builder then
	config = wezterm.config_builder()
end

-- [[
-- General: Appearance and Behavior
-- ]]
-- Appearance: Font
config.font = wezterm.font("JetBrains Mono", { weight = "Regular", italic = false })
config.font_size = 12
-- Appearance: Window
config.window_decorations = "RESIZE"
config.window_background_opacity = 0.97
config.window_close_confirmation = "NeverPrompt"
config.window_padding = {
	left = 3,
	right = 10,
	top = 7,
	bottom = 7,
}
-- Appearance: ColorScheme
-- config.color_scheme = "Later This Evening"
-- config.color_scheme = "Kolorit"
config.color_scheme = "Laserwave (Gogh)"
-- config.color_scheme = "Tango Dark"
-- config.color_scheme = "Solarized Dark"
-- config.color_scheme = "Solarized Light"
-- config.color_scheme = "Pastel Dark"
-- Appearance: Panes
config.inactive_pane_hsb = {
	saturation = 0.25,
	brightness = 0.5,
}
-- Appearance: Tab Bar
config.use_fancy_tab_bar = false
config.status_update_interval = 1000
config.tab_bar_at_bottom = false
config.tab_max_width = 25
config.show_tab_index_in_tab_bar = false
-- Behavior
config.scrollback_lines = 100000
config.default_workspace = "home"
config.disable_default_key_bindings = true

-- [[
-- Keybinds
-- ]]
config.leader = { key = "a", mods = "CTRL", timeout_milliseconds = 1000 }
config.keys = {
	-- preserve ctrl+a with two strokes
	{ key = "a", mods = "LEADER|CTRL", action = act.SendKey({ key = "a", mods = "CTRL" }) },
	-- term CTRL
	{ key = "Enter", mods = "ALT", action = act.ToggleFullScreen }, -- toggle fullscreen
	{ key = "F12", mods = "NONE", action = act.ShowDebugOverlay }, -- show debugger (I have no idea why I would need that!)
	-- { key = "C", mods = "LEADER", action = act.ActivateCommandPalette }, -- show command palette
	-- { key = "a", mods = "LEADER", action = act.SendKey({ key = "a", mods = "CTRL" }) }, -- send c-a when pressing c-a twice
	---- copy mode
	{ key = "[", mods = "LEADER", action = act.ActivateCopyMode },
	{ key = "c", mods = "CTRL|SHIFT", action = act.CopyTo("Clipboard") },
	{ key = "v", mods = "CTRL|SHIFT", action = act.PasteFrom("Clipboard") },
	-- pane CTRL
	{ key = "-", mods = "LEADER", action = act.SplitVertical({ domain = "CurrentPaneDomain" }) },
	{ key = "|", mods = "LEADER|SHIFT", action = act.SplitHorizontal({ domain = "CurrentPaneDomain" }) },
	{ key = "h", mods = "LEADER", action = act.ActivatePaneDirection("Left") },
	{ key = "j", mods = "LEADER", action = act.ActivatePaneDirection("Down") },
	{ key = "k", mods = "LEADER", action = act.ActivatePaneDirection("Up") },
	{ key = "l", mods = "LEADER", action = act.ActivatePaneDirection("Right") },
	{ key = "x", mods = "LEADER", action = act.CloseCurrentPane({ confirm = true }) },
	{ key = "z", mods = "LEADER", action = act.TogglePaneZoomState },
	{ key = "r", mods = "LEADER", action = act.RotatePanes("Clockwise") },
	{ key = "s", mods = "LEADER", action = act.ActivateKeyTable({ name = "resize_pane", one_shot = false }) },
	-- tab CTRL
	{ key = "n", mods = "CTRL|SHIFT", action = act.SpawnTab("CurrentPaneDomain") },
	{ key = "{", mods = "CTRL|SHIFT", action = act.ActivateTabRelative(-1) },
	{ key = "}", mods = "CTRL|SHIFT", action = act.ActivateTabRelative(1) },
	{ key = "t", mods = "CTRL|SHIFT", action = act.ShowTabNavigator },
	{ key = "m", mods = "CTRL|SHIFT", action = act.ActivateKeyTable({ name = "move_tab", one_shot = false }) },
	-- Workspaces CTRL
	{ key = "w", mods = "LEADER", action = act.ShowLauncherArgs({ flags = "FUZZY|WORKSPACES" }) },
}
-- navigate tabe with tab index
for i = 2, 9 do
	table.insert(config.keys, {
		key = tostring(i),
		mods = "LEADER",
		action = act.ActivateTab(i - 2),
	})
end

-- KeyTables
config.key_tables = {
	resize_pane = {
		{ key = "h", action = act.AdjustPaneSize({ "Left", 2 }) },
		{ key = "j", action = act.AdjustPaneSize({ "Down", 2 }) },
		{ key = "k", action = act.AdjustPaneSize({ "Up", 2 }) },
		{ key = "l", action = act.AdjustPaneSize({ "Right", 2 }) },
		{ key = "Escape", action = "PopKeyTable" },
		{ key = "Enter", action = "PopKeyTable" },
	},
	move_tab = {
		{ key = "h", action = act.MoveTabRelative(0) },
		{ key = "j", action = act.MoveTabRelative(0) },
		{ key = "k", action = act.MoveTabRelative(2) },
		{ key = "l", action = act.MoveTabRelative(2) },
		{ key = "Escape", action = "PopKeyTable" },
		{ key = "Enter", action = "PopKeyTable" },
	},
}

-- TAB bar
-- [[
-- Status
-- ]]
wezterm.on("update-status", function(window, pane)
	-- Workspace name
	local stat = window:active_workspace()
	local stat_color = "#f7768e"
	if window:active_key_table() then
		stat = window:active_key_table()
		stat_color = "#7dcfff"
	end
	if window:leader_is_active() then
		stat = "LDR"
		stat_color = "#bb9af7"
	end

	local basename = function(s)
		return string.gsub(s, "(.*[/\\])(.*)", "%2")
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

	-- Time
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
		{ Foreground = { Color = "#e0af68" } },
		{ Text = wezterm.nerdfonts.fa_code .. "  " .. cmd },
		"ResetAttributes",
		{ Text = " | " },
		{
			Text = wezterm.nerdfonts.fa_clock_o .. " " .. date .. " " .. time,
		},
		{ Text = "  " },
	}))
end)

return config
