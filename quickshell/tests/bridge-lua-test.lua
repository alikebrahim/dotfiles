local root = assert(os.getenv("QUICKSHELL_REPO_ROOT"), "QUICKSHELL_REPO_ROOT is required")
local bridge = dofile(root .. "/quickshell/.config/quickshell/awesome-integration/bridge.lua")

local payload = {
  primaryOutput = "HDMI-0",
  focusedOutput = "eDP-1-1",
  outputs = {
    { id = "HDMI-0", name = "HDMI-0" },
  },
  tags = {
    { name = "1", selected = true, occupied = false, urgent = false },
  },
  focusedClient = {
    title = "A \"quoted\" title",
    class = "example",
    screen = "HDMI-0",
  },
}

local encoded = bridge.encode(payload)
assert(encoded:match('"primaryOutput":"HDMI%-0"'), "primary output is encoded")
assert(encoded:match('"title":"A \\"quoted\\" title"'), "JSON strings are escaped")
assert(encoded:match('"selected":true'), "booleans are encoded")

local hotkey_entries = bridge.hotkey_snapshot({
  { mod = { "Mod4", "Control", "Shift" }, key = "t", description = "toggle titlebar", group = "client" },
  { mod = { "Mod4" }, key = "#10", description = "view workspace 1", group = "workspace" },
  { mod = {}, key = "Print", description = "interactive screenshot", group = "screenshots" },
  { mod = { "Mod4" }, key = "x", group = "ignored" },
})
assert(#hotkey_entries == 3, "only described hotkeys are published")
assert(hotkey_entries[1].combo == "Super+Ctrl+Shift+T", "modifiers and letters use display labels")
assert(hotkey_entries[2].combo == "Super+1", "workspace keycodes use number labels")
assert(hotkey_entries[3].combo == "Print", "unmodified keys remain readable")

local path = os.tmpname()
os.remove(path)
assert(bridge.write_state(path, payload))
local file = assert(io.open(path, "rb"))
local written = file:read("*a")
file:close()
assert(written == encoded .. "\n", "atomic writer emits one complete JSON document")
local partial = io.open(path .. ".tmp", "rb")
assert(partial == nil, "atomic writer leaves no partial file")
os.remove(path)

local function signal_source()
  local source = { handlers = {}, disconnects = 0 }

  function source.connect_signal(name, callback)
    source.handlers[name] = source.handlers[name] or {}
    table.insert(source.handlers[name], callback)
  end

  function source.disconnect_signal(name, callback)
    local callbacks = source.handlers[name] or {}
    for index = #callbacks, 1, -1 do
      if callbacks[index] == callback then
        table.remove(callbacks, index)
        source.disconnects = source.disconnects + 1
      end
    end
  end

  function source.emit(name, ...)
    for _, callback in ipairs(source.handlers[name] or {}) do callback(...) end
  end

  return source
end

local runtime_tag = {
  name = "1",
  selected = true,
  urgent = false,
}
function runtime_tag:clients() return {} end

local runtime_screen = {
  index = 1,
  outputs = { screen = true },
  tags = { runtime_tag },
}
local fake_screen = signal_source()
fake_screen.primary = runtime_screen
setmetatable(fake_screen, {
  __call = function(_, _, previous)
    if previous == nil then return runtime_screen end
    return nil
  end,
})

local fake_client = signal_source()
function fake_client.get() return {} end
fake_client.focus = {
  name = "Runtime title",
  class = "runtime",
  screen = runtime_screen,
}
local fake_tag = signal_source()
local workspace_provider = {
  snapshot_tags = function()
    return {
      { name = "1", selected = true, occupied = true, urgent = runtime_tag.urgent },
    }, 1, true
  end,
}
local fake_timers = {}
local timer_factory = setmetatable({}, {
  __call = function(_, options)
    local timer = {
      callback = options.callback,
      timeout = options.timeout,
      started = options.autostart == true,
    }
    function timer:again() self.started = true end
    function timer:stop() self.started = false end
    fake_timers[#fake_timers + 1] = timer
    return timer
  end,
})

local old_screen, old_client, old_tag = _G.screen, _G.client, _G.tag
local old_gears, old_awful = package.loaded.gears, package.loaded.awful
local old_awful_key = package.loaded["awful.key"]
_G.screen, _G.client, _G.tag = fake_screen, fake_client, fake_tag
package.loaded.gears = {
  filesystem = { make_parent_directories = function() return true end },
  timer = timer_factory,
}
package.loaded.awful = { screen = { focused = function() return runtime_screen end } }
package.loaded["awful.key"] = {
  hotkeys = {
    { mod = { "Mod4" }, key = "s", description = "show keybinds", group = "awesome" },
  },
}

local runtime_path = os.tmpname()
os.remove(runtime_path)
assert(bridge.start(runtime_path, workspace_provider),
  "bridge lifecycle starts with the workspace coordinator and publishes initial state")
local debounce_timer = assert(fake_timers[1], "debounce timer is created")
local heartbeat_timer = assert(fake_timers[2], "heartbeat timer is created")
assert(heartbeat_timer.timeout == 2 and heartbeat_timer.started,
  "heartbeat publication starts on a two-second cadence")
local runtime_file = assert(io.open(runtime_path, "rb"))
local initial_state = runtime_file:read("*a")
runtime_file:close()
assert(initial_state:match('"title":"Runtime title"'), "initial runtime snapshot is published")
assert(initial_state:match('"combo":"Super%+S"'), "initial runtime snapshot publishes keybinds")
assert(initial_state:match('"workspaceIndex":1'), "workspace authority index is published")
assert(initial_state:match('"workspaceSynchronized":true'), "workspace synchronization health is published")
assert(initial_state:match('"occupied":true'), "coordinator-aggregated tag state is published")
assert(initial_state:match('"publishedAtMs":%d+'), "producer heartbeat timestamp is published")
assert(initial_state:match('"producerGeneration":"[^"]+"'), "producer generation is published")

table.insert(package.loaded["awful.key"].hotkeys,
  { mod = { "Mod4" }, key = "#10", description = "view workspace 1", group = "workspace" })
assert(bridge.refresh(), "explicit refresh republishes post-registration keybinds")
local refreshed_file = assert(io.open(runtime_path, "rb"))
local refreshed_state = refreshed_file:read("*a")
refreshed_file:close()
assert(refreshed_state:match('"combo":"Super%+1"'), "refresh includes newly registered keybinds")

runtime_tag.urgent = true
fake_tag.emit("property::urgent", runtime_tag)
assert(debounce_timer.started, "Awesome state changes debounce a bridge publication")
debounce_timer.callback()
local updated_file = assert(io.open(runtime_path, "rb"))
local updated_state = updated_file:read("*a")
updated_file:close()
assert(updated_state:match('"urgent":true'), "debounced publication refreshes bridge state")

runtime_tag.urgent = false
heartbeat_timer.callback()
local heartbeat_file = assert(io.open(runtime_path, "rb"))
local heartbeat_state = heartbeat_file:read("*a")
heartbeat_file:close()
assert(heartbeat_state:match('"urgent":false'),
  "heartbeat republishes current state without waiting for an Awesome signal")

assert(bridge.stop(), "bridge lifecycle stops cleanly")
assert(not heartbeat_timer.started, "stopping the bridge stops heartbeat publication")
assert(io.open(runtime_path, "rb") == nil, "stopping removes stale runtime state")
assert(fake_client.disconnects > 0 and fake_tag.disconnects > 0 and fake_screen.disconnects > 0,
  "stopping disconnects every Awesome signal")

_G.screen, _G.client, _G.tag = old_screen, old_client, old_tag
package.loaded.gears, package.loaded.awful = old_gears, old_awful
package.loaded["awful.key"] = old_awful_key

print("ok - bridge Lua JSON, hotkeys, atomic writer, and lifecycle")
