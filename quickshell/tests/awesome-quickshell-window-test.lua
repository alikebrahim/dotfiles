local root = assert(os.getenv("QUICKSHELL_REPO_ROOT"), "QUICKSHELL_REPO_ROOT is required")

local placement_calls = { no_offscreen = 0, centered = 0 }

local function placement(name)
  return setmetatable({}, {
    __call = function()
      placement_calls[name] = (placement_calls[name] or 0) + 1
    end,
    __add = function()
      return placement("combined")
    end,
  })
end

local delayed = {}
local timed = {}
local awful = {
  client = { focus = { filter = function() return true end } },
  screen = { preferred = {} },
  placement = {
    no_overlap = placement("no_overlap"),
    no_offscreen = placement("no_offscreen"),
    centered = placement("centered"),
  },
}
local beautiful = {
  border_width = 2,
  border_normal = "#222222",
  border_focus = "#ffffff",
}
local gears = {
  filesystem = { get_cache_dir = function() return "/tmp/quickshell-awesome-test-cache" end },
  timer = {
    delayed_call = function(callback) delayed[#delayed + 1] = callback end,
    start_new = function(_, callback)
      timed[#timed + 1] = callback
      return { stop = function() end }
    end,
  },
}

package.loaded.awful = awful
package.loaded.beautiful = beautiful
package.loaded.gears = gears

local function contains(values, expected)
  for _, value in ipairs(values or {}) do
    if value == expected then return true end
  end
  return false
end

local rules = dofile(root .. "/awesome/.config/awesome/rules.lua").get({}, {})
local default_rule = assert(rules[1], "default Awesome rule exists")
assert(default_rule.except_any and contains(default_rule.except_any.type, "dock"),
  "dock surfaces are excluded from the catch-all application rule")
assert(contains(default_rule.except_any.name, "quickshell-shell"),
  "Quickshell is excluded before its dock type arrives")
assert(default_rule.properties.screen == nil and default_rule.properties.placement == nil,
  "catch-all rules never take screen or geometry ownership before identity settles")

local dock_rule
for _, candidate in ipairs(rules) do
  if candidate.rule_any and contains(candidate.rule_any.type, "dock") then
    dock_rule = candidate
    break
  end
end
assert(dock_rule, "Awesome has a dedicated dock rule")
assert(dock_rule.properties.border_width == 0, "dock surfaces are borderless")
assert(dock_rule.properties.floating == true, "dock surfaces remain floating")
assert(dock_rule.properties.sticky == true, "dock surfaces remain on every tag")
assert(dock_rule.properties.skip_taskbar == true, "dock surfaces stay out of task lists")
assert(contains(dock_rule.rule_any.name, "quickshell-shell"),
  "dock policy matches Quickshell's pre-map window name")
assert(dock_rule.properties.screen == nil and dock_rule.properties.placement == nil,
  "Awesome does not take screen or geometry ownership from dock surfaces")

local handlers = {}
_G.client = {
  get = function() return {} end,
  connect_signal = function(name, callback)
    handlers[name] = handlers[name] or {}
    handlers[name][#handlers[name] + 1] = callback
  end,
}
_G.awesome = { startup = true }
_G.screen = setmetatable({ count = function() return 0 end }, {
  __index = function() return nil end,
})
_G.screen.connect_signal = function() end
_G.tag = { connect_signal = function() end }

local signals = dofile(root .. "/awesome/.config/awesome/signals.lua")
signals.setup()
local manage = assert(handlers.manage and handlers.manage[1], "manage handler is registered")
local dock = {
  valid = true,
  name = nil,
  class = nil,
  instance = nil,
  type = "normal",
  floating = true,
  size_hints = { user_position = false, program_position = false },
}
manage(dock)

dock.name = "quickshell-shell"
dock.type = "dock"

for _, callback in ipairs(delayed) do callback() end
for _, callback in ipairs(timed) do callback() end
assert(placement_calls.no_offscreen == 0,
  "startup no-offscreen placement does not move dock surfaces")
assert(placement_calls.centered == 0,
  "delayed floating-client placement does not center dock surfaces")

local type_changed = assert(handlers["property::type"] and handlers["property::type"][1],
  "late dock type has a repair signal")
type_changed(dock)
assert(dock.border_width == 0 and dock.floating and dock.sticky and dock.skip_taskbar,
  "late dock type reapplies geometry-neutral client properties")

print("ok - Awesome leaves Quickshell dock geometry to Quickshell")
