local root = assert(os.getenv("QUICKSHELL_REPO_ROOT"), "QUICKSHELL_REPO_ROOT is required")
local module = dofile(root .. "/home/dot_config/awesome/lib/quickshell_control.lua")

local function joined(values)
    return table.concat(values or {}, "\0")
end

local function fixture(responses, mutations_enabled)
    local calls = {}
    local starts = {}
    local timers = {}
    local reports = {}
    local queue = {}
    for _, response in ipairs(responses or {}) do queue[#queue + 1] = response end

    local awful = { spawn = {} }
    function awful.spawn.easy_async(command, callback)
        calls[#calls + 1] = command
        local response = assert(table.remove(queue, 1), "missing fake async response")
        callback(response.stdout or "", response.stderr or "", response.reason or "exit", response.rc or 0)
    end
    setmetatable(awful.spawn, {
        __call = function(_, command, sn_rules)
            starts[#starts + 1] = { command = command, sn_rules = sn_rules }
            return 4242
        end,
    })

    local gears = {
        timer = {
            start_new = function(timeout, callback)
                timers[#timers + 1] = { timeout = timeout, callback = callback }
                return { stop = function() end }
            end,
        },
    }

    local controller = module.new {
        awful = awful,
        gears = gears,
        config_dir = "/home/test/.config/quickshell",
        state_path = "/run/user/1000/quickshell-awesome/state.json",
        mutations_enabled = mutations_enabled,
        retry_delay = 0.25,
        report = function(title, text)
            reports[#reports + 1] = { title = title, text = text }
        end,
    }

    return {
        controller = controller,
        calls = calls,
        starts = starts,
        timers = timers,
        reports = reports,
        remaining = queue,
    }
end

local selected_instance = [[
[{"config_path":"/home/test/.config/quickshell/shell.qml","pid":1234}]
]]

local direct = fixture({ { stdout = "open\n", rc = 0 } }, false)
direct.controller.actions.application_launcher()
assert(#direct.calls == 1, "successful action makes one IPC call")
assert(joined(direct.calls[1]):find("launcher\0toggleLauncher", 1, true),
    "launcher action uses the selected config IPC target")
assert(#direct.starts == 0 and #direct.reports == 0,
    "successful action neither starts nor reports")

local resident = fixture({
    { stderr = "IPC unavailable", rc = 1 },
    { stdout = selected_instance, rc = 0 },
}, false)
resident.controller.actions.window_switcher()
assert(#resident.calls == 2, "failed IPC inspects the selected configuration")
assert(joined(resident.calls[2]):find("--path\0/home/test/.config/quickshell\0list\0--json", 1, true),
    "recovery inspection is scoped to the selected config")
assert(#resident.starts == 0, "resident unhealthy instance is never duplicated")
assert(#resident.reports == 1
    and resident.reports[1].text:find("running but IPC is unhealthy", 1, true),
    "resident unhealthy instance reports a bounded error")

local absent = fixture({
    { stderr = "IPC unavailable", rc = 1 },
    { stdout = "[]\n", rc = 0 },
    { stdout = "audio\n", rc = 0 },
}, true)
absent.controller.actions.audio_controls()
assert(#absent.starts == 1 and #absent.timers == 1,
    "missing selected instance is started once with one readiness delay")
local start = joined(absent.starts[1].command)
assert(start:find("QUICKSHELL_ENABLE_MUTATIONS=1", 1, true),
    "accepted mutation state is passed canonically")
assert(start:find("RESOURCE_NAME=quickshell-shell", 1, true),
    "new starts use the canonical X11 resource name")
assert(start:find("/usr/sbin/quickshell\0--path\0/home/test/.config/quickshell", 1, true),
    "recovery starts exactly the selected configuration")
assert(absent.timers[1].callback() == false, "bounded readiness timer is single-shot")
assert(#absent.calls == 3 and #absent.starts == 1 and #absent.reports == 0,
    "recovery retries IPC exactly once without a legacy fallback")

local retry_failure = fixture({
    { stderr = "IPC unavailable", rc = 1 },
    { stdout = "[]", rc = 0 },
    { stderr = "still unavailable", rc = 1 },
}, false)
retry_failure.controller.actions.bluetooth_controls()
retry_failure.timers[1].callback()
assert(#retry_failure.starts == 1 and #retry_failure.calls == 3,
    "failed recovery never starts or retries more than once")
assert(#retry_failure.reports == 1
    and retry_failure.reports[1].text:find("recovery retry failed", 1, true),
    "failed retry reports through Awesome's local error route")

local list_failure = fixture({
    { stderr = "IPC unavailable", rc = 1 },
    { stderr = "list failed", rc = 2 },
}, false)
list_failure.controller.actions.network_controls()
assert(#list_failure.starts == 0, "failed exact-config inspection does not guess and start")
assert(#list_failure.reports == 1
    and list_failure.reports[1].text:find("could not inspect", 1, true),
    "failed inspection reports the recovery blocker")

local startup = fixture({ { stdout = "[]", rc = 0 } }, false)
startup.controller:ensure_started()
assert(#startup.starts == 1 and #startup.timers == 1,
    "startup ensures the exact selected configuration")
local disabled_start = joined(startup.starts[1].command)
assert(disabled_start:find("-u\0QUICKSHELL_ENABLE_MUTATIONS", 1, true),
    "disabled mutation state is explicit for a fresh process")
assert(not disabled_start:find("QUICKSHELL_ENABLE_MUTATIONS=1", 1, true),
    "disabled startup never enables native mutations")

local already_running = fixture({ { stdout = selected_instance, rc = 0 } }, false)
already_running.controller:ensure_started()
assert(#already_running.starts == 0 and #already_running.timers == 0,
    "ensure_started leaves a healthy selected instance untouched")

local restart = fixture({
    { stdout = selected_instance, rc = 0 },
    { stdout = "[]\n", rc = 0 },
}, true)
restart.controller:restart_selected()
assert(#restart.starts == 1, "restart sends TERM to the selected pid")
assert(joined(restart.starts[1].command):find("kill\0-TERM\0" .. "1234", 1, true),
    "restart targets the listed selected-config pid")
assert(#restart.timers == 1, "restart waits one readiness delay after TERM")
restart.timers[1].callback()
assert(#restart.starts == 2, "restart starts the selected config after the old pid is gone")
assert(joined(restart.starts[2].command):find("/usr/sbin/quickshell\0--path\0/home/test/.config/quickshell", 1, true),
    "restart starts exactly the selected configuration")

local first_login = fixture({ { stdout = "[]", rc = 0 } }, false)
first_login.controller:restart_selected()
assert(#first_login.starts == 1 and #first_login.timers == 1,
    "restart on an empty session starts the selected configuration once")

print("ok - Quickshell controller exact-config startup, IPC recovery, and bounded failure")
