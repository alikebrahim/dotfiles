local awful = require("awful")
local gears = require("gears")
local beautiful = require("beautiful")
local io = io
local tostring = tostring
local os = os

local signals = {}

-- Awesome tags are screen-local objects, but this desktop treats one tag
-- index as a single logical workspace spanning every output. Keep every
-- view/move/restore path behind this coordinator so no caller can advance
-- screens independently.
local workspace = {}
local synchronizing = false
local repair_scheduled = false
local pending_index = nil

local function object_is_valid(value)
	return value ~= nil and value.valid ~= false
end

local function screen_snapshot()
	local screens = {}
	for candidate in screen do
		table.insert(screens, candidate)
	end
	return screens
end

local function selected_index_for_screen(target_screen)
	if not object_is_valid(target_screen) then return nil end
	local selected = target_screen.selected_tag
	if selected and selected.index then return tonumber(selected.index) end
	for index, candidate in ipairs(target_screen.tags or {}) do
		if candidate.selected then return index end
	end
	return nil
end

local function authoritative_screen(options)
	options = options or {}
	if object_is_valid(options.preferred_screen) then
		return options.preferred_screen
	end
	if client.focus and object_is_valid(client.focus)
		and object_is_valid(client.focus.screen) then
		return client.focus.screen
	end
	local focused = awful.screen.focused()
	if object_is_valid(focused) then return focused end
	if object_is_valid(screen.primary) then return screen.primary end
	return screen_snapshot()[1]
end

function workspace.current_index(options)
	local index = selected_index_for_screen(authoritative_screen(options))
	return index or 1
end

function workspace.tag_count(options)
	local count
	for _, target_screen in ipairs(screen_snapshot()) do
		local screen_count = #(target_screen.tags or {})
		count = count and math.min(count, screen_count) or screen_count
	end
	if count then return count end
	local target_screen = authoritative_screen(options)
	return target_screen and #(target_screen.tags or {}) or 0
end

local function valid_index(index, options)
	local number = tonumber(index)
	if not number or number % 1 ~= 0 then return nil end
	if number < 1 or number > workspace.tag_count(options) then return nil end
	return number
end

function workspace.is_synchronized(index)
	index = valid_index(index or workspace.current_index())
	if not index then return false end
	local found_screen = false
	for _, target_screen in ipairs(screen_snapshot()) do
		found_screen = true
		local selected_count = 0
		local selected_index
		for candidate_index, candidate in ipairs(target_screen.tags or {}) do
			if candidate.selected then
				selected_count = selected_count + 1
				selected_index = candidate_index
			end
		end
		if selected_count ~= 1 or selected_index ~= index then return false end
	end
	return found_screen
end

local function focus_client(target_client)
	if not object_is_valid(target_client) then return false end
	client.focus = target_client
	if object_is_valid(target_client.screen) then
		pcall(awful.screen.focus, target_client.screen)
	end
	target_client:raise()
	return true
end

local function restore_focus(focused_client, focused_screen)
	gears.timer.delayed_call(function()
		if object_is_valid(focused_client) and focused_client:isvisible() then
			focus_client(focused_client)
			return
		end
		if not object_is_valid(focused_screen) then return end

		local candidate = awful.client.focus.history.get(focused_screen, 0, function(value)
			return object_is_valid(value)
				and value.screen == focused_screen
				and value:isvisible()
				and awful.client.focus.filter(value)
		end)
		if not focus_client(candidate) then
			pcall(awful.screen.focus, focused_screen)
		end
	end)
end

