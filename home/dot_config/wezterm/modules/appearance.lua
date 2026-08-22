local wezterm = require("wezterm")
local retro_themes = require("modules.retro_themes")

local M = {}

function M.apply(config)
	-- Cursor style
	config.default_cursor_style = "SteadyBar"
	-- Font configuration
	config.font = wezterm.font("JetBrains Mono", { weight = "Regular", italic = false })
	config.font_size = 13

	-- Window appearance
	config.window_decorations = "RESIZE"
	config.window_background_opacity = 0.87
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

	-- Base terminal color scheme. Retro themes below only style the tab bar/top status.
	-- config.color_scheme = "3024 (dark) (terminal.sexy)" -- **
	-- config.color_scheme = "Aardvark Blue"
	-- config.color_scheme = "Abernathy" -- ***
	config.color_scheme = "Aci (Gogh)" -- *** nice for readability
	-- config.color_scheme = "Aco (Gogh)" -- **
	-- config.color_scheme = "Andromeda" -- *
	-- config.color_scheme = "Apple System Colors" -- *
	-- config.color_scheme = "Argonaut" -- *
	-- config.color_scheme = "Atelierseaside (dark) (terminal.sexy)" -- **
	-- config.color_scheme = "ayu" -- *** nice for readability, light on the eyes
	-- config.color_scheme = "Blue Matrix"
	-- config.color_scheme = "Builtin Dark"
	-- config.color_scheme = "Count Von Count (terminal.sexy)"
	-- config.color_scheme = "deep" -- **
	-- config.color_scheme = "HaX0R_BLUE" -- **** soothing
	-- config.color_scheme = "Icy Dark (base16)"
	-- Retro tab bar theme, ported from ~/.tmux/themes.
	-- Available: amber-crt, green-phosphor, orange-gas-plasma,
	-- commodore-64, cga-cyan-magenta, mac-classic, blue-matrix.
	retro_themes.apply_tab_bar(config, os.getenv("WEZTERM_RETRO_THEME") or "cga-cyan-magenta")

	-- Pane appearance
	config.inactive_pane_hsb = {
		saturation = 0.25,
		brightness = 0.5,
	}

	-- Tab bar appearance
	config.use_fancy_tab_bar = false
	config.status_update_interval = 1000
	config.tab_bar_at_bottom = false
	config.tab_max_width = 50
	config.show_tab_index_in_tab_bar = false
	config.show_new_tab_button_in_tab_bar = false

	-- Behavior
	config.scrollback_lines = 100000
	config.default_workspace = "home"
	-- config.disable_default_key_bindings = true
end

return M
