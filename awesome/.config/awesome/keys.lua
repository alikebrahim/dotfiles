local gears = require("gears")
local awful = require("awful")
local beautiful = require("beautiful")

local keys = {}

-- Helper function to get all tiled clients sorted by X coordinate (left to right)
local function get_all_tiled_clients_sorted_by_x()
	local clients = {}
	for s in screen do
		for _, c in pairs(s.tiled_clients) do
			table.insert(clients, c)
		end
	end
	table.sort(clients, function(a, b) return a:geometry().x < b:geometry().x end)
	return clients
end


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

  -- Navigation (spatial focus across screens)
  awful.key({ modkey }, "h", function()
      local clients = get_all_tiled_clients_sorted_by_x()
      local current = client.focus
      
      if not current or #clients == 0 then return end
      
      for i, c in ipairs(clients) do
          if c == current then
              if i > 1 then  -- Not leftmost, move to previous window
                  client.focus = clients[i - 1]
                  clients[i - 1]:raise()
              end
              return
          end
      end
  end, {description = "focus left window (spatial)", group = "client"}),

  awful.key({ modkey }, "l", function()
      local clients = get_all_tiled_clients_sorted_by_x()
      local current = client.focus
      
      if not current or #clients == 0 then return end
      
      for i, c in ipairs(clients) do
          if c == current then
              if i < #clients then  -- Not rightmost, move to next window
                  client.focus = clients[i + 1]
                  clients[i + 1]:raise()
              end
              return
          end
      end
  end, {description = "focus right window (spatial)", group = "client"}),

  awful.key({ modkey }, "k", function() awful.client.focus.bydirection("up"); if client.focus then client.focus:raise() end end, {description = "focus up", group = "client"}),
  awful.key({ modkey }, "j", function() awful.client.focus.bydirection("down"); if client.focus then client.focus:raise() end end, {description = "focus down", group = "client"}),

  awful.key({ modkey, "Control" }, "h", function()
      if screen.count() > 1 then
          awful.screen.focus_relative(-1)
          local cls = awful.screen.focused().tiled_clients
          if #cls > 0 then
              client.focus = cls[1]
              cls[1]:raise()
          end
      end
  end, {description = "focus previous screen", group = "screen"}),

  awful.key({ modkey, "Control" }, "l", function()
      if screen.count() > 1 then
          awful.screen.focus_relative(1)
          local cls = awful.screen.focused().tiled_clients
          if #cls > 0 then
              client.focus = cls[1]
              cls[1]:raise()
          end
      end
  end, {description = "focus next screen", group = "screen"}),

  awful.key({ modkey, "Control" }, "k", awful.tag.viewnext, {description = "view next workspace", group = "tag"}),
  awful.key({ modkey, "Control" }, "j", awful.tag.viewprev, {description = "view previous workspace", group = "tag"}),

  awful.key({ modkey, "Shift" }, "h", function()
      -- Move focused window to left screen
      if client.focus and screen.count() > 1 then
          local current_screen = client.focus.screen
          local target_screen = current_screen.index - 1
          if target_screen < 1 then target_screen = screen.count() end
          client.focus:move_to_screen(target_screen)
          awful.screen.focus(target_screen)
          if client.focus then client.focus:raise() end
      end
  end, {description = "move window to left screen", group = "screen"}),

  awful.key({ modkey, "Shift" }, "l", function()
      -- Move focused window to right screen
      if client.focus and screen.count() > 1 then
          local current_screen = client.focus.screen
          local target_screen = current_screen.index + 1
          if target_screen > screen.count() then target_screen = 1 end
          client.focus:move_to_screen(target_screen)
          awful.screen.focus(target_screen)
          if client.focus then client.focus:raise() end
      end
  end, {description = "move window to right screen", group = "screen"}),

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