function workspace.view_index(index, options)
	options = options or {}
	index = valid_index(index, options)
	if not index then return false, "workspace index is unavailable" end

	local screens = screen_snapshot()
	if #screens == 0 then return false, "no screens are available" end
	for _, target_screen in ipairs(screens) do
		if not target_screen.tags or not target_screen.tags[index] then
			return false, "workspace index is unavailable on every screen"
		end
	end

	local focused_client
	if options.preserve_focus ~= false then
		focused_client = options.focus_client or client.focus
	end
	local focused_screen = options.focused_screen
		or (object_is_valid(focused_client) and focused_client.screen)
		or authoritative_screen(options)

	synchronizing = true
	local ok, err = pcall(function()
		for _, target_screen in ipairs(screens) do
			target_screen.tags[index]:view_only()
		end
	end)
	synchronizing = false
	if not ok then return false, tostring(err) end

	pending_index = nil
	if options.restore_focus ~= false then
		restore_focus(focused_client, focused_screen)
	end
	if awesome and awesome.emit_signal then
		awesome.emit_signal("workspace_sync::changed", index)
	end
	return true
end

function workspace.view_relative(direction, options)
	options = options or {}
	direction = tonumber(direction)
	if not direction or direction == 0 then return false, "direction is required" end
	local count = workspace.tag_count(options)
	if count == 0 then return false, "no workspaces are available" end
	local current = workspace.current_index(options)
	local target = ((current - 1 + (direction > 0 and 1 or -1)) % count) + 1
	return workspace.view_index(target, options)
end

function workspace.move_client_to_index(target_client, index, follow)
	if not object_is_valid(target_client) or not object_is_valid(target_client.screen) then
		return false, "focused client is unavailable"
	end
	index = valid_index(index, { preferred_screen = target_client.screen })
	local target_tag = index and target_client.screen.tags[index]
	if not target_tag then return false, "workspace index is unavailable" end

	target_client:move_to_tag(target_tag)
	if follow == false then return true end
	return workspace.view_index(index, {
		preferred_screen = target_client.screen,
		focus_client = target_client,
		focused_screen = target_client.screen,
	})
end

function workspace.move_client_relative(target_client, direction, follow)
	if not object_is_valid(target_client) then return false, "focused client is unavailable" end
	direction = tonumber(direction)
	if not direction or direction == 0 then return false, "direction is required" end
	local options = { preferred_screen = target_client.screen }
	local count = workspace.tag_count(options)
	if count == 0 then return false, "no workspaces are available" end
	local current = workspace.current_index(options)
	local target = ((current - 1 + (direction > 0 and 1 or -1)) % count) + 1
	return workspace.move_client_to_index(target_client, target, follow)
end

function workspace.snapshot_tags(client_filter)
	local screens = screen_snapshot()
	local authority = authoritative_screen()
	local active_index = workspace.current_index({ preferred_screen = authority })
	local entries = {}
	for index = 1, workspace.tag_count({ preferred_screen = authority }) do
		local occupied = false
		local urgent = false
		for _, target_screen in ipairs(screens) do
			local candidate_tag = target_screen.tags[index]
			if candidate_tag then
				urgent = urgent or not not candidate_tag.urgent
				local candidates = candidate_tag.clients and candidate_tag:clients() or {}
				for _, candidate in ipairs(candidates) do
					if not client_filter or client_filter(candidate) then
						occupied = true
						break
					end
				end
			end
		end
		local authority_tag = authority and authority.tags and authority.tags[index]
		entries[#entries + 1] = {
			name = tostring(authority_tag and authority_tag.name or index),
			selected = index == active_index,
			occupied = occupied,
			urgent = urgent,
		}
	end
	return entries, active_index, workspace.is_synchronized(active_index)
end

function workspace.handle_selection_change(changed_tag)
	if synchronizing then return end
	if changed_tag and changed_tag.selected and changed_tag.index then
		pending_index = tonumber(changed_tag.index)
	elseif not pending_index then
		pending_index = workspace.current_index()
	end
	if repair_scheduled then return end
	repair_scheduled = true
	gears.timer.delayed_call(function()
		repair_scheduled = false
		local target = pending_index
		pending_index = nil
		if target then workspace.view_index(target) end
	end)
end

function workspace.schedule_repair()
	workspace.handle_selection_change(nil)
end

signals.workspace = workspace

