pcall(require, "luarocks.loader")

-- Workaround: glib2 >= 1.86 moved UnixInputStream out of the Gio namespace into
-- GioUnix. This breaks awful.spawn.easy_async in awesome v4.3 (spawn.lua:485).
-- Restore the symbol before anything requires awful.spawn. Upstream master has
-- the same fix; this is a local patch until Fedora ships it.
local _lgi = require("lgi")
if not _lgi.Gio.UnixInputStream and _lgi.GioUnix and _lgi.GioUnix.InputStream then
    _lgi.Gio.UnixInputStream = _lgi.GioUnix.InputStream
end

local gears = require("gears")
local awful = require("awful")
require("awful.autofocus")
local beautiful = require("beautiful")
local naughty = require("naughty")

-- -----------------------------------------------------------------------------
-- Theme
-- -----------------------------------------------------------------------------
beautiful.init(require("theme"))

-- -----------------------------------------------------------------------------
-- Core settings
-- -----------------------------------------------------------------------------
terminal = "wezterm"
browser = "google-chrome --new-window"
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
local function run_once_process(pattern, cmd)
    awful.spawn.easy_async({ "/usr/bin/pgrep", "-u", os.getenv("USER"), "-f", pattern },
        function(_, _, _, exitcode)
            if exitcode ~= 0 then
                awful.spawn(cmd, false)
            end
        end)
end

local function spawn_shell(cmd)
	awful.spawn.with_shell(cmd)
end

-- -----------------------------------------------------------------------------
-- Error handling
-- -----------------------------------------------------------------------------
local function report_awesome_error(title, text)
    naughty.notify {
        urgency = "critical",
        title = tostring(title),
        text = tostring(text),
    }
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
	-- Tags are created per screen. Bar strut reservation is handled by the
	-- pill bar's awful.wibar (ui/bar/init.lua).
	awful.tag({ "1", "2", "3", "4", "5" }, s, awful.layout.layouts[1])
end)

-- -----------------------------------------------------------------------------
-- Autostart
-- -----------------------------------------------------------------------------
-- Normalize this Awesome session as X11 before launching Electron/Qt/Chromium apps.
os.execute("/home/alikebrahim/.config/scripts/x11-session-env.sh")

if awesome.startup then
    os.execute("/home/alikebrahim/.config/scripts/x11-monitor-setup.sh")
end

spawn_shell("feh --bg-center /home/alikebrahim/Pictures/background.png /home/alikebrahim/Pictures/background.png")
run_once_process("^picom( |$)", { "picom", "--config", "/home/alikebrahim/.config/picom/picom.conf" })
run_once_process("^xss-lock( |$)", { "xss-lock", "--transfer-sleep-lock", "--", "i3lock", "-c", "1e1e2e" })
run_once_process("^/usr/libexec/polkit-mate-authentication-agent-1$",
    { "/usr/libexec/polkit-mate-authentication-agent-1" })
run_once_process("^/opt/1Password/1password( --silent)?$",
    { "/opt/1Password/1password", "--silent" })

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

-- -----------------------------------------------------------------------------
-- Pill bar (native AwesomeWM bar; naughty handles notifications)
-- Wrapped in pcall so a pillbar failure doesn't kill the whole WM.
-- -----------------------------------------------------------------------------
local _pillbar_ok, _pillbar_err = pcall(require, "pillbar_init")
if not _pillbar_ok then
    report_awesome_error("Pill bar failed to load", tostring(_pillbar_err))
end
