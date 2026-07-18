local awful = require("awful")
local gears = require("gears")
local beautiful = require("beautiful")
local io = io
local tostring = tostring
local os = os

local signals = {}

function signals.setup()
	local function is_chrome(c)
		return c.class == "Google-chrome" or c.class == "google-chrome" or c.class == "Google Chrome"
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
		if awesome.startup and not c.size_hints.user_position and not c.size_hints.program_position then
			awful.placement.no_offscreen(c)
		end

		gears.timer.delayed_call(function()
			if c.valid and c.floating then
				awful.placement.centered(c, {
					honor_padding = true,
					honor_workarea = true
				})
			end
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

	client.connect_signal("focus", function(c)
		c.border_color = beautiful.border_focus
	end)
	client.connect_signal("unfocus", function(c)
		c.border_color = beautiful.border_normal
	end)

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

				-- Restore tags per screen (starting from line 3)
				for i = 1, screen.count() do
					local tag_idx = tonumber(lines[i + 2])
					if tag_idx and screen[i] and screen[i].tags[tag_idx] then
						screen[i].tags[tag_idx]:view_only()
					end
				end

				-- Restore screen focus
				if focus_screen and screen[focus_screen] then
					awful.screen.focus(screen[focus_screen])
				end

				-- Restore client focus
				if focus_window ~= "nil" then
					for _, c in ipairs(client.get()) do
						if tostring(c.window) == focus_window then
							client.focus = c
							c:raise()
							break
						end
					end
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
