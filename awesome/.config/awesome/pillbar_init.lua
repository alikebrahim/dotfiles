-------------------------------------------------------------------------------
-- pillbar_init — top-level entry point for the pill bar.
--
-- Wires the theme aliases, loads services, and builds the bar.
-- Deployment: add `require("pillbar_init")` to rc.lua AFTER beautiful.init.
-- See deployment.md for the exact integration.
-------------------------------------------------------------------------------
local beautiful = require("beautiful")
local theme_bar = require("theme_bar")

-- Apply bar-specific theme aliases (sourced from the existing palette).
theme_bar.apply()

-- Display-only services are lifecycle-managed by ui.bar and poll only while
-- the bar is visible. Notifications stay active so history is always captured.
require("services")
require("services.notifications")

-- Build the bar on every screen.
local bar = require("ui.bar")
bar.init()

return bar
