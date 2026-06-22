local gears = require("gears")
local awful = require("awful")
local beautiful = require("beautiful")

local keys = {}

-- Spatial focus helpers.
--
-- Policy:
--   - tiled clients only: floating clients do not participate;
--   - visible/current-tag clients only: no jumping to other workspaces;
--   - minimized clients are ignored;
--   - maximized tiled clients still participate, but h/l from a maximized
--     client jumps to the previous/next screen immediately.
local function screen_sort_key(s)
    local g = s.geometry
    return g.x, g.y, s.index
end

local function sorted_screens()
    local screens = {}
    for s in screen do
        table.insert(screens, s)
    end

    table.sort(screens, function(a, b)
        local ax, ay, ai = screen_sort_key(a)
        local bx, by, bi = screen_sort_key(b)

        if ax ~= bx then return ax < bx end
        if ay ~= by then return ay < by end
        return ai < bi
    end)

    return screens
end

local function client_sort_key(c)
    local g = c:geometry()
    return g.x, g.y, c.window
end

local function is_spatial_focus_client(c)
    return c
        and c.valid
        and c.type ~= "desktop"
        and c.type ~= "dock"
        and not c.floating
        and not c.minimized
        and c:isvisible()
end

local function sorted_spatial_clients_for_screen(s)
    local clients = {}

    for _, c in ipairs(client.get()) do
        if c.screen == s and is_spatial_focus_client(c) then
            table.insert(clients, c)
        end
    end

    table.sort(clients, function(a, b)
        local ax, ay, aw = client_sort_key(a)
        local bx, by, bw = client_sort_key(b)

        if ax ~= bx then return ax < bx end
        if ay ~= by then return ay < by end
        return aw < bw
    end)

    return clients
end

local function get_all_spatial_clients_sorted()
    local clients = {}

    for _, s in ipairs(sorted_screens()) do
        for _, c in ipairs(sorted_spatial_clients_for_screen(s)) do
            table.insert(clients, c)
        end
    end

    return clients
end

local function focus_client(c)
    if not c or not c.valid then return end

    client.focus = c
    awful.screen.focus(c.screen)
    c:raise()
end

local function focus_screen_edge_client(from_screen, direction)
    local screens = sorted_screens()
    if #screens == 0 then return false end

    local current_index = 1
    for i, s in ipairs(screens) do
        if s == from_screen then
            current_index = i
            break
        end
    end

    for step = 1, #screens - 1 do
        local target_index = current_index + (direction * step)
        while target_index < 1 do target_index = target_index + #screens end
        while target_index > #screens do target_index = target_index - #screens end

        local clients = sorted_spatial_clients_for_screen(screens[target_index])
        if #clients > 0 then
            if direction > 0 then
                focus_client(clients[1])
            else
                focus_client(clients[#clients])
            end
            return true
        end
    end

    return false
end

local function focus_spatial(direction)
    local current = client.focus
    if not current or not current.valid then return end

    if current.maximized then
        if focus_screen_edge_client(current.screen, direction) then
            return
        end
    end

    local clients = get_all_spatial_clients_sorted()
    if #clients == 0 then return end

    for i, c in ipairs(clients) do
        if c == current then
            local target_index = i + direction
            if target_index < 1 then target_index = #clients end
            if target_index > #clients then target_index = 1 end

            focus_client(clients[target_index])
            return
        end
    end

    -- If the current client does not participate, e.g. it is floating, fall back
    -- to the nearest edge of the visible tiled set.
    if direction > 0 then
        focus_client(clients[1])
    else
        focus_client(clients[#clients])
    end
end

local function view_workspace_relative_all_screens(direction)
    local focused_client = client.focus
    local focused_screen

    if focused_client and focused_client.valid then
        focused_screen = focused_client.screen
    else
        focused_screen = awful.screen.focused()
    end

    for s in screen do
        if direction > 0 then
            awful.tag.viewnext(s)
        else
            awful.tag.viewprev(s)
        end
    end

    -- awful.autofocus reacts to tag selection via delayed callbacks. Restore
    -- focus after those callbacks so multi-screen tag navigation doesn't settle
    -- on whichever screen autofocus processed last.
    gears.timer.delayed_call(function()
        if not focused_screen or not focused_screen.valid then
            return
        end

        if focused_client and focused_client.valid and focused_client:isvisible() then
            focus_client(focused_client)
            return
        end

        local c = awful.client.focus.history.get(focused_screen, 0, function(candidate)
            return candidate
                and candidate.valid
                and candidate.screen == focused_screen
                and candidate:isvisible()
                and awful.client.focus.filter(candidate)
        end)

        if c then
            focus_client(c)
        else
            awful.screen.focus(focused_screen)
        end
    end)
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
  awful.key({ modkey, "Control" }, "t", function() awful.spawn("/home/alikebrahim/.dotfiles/awesomewm-bin/theme-select") end, { description = "theme selector", group = "launcher" }),
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
      focus_spatial(-1)
  end, {description = "focus previous tiled window/screen (spatial)", group = "client"}),

  awful.key({ modkey }, "l", function()
      focus_spatial(1)
  end, {description = "focus next tiled window/screen (spatial)", group = "client"}),

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

  awful.key({ modkey, "Control" }, "k", function()
      view_workspace_relative_all_screens(1)
  end, {description = "view next workspace on all screens", group = "tag"}),
  awful.key({ modkey, "Control" }, "j", function()
      view_workspace_relative_all_screens(-1)
  end, {description = "view previous workspace on all screens", group = "tag"}),

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
    awful.key({ modkey, "Control", "Shift" }, "t", function(c) awful.titlebar.toggle(c) end,
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
