local wezterm = require("wezterm")

-- Use the config builder API if available
local config = wezterm.config_builder and wezterm.config_builder() or {}

-- Import configuration modules
local appearance = require("modules.appearance")
local keybindings = require("modules.keybindings") 
local status = require("modules.status")

-- Apply configuration from modules
appearance.apply(config)
keybindings.apply(config)
status.setup(wezterm)

return config