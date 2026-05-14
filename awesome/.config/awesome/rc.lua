pcall(require, "luarocks.loader")

local gears = require("gears")
local awful = require("awful")
require("awful.autofocus")
local beautiful = require("beautiful")

-- -----------------------------------------------------------------------------
-- Theme
-- -----------------------------------------------------------------------------
beautiful.init(require("theme"))

-- -----------------------------------------------------------------------------
-- Core settings
-- -----------------------------------------------------------------------------
terminal = "wezterm"
browser = "google-chrome-stable --new-window"
editor = os.getenv("EDITOR") or "nano"
modkey = "Mod4"

awful.layout.layouts = {
	awful.layout.suit.tile,
	awful.layout.suit.tile.left,
	awful.layout.suit.tile.bottom,
	awful.layout.suit.tile.top,
	awful.layout.suit.floating,
	awful.layout.suit.max,
}

-- -----------------------------------------------------------------------------
-- Helpers
-- -----------------------------------------------------------------------------
local function run_once_process(process, cmd)
	awful.spawn.with_shell("pgrep -u $USER -x " .. process .. " >/dev/null || (" .. cmd .. ")")
end

local function spawn_shell(cmd)
	awful.spawn.with_shell(cmd)
end

-- -----------------------------------------------------------------------------
-- Error handling
-- -----------------------------------------------------------------------------
local function report_awesome_error(title, text)
	local safe_title = tostring(title):gsub("'", "'\\''")
	local safe_text = tostring(text):gsub("'", "'\\''")
	awful.spawn.with_shell("notify-send -u critical '" .. safe_title .. "' '" .. safe_text .. "'")
end

if awesome.startup_errors then
	report_awesome_error("Awesome startup errors", awesome.startup_errors)
end

local in_error = false
awesome.connect_signal("debug::error", function(err)
	if in_error then
		return
	end
	in_error = true
	report_awesome_error("Awesome runtime error", tostring(err))
	in_error = false
end)

-- -----------------------------------------------------------------------------
-- Tags / Screen setup
-- -----------------------------------------------------------------------------
awful.screen.connect_for_each_screen(function(s)
	if s == screen.primary then
		s.padding = { top = 26 }
	else
		s.padding = { top = 0 }
	end

	awful.tag({ "1", "2", "3", "4", "5" }, s, awful.layout.layouts[1])
end)

-- -----------------------------------------------------------------------------
-- Autostart
-- -----------------------------------------------------------------------------
-- Normalize this Awesome session as X11 before launching Electron/Qt/Chromium apps.
os.execute("/home/alikebrahim/.config/scripts/x11-session-env.sh")

os.execute("/home/alikebrahim/.config/scripts/x11-monitor-setup.sh")

spawn_shell("feh --bg-center /home/alikebrahim/Pictures/background.png /home/alikebrahim/Pictures/background.png")
run_once_process("picom", "picom --config /home/alikebrahim/.config/picom/picom.conf")
run_once_process("dunst", "dunst")
spawn_shell("/home/alikebrahim/.config/polybar/launch.sh")
-- run_once_process("quickshell", "quickshell")
run_once_process("xss-lock", "xss-lock --transfer-sleep-lock -- i3lock -c 1e1e2e")

-- -----------------------------------------------------------------------------
-- Components (Modularized)
-- -----------------------------------------------------------------------------
local keys = require("keys")
local rules = require("rules")
local signals = require("signals")
local dynamism = require("dynamism")

-- Initialize components
root.keys(keys.globalkeys)
awful.rules.rules = rules.get(keys.clientkeys, keys.clientbuttons)
signals.setup()
dynamism.setup()
