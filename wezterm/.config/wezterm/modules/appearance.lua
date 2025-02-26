local wezterm = require("wezterm")

local M = {}

function M.apply(config)
	-- Font configuration
	config.font = wezterm.font("JetBrains Mono", { weight = "Regular", italic = false })
	config.font_size = 12

	-- Window appearance
	config.window_decorations = "RESIZE"
	config.window_background_opacity = 0.97
	config.window_close_confirmation = "NeverPrompt"
	config.window_padding = {
		left = 3,
		right = 10,
		top = 7,
		bottom = 17,
	}

	-- Disable notifications/bells
	config.audible_bell = "Disabled"
	config.visual_bell = {
		fade_in_duration_ms = 0,
		fade_out_duration_ms = 0,
		target = "CursorColor",
	}
	config.notification_handling = "NeverShow"

	-- Color scheme
	config.color_scheme = "Laserwave (Gogh)"
	-- Uncomment to use alternative themes:
	-- config.color_scheme = "Later This Evening"
	-- config.color_scheme = "Kolorit"
	-- config.color_scheme = "Tango Dark"
	-- config.color_scheme = "Solarized Dark"
	-- config.color_scheme = "Solarized Light"
	-- config.color_scheme = "Pastel Dark"

	-- Pane appearance
	config.inactive_pane_hsb = {
		saturation = 0.25,
		brightness = 0.5,
	}

	-- Tab bar appearance
	config.use_fancy_tab_bar = false
	config.status_update_interval = 1000
	config.tab_bar_at_bottom = false
	config.tab_max_width = 25
	config.show_tab_index_in_tab_bar = false

	-- Behavior
	config.scrollback_lines = 100000
	config.default_workspace = "home"
	config.disable_default_key_bindings = true
end

return M

