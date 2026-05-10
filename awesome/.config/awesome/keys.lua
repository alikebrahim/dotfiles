local gears = require("gears")
local awful = require("awful")
local beautiful = require("beautiful")

local keys = {}

-- -----------------------------------------------------------------------------
-- Global Keys
-- -----------------------------------------------------------------------------
keys.globalkeys = gears.table.join(
  awful.key({ modkey }, "s", function() awful.spawn("/home/alikebrahim/.config/scripts/rofi-keybinds.sh") end, { description = "show keybinds", group = "awesome" }),

  -- Launcher
  awful.key({ modkey }, "Return", function() awful.spawn(terminal) end, { description = "open terminal", group = "launcher" }),
  awful.key({ modkey, "Shift" }, "Return", function() awful.spawn(browser) end, { description = "open browser", group = "launcher" }),
  awful.key({ modkey }, "Tab", function() awful.spawn("rofi -show window") end, { description = "window switcher", group = "launcher" }),
  awful.key({ modkey }, "space", function() awful.spawn("rofi -show drun") end, { description = "application launcher", group = "launcher" }),
  awful.key({ modkey }, "f", function() awful.spawn("nautilus") end, { description = "open files", group = "launcher" }),
  awful.key({ modkey }, "p", function() awful.spawn("/home/alikebrahim/.config/scripts/rofi-display-manager.sh") end, { description = "display manager", group = "launcher" }),
  awful.key({ modkey }, "u", function() awful.spawn("/home/alikebrahim/.config/scripts/wm-stabilize.sh") end, { description = "refresh monitors/UI", group = "awesome" }),
  awful.key({ modkey }, "Escape", function() awful.spawn("/home/alikebrahim/.config/scripts/rofi-power-menu.sh") end, { description = "power menu", group = "awesome" }),
  awful.key({ modkey, "Control" }, "t", function() awful.spawn("/home/alikebrahim/.dotfiles/bin/theme-select") end, { description = "theme selector", group = "launcher" }),
  awful.key({ modkey, "Shift" }, "a", function() awful.spawn("/home/alikebrahim/.config/scripts/rofi-audio-menu.sh") end, { description = "audio controls", group = "launcher" }),
  awful.key({ modkey, "Shift" }, "w", function() awful.spawn("/home/alikebrahim/.config/scripts/rofi-wifi-menu.sh") end, { description = "wi-fi controls", group = "launcher" }),
  awful.key({ modkey, "Shift" }, "b", function() awful.spawn("/home/alikebrahim/.config/scripts/rofi-bluetooth-menu.sh") end, { description = "bluetooth controls", group = "launcher" }),
  awful.key({ modkey }, "grave", function() require("dynamism").term_scratch:toggle() end, { description = "toggle scratchpad", group = "launcher" }),

  -- Screenshots / capture, Omarchy-inspired but X11-native via Flameshot.
  awful.key({}, "Print", function() awful.spawn("/home/alikebrahim/.config/scripts/screenshot-flameshot.sh gui") end, { description = "interactive screenshot", group = "screenshots" }),
  awful.key({ modkey }, "Print", function() awful.spawn("/home/alikebrahim/.config/scripts/screenshot-flameshot.sh full") end, { description = "full screenshot", group = "screenshots" }),
  awful.key({ modkey, "Shift" }, "s", function() awful.spawn("/home/alikebrahim/.config/scripts/screenshot-flameshot.sh gui") end, { description = "region screenshot", group = "screenshots" }),

  awful.key({ modkey, "Shift" }, "space", function () awful.layout.inc( 1) end, {description = "select next layout", group = "layout"}),

  -- Navigation (Pop!_OS / Vim style with multi-screen support)
  awful.key({ modkey }, "h", function()
      local c = client.focus
      awful.client.focus.bydirection("left")
      if client.focus == c or (client.focus and client.focus.type == "dock") then
          awful.screen.focus_relative(-1)
          local cls = awful.screen.focused().tiled_clients
          if #cls > 0 then
              table.sort(cls, function(a, b) return a:geometry().x > b:geometry().x end)
              client.focus = cls[1]
          end
      end
      if client.focus then client.focus:raise() end
  end, {description = "focus left", group = "client"}),

  awful.key({ modkey }, "l", function()
      local c = client.focus
      awful.client.focus.bydirection("right")
      if client.focus == c or (client.focus and client.focus.type == "dock") then
          awful.screen.focus_relative(1)
          local cls = awful.screen.focused().tiled_clients
          if #cls > 0 then
              table.sort(cls, function(a, b) return a:geometry().x < b:geometry().x end)
              client.focus = cls[1]
          end
      end
      if client.focus then client.focus:raise() end
  end, {description = "focus right", group = "client"}),

  awful.key({ modkey }, "k", function() awful.client.focus.bydirection("up"); if client.focus then client.focus:raise() end end, {description = "focus up", group = "client"}),
  awful.key({ modkey }, "j", function() awful.client.focus.bydirection("down"); if client.focus then client.focus:raise() end end, {description = "focus down", group = "client"}),

  awful.key({ modkey, "Control" }, "k", awful.tag.viewnext, {description = "view next workspace", group = "tag"}),
  awful.key({ modkey, "Control" }, "j", awful.tag.viewprev, {description = "view previous workspace", group = "tag"}),

  awful.key({ modkey, "Shift" }, "h", function() if client.focus then client.focus:move_to_screen(client.focus.screen.index - 1) end end, {description = "move client to previous screen", group = "screen"}),
  awful.key({ modkey, "Shift" }, "l", function() if client.focus then client.focus:move_to_screen(client.focus.screen.index + 1) end end, {description = "move client to next screen", group = "screen"}),

  awful.key({ modkey, "Shift" }, "k", function()
      if client.focus then
          local t = client.focus.screen.tags[client.focus.screen.selected_tag.index + 1]
          if t then client.focus:move_to_tag(t); t:view_only() end
      end
  end, {description = "move client to next workspace and follow", group = "tag"}),
  awful.key({ modkey, "Shift" }, "j", function()
      if client.focus then
          local t = client.focus.screen.tags[client.focus.screen.selected_tag.index - 1]
          if t then client.focus:move_to_tag(t); t:view_only() end
      end
  end, {description = "move client to previous workspace and follow", group = "tag"}),

  -- Reload / quit
  awful.key({ modkey, "Shift" }, "r", function()
      local f = io.open("/tmp/awesome_state", "w")
      if f then
          -- Line 1: Screen Index
          f:write(awful.screen.focused().index .. "\n")
          -- Line 2: Focus Window ID
          f:write((client.focus and tostring(client.focus.window) or "nil") .. "\n")
          -- Lines 3+: Tag indices per screen
          for s in screen do
              f:write(s.selected_tag.index .. "\n")
          end
          f:close()
      end
      awesome.restart()
  end, { description = "reload awesome", group = "awesome" }),
  awful.key({ modkey, "Shift" }, "q", awesome.quit, { description = "quit awesome", group = "awesome" })
)

