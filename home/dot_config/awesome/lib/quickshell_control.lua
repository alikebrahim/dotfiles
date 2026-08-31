local quickshell_control = {}

local action_specs = {
    bar_toggle = {
        label = "bar toggle",
        target = "bar",
        method = "toggleVisibility",
        accepted = { visible = true, hidden = true },
    },
    window_switcher = {
        label = "window switcher",
        target = "windowSwitcher",
        method = "toggleSwitcher",
        accepted = { open = true, closed = true },
    },
    application_launcher = {
        label = "application launcher",
        target = "launcher",
        method = "toggleLauncher",
        accepted = { open = true, closed = true },
    },
    power_menu = {
        label = "power menu",
        target = "sessionMenu",
        method = "toggleMenu",
        accepted = { open = true, closed = true },
    },
    keybind_help = {
        label = "keybind help",
        target = "keybindHelp",
        method = "toggleHelp",
        accepted = { open = true, closed = true },
    },
    display_manager = {
        label = "display manager",
        target = "displayManager",
        method = "toggleManager",
        accepted = { open = true, closed = true, busy = true },
    },
    audio_controls = {
        label = "audio controls",
        target = "controls",
        method = "openAudio",
        accepted = { audio = true },
    },
    network_controls = {
        label = "network controls",
        target = "controls",
        method = "openNetwork",
        accepted = { network = true },
    },
    bluetooth_controls = {
        label = "Bluetooth controls",
        target = "controls",
        method = "openBluetooth",
        accepted = { bluetooth = true },
    },
    volume_up = {
        label = "volume up",
        target = "osd",
        method = "volumeUp",
        accepted = { ok = true },
    },
    volume_down = {
        label = "volume down",
        target = "osd",
        method = "volumeDown",
        accepted = { ok = true },
    },
    volume_mute = {
        label = "volume mute",
        target = "osd",
        method = "volumeMute",
        accepted = { ok = true },
    },
    mic_mute = {
        label = "microphone mute",
        target = "osd",
        method = "micMute",
        accepted = { ok = true },
    },
    brightness_up = {
        label = "brightness up",
        target = "osd",
        method = "brightnessUp",
        accepted = { ok = true },
    },
    brightness_down = {
        label = "brightness down",
        target = "osd",
        method = "brightnessDown",
        accepted = { ok = true },
    },
}

