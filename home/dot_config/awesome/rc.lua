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
-- Keep internal Awesome error notifications without loading naughty.dbus,
-- which would compete with Quickshell for org.freedesktop.Notifications.
local naughty = require("naughty.core")

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

local function process_argv(pid)
    if type(pid) ~= "number" or pid <= 0 then return nil end
    local cmdline = io.open("/proc/" .. tostring(pid) .. "/cmdline", "rb")
    if not cmdline then return nil end
    local data = cmdline:read("*a")
    cmdline:close()
    if not data or data == "" then return nil end

    local argv = {}
    local cursor = 1
    while cursor <= #data do
        local terminator = data:find("\0", cursor, true)
        if not terminator then break end
        table.insert(argv, data:sub(cursor, terminator - 1))
        cursor = terminator + 1
    end
    return argv
end

local function argv_matches(actual, expected)
    if not actual or #actual ~= #expected then return false end
    for index, expected_arg in ipairs(expected) do
        local actual_arg = actual[index]
        if index == 1 then
            actual_arg = actual_arg:match("([^/]+)$") or actual_arg
            expected_arg = expected_arg:match("([^/]+)$") or expected_arg
        end
        if actual_arg ~= expected_arg then return false end
    end
    return true
end

local function ensure_lock_route(command)
    local user = os.getenv("USER")
    local any_probe = { "/usr/bin/pgrep", "-u", user, "-x", "xss-lock" }

    awful.spawn.easy_async(any_probe, function(stdout)
        local process_count = 0
        local intended_count = 0
        for raw_pid in stdout:gmatch("%d+") do
            local pid = tonumber(raw_pid)
            local actual = process_argv(pid)
            if actual then
                process_count = process_count + 1
                if argv_matches(actual, command) then
                    intended_count = intended_count + 1
                end
            end
        end

        if process_count == 1 and intended_count == 1 then return end
        if process_count > 0 then
            report_awesome_error(
                "Lock route mismatch",
                "The running xss-lock process set does not exactly match the configured Machine Synoptic route."
            )
            return
        end

        local pid = awful.spawn(command, false)
        if type(pid) ~= "number" or pid <= 0 then
            report_awesome_error("Lock route failed to start", tostring(pid))
            return
        end

        gears.timer.start_new(1, function()
            if not argv_matches(process_argv(pid), command) then
                report_awesome_error(
                    "Lock route failed to stay running",
                    "The exact Machine Synoptic xss-lock PID/argv was not present after startup."
                )
            end
            return false
        end)
    end)
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
	-- Tags are created per screen. Quickshell owns the primary-output bar strut.
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
local lock_selector = 'if [ -x "$HOME/.config/scripts/machine-synoptic-lock.sh" ]; then '
    .. 'exec "$HOME/.config/scripts/machine-synoptic-lock.sh"; '
    .. 'else exec i3lock --nofork -c 1e1e2e; fi'
ensure_lock_route(
    { "xss-lock", "--transfer-sleep-lock", "--", "/bin/sh", "-c", lock_selector }
)
run_once_process("^/usr/libexec/polkit-mate-authentication-agent-1$",
    { "/usr/libexec/polkit-mate-authentication-agent-1" })
run_once_process("^/opt/1Password/1password( --silent)?$",
    { "/opt/1Password/1password", "--silent" })

-- Quickshell production integration. The shell and bridge are always active;
-- native control mutations are the production default. A per-login safe-mode
-- marker disables them before the exact selected config starts.
-- Every shell action uses one exact-config controller. Recovery starts that
-- selected configuration once and retries IPC once; no legacy UI is launched.
local quickshell_config_dir = os.getenv("HOME") .. "/.config/quickshell"
local quickshell_bridge_path = quickshell_config_dir .. "/awesome-integration/bridge.lua"
local quickshell_runtime_dir = os.getenv("XDG_RUNTIME_DIR") or gears.filesystem.get_cache_dir()
local quickshell_state_path = quickshell_runtime_dir .. "/quickshell-awesome/state.json"
local quickshell_safe_mode_marker = quickshell_runtime_dir .. "/quickshell-awesome/safe-mode"
local quickshell_bridge
local quickshell_controller
local quickshell_integration_ready = false
local signals = require("signals")

local function quickshell_marker_exists(path)
    local marker = io.open(path, "r")
    if not marker then return false end
    marker:close()
    return true
end

local quickshell_mutations_enabled = not quickshell_marker_exists(quickshell_safe_mode_marker)

local control_loaded, control_module = pcall(require, "lib.quickshell_control")
if control_loaded then
    local configured, controller_or_error = pcall(control_module.new, {
        awful = awful,
        gears = gears,
        config_dir = quickshell_config_dir,
        state_path = quickshell_state_path,
        mutations_enabled = quickshell_mutations_enabled,
        report = report_awesome_error,
    })
    if configured then
        quickshell_controller = controller_or_error
    else
        report_awesome_error("Quickshell controller failed to configure", tostring(controller_or_error))
    end
else
    report_awesome_error("Quickshell controller is not deployed", tostring(control_module))
end

local quickshell_bridge_loader, quickshell_bridge_load_error = loadfile(quickshell_bridge_path)
if quickshell_bridge_loader then
    local loaded, module_or_error = pcall(quickshell_bridge_loader)
    if loaded then
        quickshell_bridge = module_or_error
        local started, start_error = quickshell_bridge.start(
            quickshell_state_path,
            signals.workspace
        )
        if started then
            quickshell_integration_ready = true
            if quickshell_controller then quickshell_controller:restart_selected() end
        else
            quickshell_bridge = nil
            report_awesome_error("Quickshell bridge failed to start", tostring(start_error))
        end
    else
        report_awesome_error("Quickshell bridge failed to load", tostring(module_or_error))
    end
else
    report_awesome_error("Quickshell integration is not deployed", tostring(quickshell_bridge_load_error))
end

-- -----------------------------------------------------------------------------
-- Components (Modularized)
-- -----------------------------------------------------------------------------
local keys = require("keys")
if quickshell_controller
    and not keys.configure_shell_actions(quickshell_controller.actions) then
    report_awesome_error("Quickshell key actions failed to configure", "Controller action set is incomplete")
end

local rules = require("rules")
local dynamism = require("dynamism")

-- Initialize components
root.keys(keys.globalkeys)
if quickshell_integration_ready and quickshell_bridge then
    local refreshed, refresh_error = quickshell_bridge.refresh()
    if not refreshed then
        report_awesome_error("Quickshell bridge keybind refresh failed", tostring(refresh_error))
    end
end
awful.rules.rules = rules.get(keys.clientkeys, keys.clientbuttons)
signals.setup()
dynamism.setup()