-- Workspaces 1-5
for i = 1, 5 do
  keys.globalkeys = gears.table.join(keys.globalkeys,
    awful.key({ modkey }, "#" .. i + 9, function()
      local screen = awful.screen.focused()
      local tag = screen.tags[i]
      if tag then tag:view_only() end
    end, { description = "view workspace " .. i, group = "workspace" }),
    awful.key({ modkey, "Shift" }, "#" .. i + 9, function()
      if client.focus then
        local tag = client.focus.screen.tags[i]
        if tag then client.focus:move_to_tag(tag) end
      end
    end, { description = "move focused client to workspace " .. i, group = "workspace" })
  )
end

-- -----------------------------------------------------------------------------
-- Client Keys
-- -----------------------------------------------------------------------------
keys.clientkeys = gears.table.join(
    awful.key({ modkey }, "m", function(c)
        c.maximized = not c.maximized
        c.border_width = c.maximized and 0 or beautiful.border_width
        c:raise()
    end, { description = "toggle maximize", group = "client" }),
    awful.key({ modkey }, "q", function(c) c:kill() end, { description = "close", group = "client" }),
    awful.key({ modkey }, "t", awful.client.floating.toggle, 
              { description = "toggle floating", group = "client" }),
    awful.key({ modkey, "Control" }, "t", function(c) awful.titlebar.toggle(c) end,
              { description = "toggle titlebar", group = "client" })
)

-- -----------------------------------------------------------------------------
-- Client Buttons
-- -----------------------------------------------------------------------------
keys.clientbuttons = gears.table.join(
  awful.button({}, 1, function(c)
    client.focus = c
    c:raise()
  end),
  awful.button({ modkey }, 1, function(c)
    client.focus = c
    c:raise()
    awful.mouse.client.move(c)
  end),
  awful.button({ modkey }, 3, function(c)
    client.focus = c
    c:raise()
    awful.mouse.client.resize(c)
  end)
)

return keys
