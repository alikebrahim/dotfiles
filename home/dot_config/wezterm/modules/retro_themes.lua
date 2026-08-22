local M = {}

local themes = {
	["amber-crt"] = {
		background = "#0A1017",
		foreground = "#F0A020",
		active = "#F0A020",
		inactive_bg = "#1A1610",
		muted = "#5A4A3A",
		metric = "#FFD700",
		alert = "#FF7832",
		selection_bg = "#4A3220",
		selection_fg = "#FFD700",
		ansi = { "#0A1017", "#FF7832", "#F0A020", "#FFD700", "#A06020", "#D08030", "#FFC940", "#F0A020" },
		brights = { "#5A4A3A", "#FF9A5C", "#FFC940", "#FFE680", "#C08030", "#F0A020", "#FFD700", "#FFF0B0" },
	},
	["green-phosphor"] = {
		background = "#000000",
		foreground = "#13A10E",
		active = "#16BA10",
		inactive_bg = "#061406",
		muted = "#0B7A09",
		metric = "#42F07C",
		alert = "#F0D342",
		selection_bg = "#014401",
		selection_fg = "#42F07C",
		ansi = { "#000000", "#0B7A09", "#13A10E", "#45EB45", "#014401", "#16BA10", "#42F07C", "#13A10E" },
		brights = { "#014401", "#13A10E", "#16BA10", "#F0D342", "#0B7A09", "#42F07C", "#45EB45", "#B6FFB6" },
	},
	["orange-gas-plasma"] = {
		background = "#18110D",
		foreground = "#FFCB83",
		active = "#FC531D",
		inactive_bg = "#2A1810",
		muted = "#8F4E2D",
		metric = "#FFBE55",
		alert = "#FF7A2A",
		selection_bg = "#4A2414",
		selection_fg = "#FFCB83",
		ansi = { "#18110D", "#FC531D", "#FFBE55", "#FFCB83", "#8F4E2D", "#C06030", "#FF9F45", "#FFCB83" },
		brights = { "#4A2414", "#FF7A2A", "#FFCB83", "#FFE0A8", "#C06030", "#FC531D", "#FFBE55", "#FFF1D0" },
	},
	["commodore-64"] = {
		background = "#40318D",
		foreground = "#7869C4",
		active = "#A9FFFE",
		inactive_bg = "#352879",
		muted = "#7869C4",
		metric = "#FFFFB3",
		alert = "#FF7777",
		selection_bg = "#7869C4",
		selection_fg = "#40318D",
		ansi = { "#090300", "#883932", "#55A049", "#BFCE72", "#40318D", "#8B3F96", "#67B6BD", "#7869C4" },
		brights = { "#000000", "#FF7777", "#55FF55", "#FFFFB3", "#7869C4", "#AA5FB6", "#A9FFFE", "#FFFFFF" },
	},
	["cga-cyan-magenta"] = {
		background = "#000000",
		foreground = "#55FFFF",
		active = "#FF55FF",
		inactive_bg = "#0000AA",
		muted = "#5555FF",
		metric = "#FFFF55",
		alert = "#FF5555",
		selection_bg = "#0000AA",
		selection_fg = "#FFFF55",
		ansi = { "#000000", "#AA0000", "#00AA00", "#AA5500", "#0000AA", "#AA00AA", "#00AAAA", "#AAAAAA" },
		brights = { "#555555", "#FF5555", "#55FF55", "#FFFF55", "#5555FF", "#FF55FF", "#55FFFF", "#FFFFFF" },
	},
	["mac-classic"] = {
		background = "#101010",
		foreground = "#D8D8D8",
		active = "#FFFFFF",
		inactive_bg = "#2A2A2A",
		muted = "#808080",
		metric = "#BDBDBD",
		alert = "#F0A000",
		selection_bg = "#404040",
		selection_fg = "#FFFFFF",
		ansi = { "#000000", "#666666", "#777777", "#999999", "#555555", "#888888", "#AAAAAA", "#D8D8D8" },
		brights = { "#404040", "#888888", "#AAAAAA", "#BDBDBD", "#777777", "#CCCCCC", "#E8E8E8", "#FFFFFF" },
	},
	["blue-matrix"] = {
		background = "#03131F",
		foreground = "#7FDBFF",
		active = "#00D7FF",
		inactive_bg = "#082235",
		muted = "#2E6F8F",
		metric = "#39FFEA",
		alert = "#FF5F87",
		selection_bg = "#123A55",
		selection_fg = "#D7FFFF",
		ansi = { "#03131F", "#FF5F87", "#39FFEA", "#7FDBFF", "#0087AF", "#5F87FF", "#00D7FF", "#BFEFFF" },
		brights = { "#123A55", "#FF87AF", "#87FFF0", "#D7FFFF", "#00AFFF", "#87AFFF", "#5FFFFF", "#FFFFFF" },
	},
}

local active_name = "amber-crt"
local active = themes[active_name]

local function get_theme(name)
	return themes[name] or themes[active_name]
end

function M.apply_tab_bar(config, name)
	active_name = name or os.getenv("WEZTERM_RETRO_THEME") or active_name
	active = get_theme(active_name)

	-- Intentionally only style WezTerm's tab bar/top chrome.  Do not set
	-- terminal foreground/background, ANSI colors, cursor, selection, opacity,
	-- or layout here; those belong to the base color scheme/appearance config.
	config.colors = config.colors or {}
	config.colors.tab_bar = {
		background = active.background,
		active_tab = {
			bg_color = active.active,
			fg_color = active.background,
			intensity = "Bold",
		},
		inactive_tab = {
			bg_color = active.inactive_bg,
			fg_color = active.muted,
		},
		inactive_tab_hover = {
			bg_color = active.selection_bg,
			fg_color = active.foreground,
		},
		new_tab = {
			bg_color = active.background,
			fg_color = active.muted,
		},
		new_tab_hover = {
			bg_color = active.selection_bg,
			fg_color = active.foreground,
		},
	}
end

-- Backwards-compatible alias for older callers.
function M.apply(config, name)
	M.apply_tab_bar(config, name)
end

function M.get_active()
	return active
end

function M.get_active_name()
	return active_name
end

return M
