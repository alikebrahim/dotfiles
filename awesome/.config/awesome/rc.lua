pcall(require, "luarocks.loader")

local gears = require("gears")
local awful = require("awful")
require("awful.autofocus")
local beautiful = require("beautiful")
local naughty = require("naughty")
local hotkeys_popup = require("awful.hotkeys_popup")
require("awful.hotkeys_popup.keys")

-- -----------------------------------------------------------------------------
-- Theme
-- -----------------------------------------------------------------------------
beautiful.init(require("theme"))

-- -----------------------------------------------------------------------------
-- Core settings
-- -----------------------------------------------------------------------------
terminal = "wezterm"
browser = "google-chrome-stable --ozone-platform=x11 --new-window"
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
if awesome.startup_errors then
  naughty.notify({
    preset = naughty.config.presets.critical,
    title = "Awesome startup errors",
    text = awesome.startup_errors,
  })
end

local in_error = false
awesome.connect_signal("debug::error", function(err)
  if in_error then return end
  in_error = true
  naughty.notify({
    preset = naughty.config.presets.critical,
    title = "Awesome runtime error",
    text = tostring(err),
  })
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
spawn_shell("systemctl --user import-environment DISPLAY XAUTHORITY XDG_CURRENT_DESKTOP XDG_SESSION_TYPE DESKTOP_SESSION DBUS_SESSION_BUS_ADDRESS")
spawn_shell("dbus-update-activation-environment --systemd DISPLAY XAUTHORITY XDG_CURRENT_DESKTOP XDG_SESSION_TYPE DESKTOP_SESSION")

os.execute("/home/alikebrahim/.config/scripts/x11-monitor-setup.sh")

spawn_shell("feh --bg-fill /home/alikebrahim/Pictures/background.png /home/alikebrahim/Pictures/background.png")
run_once_process("picom", "picom --config /home/alikebrahim/.config/picom/picom.conf")
run_once_process("dunst", "dunst")
spawn_shell("/home/alikebrahim/.config/polybar/launch.sh")
run_once_process("xss-lock", "xss-lock --transfer-sleep-lock -- i3lock -c 1e1e2e")

-- -----------------------------------------------------------------------------
-- Components (Modularized)
-- -----------------------------------------------------------------------------
local keys = require("keys")
local rules = require("rules")
local signals = require("signals")

-- Initialize components
root.keys(keys.globalkeys)
awful.rules.rules = rules.get(keys.clientkeys, keys.clientbuttons)
signals.setup()