local function append(target, value)
    target[#target + 1] = value
end

local function copy(values)
    local result = {}
    for _, value in ipairs(values or {}) do result[#result + 1] = value end
    return result
end

local function trim(value)
    return tostring(value or ""):match("^%s*(.-)%s*$")
end

local function detail(stderr, reason, exit_code)
    local message = trim(stderr)
    if message ~= "" then return message end
    message = trim(reason)
    if message ~= "" and message ~= "exit" then return message end
    return "exit " .. tostring(exit_code or "unknown")
end

function quickshell_control.new(options)
    assert(type(options) == "table", "options are required")
    assert(options.awful and options.awful.spawn, "awful.spawn is required")
    assert(options.gears and options.gears.timer, "gears.timer is required")
    assert(type(options.config_dir) == "string" and options.config_dir ~= "",
        "Quickshell config directory is required")

    local awful = options.awful
    local gears = options.gears
    local config_dir = options.config_dir
    local quickshell_path = options.quickshell_path or "/usr/sbin/quickshell"
    local retry_delay = tonumber(options.retry_delay) or 0.4
    local report = options.report or function() end
    local starting = false
    local pending_retry = nil

    local start_command = { "/usr/bin/env" }
    if options.mutations_enabled then
        append(start_command, "QUICKSHELL_ENABLE_MUTATIONS=1")
    else
        append(start_command, "-u")
        append(start_command, "QUICKSHELL_ENABLE_MUTATIONS")
    end
    if options.state_path and options.state_path ~= "" then
        append(start_command, "QUICKSHELL_AWESOME_STATE=" .. options.state_path)
    end
    append(start_command, "RESOURCE_NAME=quickshell-shell")
    append(start_command, quickshell_path)
    append(start_command, "--path")
    append(start_command, config_dir)

    local controller = { actions = {} }
    local run_ipc

    local function report_action(spec, message)
        report("Quickshell action unavailable", spec.label .. ": " .. message)
    end

    local function list_command()
        return {
            quickshell_path, "--path", config_dir, "list", "--json",
        }
    end

    local function selected_instance_pid(stdout, exit_code)
        if exit_code ~= 0 then return nil end
        local output = tostring(stdout or "")
        for object in output:gmatch("%b{}") do
            if object:find(config_dir, 1, true) then
                local pid = tonumber(object:match('"pid"%s*:%s*(%d+)'))
                if pid and pid > 1 then return pid end
            end
        end
        return false
    end

    local function selected_instance_present(stdout, exit_code)
        local pid = selected_instance_pid(stdout, exit_code)
        if pid == nil then return nil end
        return pid ~= false
    end

    local function start_selected_config(spec)
        if spec then pending_retry = spec end
        if starting then return end

        starting = true
        awful.spawn(copy(start_command), false)
        gears.timer.start_new(retry_delay, function()
            starting = false
            local retry_spec = pending_retry
            pending_retry = nil
            if retry_spec then run_ipc(retry_spec, false) end
            return false
        end)
    end

    local function recover_or_report(spec, ipc_error)
        awful.spawn.easy_async(list_command(), function(stdout, stderr, reason, exit_code)
            local present = selected_instance_present(stdout, exit_code)
            if present == nil then
                report_action(spec,
                    "could not inspect the selected configuration ("
                    .. detail(stderr, reason, exit_code) .. ")")
                return
            end
            if present then
                report_action(spec,
                    "the selected configuration is running but IPC is unhealthy ("
                    .. ipc_error .. ")")
                return
            end
            start_selected_config(spec)
        end)
    end

    run_ipc = function(spec, allow_recovery)
        local command = {
            quickshell_path, "--path", config_dir,
            "ipc", "call", spec.target, spec.method,
        }
        awful.spawn.easy_async(command, function(stdout, stderr, reason, exit_code)
            local response = trim(stdout)
            if exit_code == 0 and spec.accepted[response] then return end

            local failure = exit_code == 0
                and ("unexpected response " .. string.format("%q", response))
                or detail(stderr, reason, exit_code)
            if allow_recovery then
                recover_or_report(spec, failure)
            else
                report_action(spec, "recovery retry failed (" .. failure .. ")")
            end
        end)
    end

    function controller:ensure_started()
        awful.spawn.easy_async(list_command(), function(stdout, stderr, reason, exit_code)
            local present = selected_instance_present(stdout, exit_code)
            if present == nil then
                report("Quickshell recovery unavailable",
                    "Could not inspect the selected configuration ("
                    .. detail(stderr, reason, exit_code) .. ")")
                return
            end
            if not present then start_selected_config(nil) end
        end)
    end

    -- Awesome reload re-runs rc.lua while a daemonized Quickshell can keep
    -- serving the previous QML. Replace that selected process so a WM restart
    -- is a desktop reload, not only a window-manager reload.
    function controller:restart_selected()
        awful.spawn.easy_async(list_command(), function(stdout, stderr, reason, exit_code)
            local pid = selected_instance_pid(stdout, exit_code)
            if pid == nil then
                report("Quickshell restart unavailable",
                    "Could not inspect the selected configuration ("
                    .. detail(stderr, reason, exit_code) .. ")")
                return
            end
            if not pid then
                start_selected_config(nil)
                return
            end

            awful.spawn({ "kill", "-TERM", tostring(pid) }, false)
            gears.timer.start_new(retry_delay, function()
                awful.spawn.easy_async(list_command(), function(stdout2, stderr2, reason2, exit_code2)
                    local remaining = selected_instance_pid(stdout2, exit_code2)
                    if type(remaining) == "number" then
                        awful.spawn({ "kill", "-KILL", tostring(remaining) }, false)
                        gears.timer.start_new(0.2, function()
                            start_selected_config(nil)
                            return false
                        end)
                        return
                    end
                    start_selected_config(nil)
                end)
                return false
            end)
        end)
    end

    for name, spec in pairs(action_specs) do
        controller.actions[name] = function()
            run_ipc(spec, true)
        end
    end

    return controller
end

return quickshell_control
