local colors = require("theme.colors")
local theme = {}

theme.font = "JetBrainsMono Nerd Font 10"
theme.bg_normal = colors.bg
theme.bg_focus = colors.color0
theme.bg_urgent = colors.color1
theme.bg_minimize = colors.bg
theme.fg_normal = colors.fg
theme.fg_focus = colors.accent
theme.fg_urgent = colors.bg
theme.fg_minimize = colors.color8
theme.useless_gap = 2
theme.border_width = 2
theme.border_normal = colors.color8
theme.border_focus = colors.accent
theme.border_marked = colors.color2

theme.hotkeys_bg = colors.bg
theme.hotkeys_fg = colors.fg
theme.hotkeys_border_width = 2
theme.hotkeys_border_color = colors.accent
theme.hotkeys_group_margin = 20
theme.hotkeys_font = "JetBrainsMono Nerd Font Bold 12"
theme.hotkeys_description_font = "JetBrainsMono Nerd Font 10"

return theme
