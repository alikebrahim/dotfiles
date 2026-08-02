local root = assert(os.getenv("QUICKSHELL_REPO_ROOT"), "QUICKSHELL_REPO_ROOT is required")

local focused_screen
local screens = {}
local emitted = {}

local fake_screen = { primary = nil }
function fake_screen.count() return #screens end
setmetatable(fake_screen, {
  __call = function(_, _, previous)
    if previous == nil then return screens[1] end
    for index, candidate in ipairs(screens) do
      if candidate == previous then return screens[index + 1] end
    end
    return nil
  end,
})

local function make_screen(index)
  local target = {
    index = index,
    valid = true,
    tags = {},
  }
  for tag_index = 1, 5 do
    local candidate = {
      index = tag_index,
      name = tostring(tag_index),
      screen = target,
      selected = tag_index == 1,
      urgent = false,
      _clients = {},
    }
    function candidate:view_only()
      for _, sibling in ipairs(self.screen.tags) do
        sibling.selected = sibling == self
      end
      self.screen.selected_tag = self
    end
    function candidate:clients() return self._clients end
    target.tags[tag_index] = candidate
  end
  target.selected_tag = target.tags[1]
  return target
end

screens[1] = make_screen(1)
screens[2] = make_screen(2)
fake_screen.primary = screens[2]
focused_screen = screens[1]

local fake_client = { focus = nil }
function fake_client.get() return {} end

local fake_awful = {
  screen = {
    focused = function() return focused_screen end,
    focus = function(target) focused_screen = target end,
  },
  client = {
    focus = {
      filter = function() return true end,
      history = { get = function() return nil end },
    },
  },
  placement = {},
}

local fake_gears = {
  timer = {
    delayed_call = function(callback) callback() end,
    start_new = function(_, callback) callback(); return {} end,
  },
  filesystem = { get_cache_dir = function() return "/tmp" end },
}

local old_screen, old_client, old_awesome = _G.screen, _G.client, _G.awesome
local old_awful, old_gears, old_beautiful = package.loaded.awful, package.loaded.gears, package.loaded.beautiful
_G.screen, _G.client = fake_screen, fake_client
_G.awesome = { emit_signal = function(name, index) emitted[#emitted + 1] = { name, index } end }
package.loaded.awful = fake_awful
package.loaded.gears = fake_gears
package.loaded.beautiful = {}

package.loaded.signals = nil
local signals = dofile(root .. "/awesome/.config/awesome/signals.lua")
local workspace = assert(signals.workspace, "signals exports the workspace coordinator")

screens[1].tags[2]:view_only()
screens[2].tags[4]:view_only()
assert(not workspace.is_synchronized(), "fixture begins desynchronized")
assert(workspace.view_relative(1, { preferred_screen = screens[1], restore_focus = false }))
assert(screens[1].selected_tag.index == 3 and screens[2].selected_tag.index == 3,
  "relative navigation computes once and applies one index to every screen")
assert(workspace.is_synchronized(3), "relative navigation restores the invariant")

local app = { valid = true, type = "normal", class = "Example" }
local shell = { valid = true, type = "dock", class = "quickshell-shell" }
screens[2].tags[2]._clients = { app }
screens[1].tags[2].urgent = true
screens[1].tags[4]._clients = { shell }
local tags, active_index, synchronized = workspace.snapshot_tags(function(candidate)
  return candidate.type ~= "dock" and candidate.class ~= "quickshell-shell"
end)
assert(active_index == 3 and synchronized, "snapshot exposes one synchronized active index")
assert(tags[2].occupied and tags[2].urgent, "snapshot aggregates occupied and urgent state across outputs")
assert(not tags[4].occupied, "snapshot filter excludes shell-only occupancy")

screens[2].tags[5]:view_only()
workspace.handle_selection_change(screens[2].tags[5])
assert(screens[1].selected_tag.index == 5 and screens[2].selected_tag.index == 5,
  "an external single-screen selection is repaired globally")

assert(workspace.view_index(3, { restore_focus = false }))
local moved = {
  valid = true,
  type = "normal",
  class = "Example",
  screen = screens[1],
  first_tag = screens[1].tags[3],
  raised = false,
}
function moved:move_to_tag(target)
  self.first_tag = target
  self.screen = target.screen
end
function moved:isvisible() return self.first_tag.selected end
function moved:raise() self.raised = true end
fake_client.focus = moved
assert(workspace.move_client_relative(moved, 1, true), "move-and-follow succeeds within range")
assert(moved.first_tag == screens[1].tags[4], "client moves to the same-screen tag at the target index")
assert(screens[1].selected_tag.index == 4 and screens[2].selected_tag.index == 4,
  "move-and-follow advances every output together")
assert(fake_client.focus == moved and moved.raised, "move-and-follow restores client focus")

assert(workspace.view_index(5, { restore_focus = false }))
assert(workspace.move_client_relative(moved, 1, true),
  "relative client movement wraps from the last workspace to the first")
assert(moved.first_tag == screens[1].tags[1]
  and screens[1].selected_tag.index == 1 and screens[2].selected_tag.index == 1,
  "forward wrap moves the client and follows on every output")
assert(workspace.move_client_relative(moved, -1, true),
  "relative client movement wraps from the first workspace to the last")
assert(moved.first_tag == screens[1].tags[5]
  and screens[1].selected_tag.index == 5 and screens[2].selected_tag.index == 5,
  "backward wrap moves the client and follows on every output")
assert(not workspace.view_index(6), "unavailable absolute indices are rejected")
assert(#emitted >= 1 and emitted[#emitted][1] == "workspace_sync::changed",
  "successful synchronization publishes the coordinator signal")

_G.screen, _G.client, _G.awesome = old_screen, old_client, old_awesome
package.loaded.awful, package.loaded.gears, package.loaded.beautiful = old_awful, old_gears, old_beautiful
package.loaded.signals = nil

print("ok - workspace coordinator synchronization, aggregation, repair, and move-follow")
