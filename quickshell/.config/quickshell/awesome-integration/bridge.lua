local bridge = {}

local array_marker = {}
local runtime = {
  path = nil,
  timer = nil,
  heartbeat_timer = nil,
  generation = "",
  workspace = nil,
  connections = {},
  last_error = "",
}

local function json_escape(value)
  local escaped = tostring(value)
    :gsub("\\", "\\\\")
    :gsub('"', '\\"')
    :gsub("\b", "\\b")
    :gsub("\f", "\\f")
    :gsub("\n", "\\n")
    :gsub("\r", "\\r")
    :gsub("\t", "\\t")
  return '"' .. escaped .. '"'
end

local function is_array(value)
  if getmetatable(value) == array_marker then
    return true, #value
  end

  local count = 0
  local largest = 0
  for key in pairs(value) do
    if type(key) ~= "number" or key < 1 or key % 1 ~= 0 then
      return false, 0
    end
    count = count + 1
    if key > largest then largest = key end
  end

  return count > 0 and count == largest, largest
end

local function encode_value(value, seen)
  local kind = type(value)
  if kind == "nil" then return "null" end
  if kind == "boolean" then return value and "true" or "false" end
  if kind == "string" then return json_escape(value) end
  if kind == "number" then
    if value ~= value or value == math.huge or value == -math.huge then
      error("cannot encode a non-finite number")
    end
    return tostring(value)
  end
  if kind ~= "table" then error("cannot encode value of type " .. kind) end
  if seen[value] then error("cannot encode a cyclic table") end

  seen[value] = true
  local array, length = is_array(value)
  local parts = {}
  if array then
    for index = 1, length do
      parts[#parts + 1] = encode_value(value[index], seen)
    end
  else
    local keys = {}
    for key in pairs(value) do
      if type(key) ~= "string" then
        seen[value] = nil
        error("JSON object keys must be strings")
      end
      keys[#keys + 1] = key
    end
    table.sort(keys)
    for _, key in ipairs(keys) do
      parts[#parts + 1] = json_escape(key) .. ":" .. encode_value(value[key], seen)
    end
  end
  seen[value] = nil

  return array and ("[" .. table.concat(parts, ",") .. "]")
    or ("{" .. table.concat(parts, ",") .. "}")
end

function bridge.array(values)
  return setmetatable(values or {}, array_marker)
end

function bridge.encode(value)
  return encode_value(value, {})
end

local modifier_labels = {
  Mod4 = "Super",
  Mod1 = "Alt",
  Control = "Ctrl",
  Shift = "Shift",
}

local key_labels = {
  Return = "Enter",
  Escape = "Esc",
  space = "Space",
  grave = "Grave",
}

local function display_key(value)
  local key = tostring(value or "")
  local keycode = key:match("^#(%d+)$")
  if keycode then
    local number = tonumber(keycode)
    if number and number >= 10 and number <= 18 then
      return tostring(number - 9)
    end
  end
  if #key == 1 and key:match("%a") then return key:upper() end
  return key_labels[key] or key
end

function bridge.hotkey_snapshot(hotkeys)
  local entries = bridge.array()
  for _, data in ipairs(hotkeys or {}) do
    if #entries >= 128 then break end
    if type(data) == "table" then
      local description = tostring(data.description or "")
      local key = display_key(data.key)
      if description ~= "" and key ~= "" then
        local parts = {}
        for _, modifier in ipairs(data.mod or {}) do
          local label = modifier_labels[tostring(modifier)] or tostring(modifier)
          if label ~= "Lock" and label ~= "Mod2" and label ~= "" then
            parts[#parts + 1] = label
          end
        end
        parts[#parts + 1] = key
        entries[#entries + 1] = {
          combo = table.concat(parts, "+"),
          description = description,
          group = tostring(data.group or "misc"):lower(),
        }
      end
    end
  end
  return entries
end

function bridge.write_state(path, state)
  assert(type(path) == "string" and path ~= "", "state path is required")

  local temporary_path = path .. ".tmp"
  local file, open_error = io.open(temporary_path, "wb")
  if not file then return nil, open_error end

  local ok, payload = pcall(bridge.encode, state)
  if not ok then
    file:close()
    os.remove(temporary_path)
    return nil, payload
  end

  local write_ok, write_error = file:write(payload, "\n")
  local close_ok, close_error = file:close()
  if not write_ok or not close_ok then
    os.remove(temporary_path)
    return nil, write_error or close_error
  end

  local renamed, rename_error = os.rename(temporary_path, path)
  if not renamed then
    os.remove(temporary_path)
    return nil, rename_error
  end

  return true
end

local function output_id(target_screen)
  if not target_screen then return "" end

  local names = {}
  for name in pairs(target_screen.outputs or {}) do
    names[#names + 1] = tostring(name)
  end
  table.sort(names)
  if #names > 0 then return table.concat(names, "+") end
  return "screen-" .. tostring(target_screen.index or "unknown")
end

local function sorted_screens()
  local screens = {}
  for target_screen in screen do screens[#screens + 1] = target_screen end
  table.sort(screens, function(left, right)
    local left_geometry = left.geometry or {}
    local right_geometry = right.geometry or {}
    if (left_geometry.x or 0) ~= (right_geometry.x or 0) then
      return (left_geometry.x or 0) < (right_geometry.x or 0)
    end
    if (left_geometry.y or 0) ~= (right_geometry.y or 0) then
      return (left_geometry.y or 0) < (right_geometry.y or 0)
    end
    return (left.index or 0) < (right.index or 0)
  end)
  return screens
end

local function screen_side_map(screens)
  local sides = {}
  for index, target_screen in ipairs(screens) do
    local side = "C"
    if #screens > 1 then
      if index == 1 then side = "L"
      elseif index == #screens then side = "R" end
    end
    sides[target_screen] = side
  end
  return sides
end

local function is_shell_client(candidate)
  local class = tostring(candidate.class or ""):lower()
  local instance = tostring(candidate.instance or ""):lower()
  local name = tostring(candidate.name or ""):lower()
  return class == "quickshell-shell" or instance == "quickshell-shell"
    or name == "quickshell-shell"
end

local function is_published_client(candidate)
  local class = tostring(candidate.class or "")
  return candidate.valid and candidate.type ~= "desktop" and candidate.type ~= "dock"
    and class:lower() ~= "scratchpad" and not is_shell_client(candidate)
end

function bridge.snapshot(workspace_provider)
  local awful = require("awful")
  local key_ok, key_module = pcall(require, "awful.key")
  local ordered_screens = sorted_screens()
  local sides = screen_side_map(ordered_screens)
  local outputs = bridge.array()
  for _, target_screen in ipairs(ordered_screens) do
    local id = output_id(target_screen)
    outputs[#outputs + 1] = {
      id = id,
      name = id,
      x = tonumber(target_screen.geometry and target_screen.geometry.x) or 0,
      side = sides[target_screen] or "C",
    }
  end

  local primary_screen = screen.primary or awful.screen.focused()
  local focused_screen = awful.screen.focused() or primary_screen
  local tags
  local workspace_index = 0
  local workspace_synchronized = true
  local active_workspace = workspace_provider or runtime.workspace
  if active_workspace and type(active_workspace.snapshot_tags) == "function" then
    local ok, entries, index, synchronized = pcall(
      active_workspace.snapshot_tags,
      is_published_client
    )
    if ok then
      tags = bridge.array(entries)
      workspace_index = tonumber(index) or 0
      workspace_synchronized = not not synchronized
    end
  end
  if not tags then
    tags = bridge.array()
    for index, tag in ipairs((primary_screen and primary_screen.tags) or {}) do
      local occupied = false
      for _, candidate in ipairs(tag.clients and tag:clients() or {}) do
        if is_published_client(candidate) then
          occupied = true
          break
        end
      end
      tags[#tags + 1] = {
        name = tostring(tag.name or ""),
        selected = not not tag.selected,
        occupied = occupied,
        urgent = not not tag.urgent,
      }
      if tag.selected then workspace_index = index end
    end
  end

  local focused_client = client.focus
  local clients = bridge.array()
  for _, candidate in ipairs(client.get()) do
    local class = tostring(candidate.class or "")
    if is_published_client(candidate) then
      local first_tag = candidate.first_tag
      clients[#clients + 1] = {
        id = tonumber(candidate.window) or 0,
        title = tostring(candidate.name or ""),
        class = class,
        output = output_id(candidate.screen),
        side = sides[candidate.screen] or "C",
        tagIndex = first_tag and (tonumber(first_tag.index) or 0) or 0,
        minimized = not not candidate.minimized,
        maximized = not not candidate.maximized,
        fullscreen = not not candidate.fullscreen,
        urgent = not not candidate.urgent,
        focused = candidate == focused_client,
      }
    end
  end

  return {
    publishedAtMs = os.time() * 1000,
    producerGeneration = runtime.generation,
    primaryOutput = output_id(primary_screen),
    focusedOutput = output_id(focused_screen),
    outputs = outputs,
    tags = tags,
    workspaceIndex = workspace_index,
    workspaceSynchronized = workspace_synchronized,
    clients = clients,
    keybinds = bridge.hotkey_snapshot(key_ok and key_module.hotkeys or {}),
    focusedClient = {
      title = focused_client and tostring(focused_client.name or "") or "",
      class = focused_client and tostring(focused_client.class or "") or "",
      screen = focused_client and output_id(focused_client.screen) or "",
    },
  }
end

function bridge.publish(path)
  return bridge.write_state(path, bridge.snapshot())
end

local function publish_runtime_state()
  if not runtime.path then return nil, "bridge is not running" end
  local state = bridge.snapshot()
  local ok, err = bridge.write_state(runtime.path, state)
  runtime.last_error = ok and "" or tostring(err or "bridge publication failed")
  return ok, err
end

function bridge.refresh()
  return publish_runtime_state()
end

local function schedule_runtime_publish()
  if runtime.timer then runtime.timer:again() end
end

local function runtime_signal_groups()
  return {
    {
      source = client,
      names = {
        "focus", "unfocus", "manage", "unmanage", "tagged", "untagged",
        "property::name", "property::class", "property::instance", "property::screen",
        "property::type", "property::urgent", "property::minimized",
        "property::maximized", "property::fullscreen",
      },
    },
    {
      source = tag,
      names = { "property::selected", "property::urgent", "property::name" },
    },
    {
      source = screen,
      names = { "primary_changed", "list", "added", "removed", "property::outputs" },
    },
  }
end

function bridge.start(path, workspace_provider)
  assert(type(path) == "string" and path ~= "", "state path is required")
  if runtime.path == path and runtime.workspace == workspace_provider then
    return publish_runtime_state()
  end
  if runtime.path then bridge.stop() end

  local gears = require("gears")
  local parent_ok, parent_error = gears.filesystem.make_parent_directories(path)
  if not parent_ok then return nil, parent_error end

  runtime.path = path
  local awesome_pid = _G.awesome and tonumber(_G.awesome.pid) or 0
  runtime.generation = table.concat({
    tostring(os.time()),
    tostring(awesome_pid or 0),
    (tostring(runtime):gsub("^table: ", "")),
  }, "-")
  runtime.workspace = workspace_provider
  runtime.last_error = ""
  runtime.timer = gears.timer {
    timeout = 0.05,
    single_shot = true,
    callback = publish_runtime_state,
  }
  runtime.heartbeat_timer = gears.timer {
    timeout = 2,
    autostart = true,
    call_now = false,
    callback = publish_runtime_state,
  }

  for _, group in ipairs(runtime_signal_groups()) do
    for _, name in ipairs(group.names) do
      group.source.connect_signal(name, schedule_runtime_publish)
      runtime.connections[#runtime.connections + 1] = {
        source = group.source,
        name = name,
      }
    end
  end

  local ok, err = publish_runtime_state()
  if not ok then
    bridge.stop()
    return nil, err
  end
  return true
end

function bridge.stop()
  if runtime.timer then runtime.timer:stop() end
  if runtime.heartbeat_timer then runtime.heartbeat_timer:stop() end
  for _, connection in ipairs(runtime.connections) do
    connection.source.disconnect_signal(connection.name, schedule_runtime_publish)
  end

  local path = runtime.path
  runtime.path = nil
  runtime.workspace = nil
  runtime.timer = nil
  runtime.heartbeat_timer = nil
  runtime.generation = ""
  runtime.connections = {}
  runtime.last_error = ""
  if path then
    os.remove(path)
    os.remove(path .. ".tmp")
  end
  return true
end

function bridge.last_error()
  return runtime.last_error
end

return bridge