function signals.setup()
	local function is_chrome(c)
		return c.class == "Google-chrome" or c.class == "google-chrome" or c.class == "Google Chrome"
	end

	local function owns_its_geometry(c)
		local class = tostring(c.class or ""):lower()
		local instance = tostring(c.instance or ""):lower()
		local name = tostring(c.name or ""):lower()
		return class == "quickshell-shell" or instance == "quickshell-shell"
			or name == "quickshell-shell"
			or c.type == "desktop" or c.type == "dock"
	end

	local function is_quickshell_modal(c)
		local name = tostring(c.name or ""):lower()
		return name == "quickshell-application-launcher"
			or name == "quickshell-window-switcher"
			or name == "quickshell-session-menu"
			or name == "quickshell-calendar"
			or name == "quickshell-keybind-help"
			or name == "quickshell-display-manager"
	end

	local function focus_quickshell_modal(c)
		if not c.valid or not is_quickshell_modal(c) or not c:isvisible() then return end
		client.focus = c
		c:raise()
	end

	local function enforce_geometry_owner_properties(c)
		if not c.valid or not owns_its_geometry(c) then return end
		c.border_width = 0
		c.floating = true
		c.sticky = true
		c.skip_taskbar = true
	end

	local function is_placeable_application(c)
		return c.type == "dialog" or c.type == "normal"
			or c.type == "splash" or c.type == "utility"
	end

	local function enforce_ordinary_client_not_sticky(c)
		if not c.valid or c.type ~= "normal" then return end
		local class = tostring(c.class or ""):lower()
		if class == "scratchpad" or owns_its_geometry(c) or is_quickshell_modal(c) then
			return
		end
		if not c.sticky then return end

		-- The retired generic-title shell rule set both flags on an ordinary
		-- application. Clear skip_taskbar only when that stale signature is
		-- present; maximized/floating state is intentionally left untouched.
		local stale_shell_signature = c.skip_taskbar
		c.sticky = false
		if stale_shell_signature then
			c.skip_taskbar = false
			gears.timer.delayed_call(function()
				if c.valid and c.type == "normal" and not c.sticky then
					c.skip_taskbar = false
				end
			end)
		end
	end

	local chrome_startup_guard = setmetatable({}, { __mode = "k" })

	local function force_chrome_tiled(c)
		if not is_chrome(c) or c.type == "dialog" or c.transient_for then
			return
		end
		c.fullscreen = false
		c.maximized = false
		c.maximized_horizontal = false
		c.maximized_vertical = false
		c.floating = false
		c.ontop = false
		c.above = false
		c.below = false
	end

	local function allow_chrome_transient(c)
		if not c.valid or not is_chrome(c) or not c.transient_for then return end
		chrome_startup_guard[c] = nil
		c.floating = true
		gears.timer.delayed_call(function()
			if c.valid and c.transient_for then
				awful.placement.centered(c, {
					honor_padding = true,
					honor_workarea = true,
				})
			end
		end)
	end

	client.connect_signal("manage", function(c)
		enforce_geometry_owner_properties(c)
		focus_quickshell_modal(c)
		enforce_ordinary_client_not_sticky(c)

		gears.timer.start_new(0.1, function()
			if not c.valid then return false end
			if owns_its_geometry(c) then
				enforce_geometry_owner_properties(c)
				focus_quickshell_modal(c)
			elseif is_placeable_application(c) then
				if awesome.startup and not c.size_hints.user_position
					and not c.size_hints.program_position then
					awful.placement.no_offscreen(c)
				end
				if not c.floating then return false end
				awful.placement.centered(c, {
					honor_padding = true,
					honor_workarea = true
				})
			end
			return false
		end)

		if is_chrome(c) and c.transient_for then
			allow_chrome_transient(c)
		elseif is_chrome(c) and c.type ~= "dialog" then
			chrome_startup_guard[c] = true
			gears.timer.delayed_call(function()
				force_chrome_tiled(c)
			end)
			gears.timer.start_new(2, function()
				chrome_startup_guard[c] = nil
				return false
			end)
		end
	end)

	client.connect_signal("property::name", function(c)
		enforce_geometry_owner_properties(c)
		focus_quickshell_modal(c)
	end)
	client.connect_signal("property::type", enforce_geometry_owner_properties)
	client.connect_signal("property::sticky", enforce_ordinary_client_not_sticky)

	-- QML activation requests are handled by Awesome's built-in
	-- awful.ewmh.activate handler. Do not call awful.screen.focus() from a
	-- request::activate handler: screen.focus() emits request::activate again.

	client.connect_signal("property::transient_for", function(c)
		allow_chrome_transient(c)
	end)

	client.connect_signal("property::maximized", function(c)
		if chrome_startup_guard[c] then
			force_chrome_tiled(c)
		end
	end)

	client.connect_signal("property::fullscreen", function(c)
		if chrome_startup_guard[c] then
			force_chrome_tiled(c)
		end
	end)

	-- Repair any tag selection made outside the coordinator on the next event
	-- loop turn. This covers third-party clients and legacy Awesome paths while
	-- avoiding re-entrant selection signals during a synchronized change.
	tag.connect_signal("property::selected", workspace.handle_selection_change)
	screen.connect_signal("added", workspace.schedule_repair)
	screen.connect_signal("removed", workspace.schedule_repair)
	screen.connect_signal("list", workspace.schedule_repair)

	client.connect_signal("focus", function(c)
		c.border_color = beautiful.border_focus
	end)
	client.connect_signal("unfocus", function(c)
		c.border_color = beautiful.border_normal
	end)

	-- Existing clients survive an Awesome restart with their mutable properties.
	-- Normalize only ordinary applications; shell docks and explicit modals keep
	-- their intentional sticky behavior.
	for _, c in ipairs(client.get()) do
		enforce_ordinary_client_not_sticky(c)
	end

	-- Restore focus and workspace state after reload
	gears.timer.delayed_call(function()
		local ok, err = pcall(function()
			local runtime_dir = os.getenv("XDG_RUNTIME_DIR") or gears.filesystem.get_cache_dir()
			local state_path = runtime_dir .. "/awesome-state"
			local f = io.open(state_path, "r")
			if f then
				local lines = {}
				for line in f:lines() do
					table.insert(lines, line)
				end
				f:close()
				os.remove(state_path)

				local focus_screen = tonumber(lines[1])
				local focus_window = lines[2]

				-- New state files carry one global index on line 3. For an older
				-- per-screen file, use the saved focused screen as authority.
				local tag_line = (#lines > 3 and focus_screen)
					and lines[focus_screen + 2] or lines[3]
				local tag_idx = tonumber(tag_line)
				if tag_idx then
					workspace.view_index(tag_idx, {
						preserve_focus = false,
						restore_focus = false,
					})
				end

				-- Restore screen focus
				if focus_screen and screen[focus_screen] then
					awful.screen.focus(screen[focus_screen])
				end

				-- Restore client focus only when the saved client belongs to the
				-- restored logical workspace. A client that used to be sticky may
				-- be focused while its own tag is hidden; focusing it here would
				-- make EWMH select that tag and override the saved global index.
				local restored_focus = false
				if focus_window ~= "nil" then
					for _, c in ipairs(client.get()) do
						if tostring(c.window) == focus_window and c:isvisible() then
							restored_focus = focus_client(c)
							break
						end
					end
				end
				if not restored_focus and focus_screen and screen[focus_screen] then
					restore_focus(nil, screen[focus_screen])
				end
			end
		end)
		if not ok then
			local runtime_dir = os.getenv("XDG_RUNTIME_DIR") or gears.filesystem.get_cache_dir()
			local log = io.open(runtime_dir .. "/awesome-state-restore-error.log", "w")
			if log then
				log:write(os.date("%Y-%m-%d %H:%M:%S") .. " - state restore error: " .. tostring(err) .. "\n")
				log:close()
			end
		end
	end)
end

return signals
