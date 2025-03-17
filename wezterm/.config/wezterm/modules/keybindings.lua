local wezterm = require("wezterm")
local act = wezterm.action

local M = {}

function M.apply(config)
	-- Leader key configuration
	config.leader = { key = "a", mods = "CTRL", timeout_milliseconds = 1000 }

	-- Key binding categories
	local keys = {}

	-- Leader key bindings
	table.insert(keys, { key = "a", mods = "LEADER|CTRL", action = act.SendKey({ key = "a", mods = "CTRL" }) })

	-- Terminal control bindings
	table.insert(keys, { key = "Enter", mods = "ALT", action = act.ToggleFullScreen })
	table.insert(keys, { key = "F12", mods = "NONE", action = act.ShowDebugOverlay })
	-- table.insert(keys, { key = "C", mods = "LEADER", action = act.ActivateCommandPalette })

	-- Copy mode
	table.insert(keys, { key = "[", mods = "LEADER", action = act.ActivateCopyMode })
	table.insert(keys, { key = "c", mods = "CTRL|SHIFT", action = act.CopyTo("Clipboard") })
	table.insert(keys, { key = "v", mods = "CTRL|SHIFT", action = act.PasteFrom("Clipboard") })

	-- Pane control
	table.insert(keys, { key = "-", mods = "LEADER", action = act.SplitVertical({ domain = "CurrentPaneDomain" }) })
	table.insert(
		keys,
		{ key = "|", mods = "LEADER|SHIFT", action = act.SplitHorizontal({ domain = "CurrentPaneDomain" }) }
	)
	table.insert(keys, { key = "h", mods = "LEADER", action = act.ActivatePaneDirection("Left") })
	table.insert(keys, { key = "j", mods = "LEADER", action = act.ActivatePaneDirection("Down") })
	table.insert(keys, { key = "k", mods = "LEADER", action = act.ActivatePaneDirection("Up") })
	table.insert(keys, { key = "l", mods = "LEADER", action = act.ActivatePaneDirection("Right") })
	table.insert(keys, { key = "x", mods = "LEADER", action = act.CloseCurrentPane({ confirm = true }) })
	table.insert(keys, { key = "z", mods = "LEADER", action = act.TogglePaneZoomState })
	table.insert(keys, { key = "r", mods = "LEADER", action = act.RotatePanes("Clockwise") })
	table.insert(
		keys,
		{ key = "s", mods = "LEADER", action = act.ActivateKeyTable({ name = "resize_pane", one_shot = false }) }
	)

	-- Tab control
	table.insert(keys, { key = "n", mods = "CTRL|SHIFT", action = act.SpawnTab("CurrentPaneDomain") })
	table.insert(keys, { key = "{", mods = "CTRL|SHIFT", action = act.ActivateTabRelative(-1) })
	table.insert(keys, { key = "}", mods = "CTRL|SHIFT", action = act.ActivateTabRelative(1) })
	table.insert(keys, { key = "t", mods = "CTRL|SHIFT", action = act.ShowTabNavigator })
	table.insert(
		keys,
		{ key = "m", mods = "CTRL|SHIFT", action = act.ActivateKeyTable({ name = "move_tab", one_shot = false }) }
	)

	-- Workspace control
	table.insert(keys, { key = "w", mods = "LEADER", action = act.ShowLauncherArgs({ flags = "FUZZY|WORKSPACES" }) })

	-- Tab navigation using numbers
	for i = 2, 9 do
		table.insert(keys, {
			key = tostring(i),
			mods = "LEADER",
			action = act.ActivateTab(i - 2),
		})
	end

	config.keys = keys

	-- Key Tables for special modes
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
			{ key = "h", action = act.MoveTabRelative(-1) }, -- Fix: was 0
			{ key = "j", action = act.MoveTabRelative(-1) }, -- Fix: was 0
			{ key = "k", action = act.MoveTabRelative(1) }, -- Fix: was 2
			{ key = "l", action = act.MoveTabRelative(1) }, -- Fix: was 2
			{ key = "Escape", action = "PopKeyTable" },
			{ key = "Enter", action = "PopKeyTable" },
		},
	}
end

return M
