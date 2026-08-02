-------------------------------------------------------------------------------
-- ui.bar.resources — right pill B: CPU · RAM · battery.
-- Battery section self-hides when unavailable (no awkward separators).
-------------------------------------------------------------------------------
local awful = require("awful")
local wibox = require("wibox")
local gears = require("gears")
local beautiful = require("beautiful")
local dpi = require("beautiful.xresources").apply_dpi
local pill = require("ui.bar.pill")

local resources = {}

local function seg(icon)
	local w = wibox.widget.textbox()
	w.font = beautiful.font
	w.markup = '<span foreground="'
		.. (beautiful.bar_pill_fg_muted or beautiful.fg_minimize)
		.. '">'
		.. icon
		.. "</span>"
	return w
end

function resources.new(s)
	local cpu_icon = seg("CPU")
	local cpu_val = wibox.widget.textbox()
	cpu_val.font = beautiful.font
	cpu_val.markup = " 0%"
	cpu_val.forced_width = dpi(34)
	cpu_val.align = "right"
	awesome.connect_signal("service::cpu", function(st)
		cpu_val.markup = " " .. (st.percentage or 0) .. "%"
	end)

	local ram_icon = seg("RAM")
	local ram_val = wibox.widget.textbox()
	ram_val.font = beautiful.font
	ram_val.markup = " 0%"
	ram_val.forced_width = dpi(34)
	ram_val.align = "right"
	awesome.connect_signal("service::memory", function(st)
		ram_val.markup = " " .. (st.percentage or 0) .. "%"
	end)

	-- Battery: conditionally rendered.
	local bat_icon = seg("󰁹")
	local bat_val = wibox.widget.textbox()
	bat_val.font = beautiful.font
	bat_val.forced_width = dpi(34)
	bat_val.align = "right"
	local bat_sep = wibox.widget.textbox(" · ")
	bat_sep.font = beautiful.font
	bat_icon.visible = false
	bat_val.visible = false
	bat_sep.visible = false
	awesome.connect_signal("service::battery", function(st)
		if not st.available then
			bat_icon.visible = false
			bat_val.visible = false
			bat_sep.visible = false
			return
		end
		bat_icon.visible = true
		bat_val.visible = true
		bat_sep.visible = true
		local icon = "󰁹"
		if st.state_str == "charging" then
			icon = "󰂄"
		elseif st.warning_level >= 3 then
			icon = "󰂃"
		elseif st.warning_level == 2 then
			icon = "󰁿"
		end
		local fg = (st.warning_level >= 2) and (beautiful.bar_urgent or beautiful.bg_urgent) or nil
		local color_open = fg and ('<span foreground="' .. fg .. '">') or ""
		local color_close = fg and "</span>" or ""
		bat_icon.markup = '<span foreground="'
			.. (fg or (beautiful.bar_pill_fg_muted or beautiful.fg_minimize))
			.. '">'
			.. icon
			.. "</span>"
		bat_val.markup = color_open .. " " .. st.percentage .. "%" .. color_close
	end)

	local content = wibox.layout.fixed.horizontal()
	content.spacing = dpi(2)
	content:add(cpu_icon)
	content:add(cpu_val)
	local sep1 = wibox.widget.textbox(" · ")
	sep1.font = beautiful.font
	content:add(sep1)
	content:add(ram_icon)
	content:add(ram_val)
	content:add(bat_sep)
	content:add(bat_icon)
	content:add(bat_val)

	local p, bg = pill({
		child = content,
		spacing = dpi(0),
		hover = true,
		buttons = gears.table.join(
			awful.button({}, 1, function()
				awesome.emit_signal("pill::toggle_popup", "resources", mouse.current_widget_geometry or p, s)
			end),
			awful.button({}, 3, function()
				awful.spawn("wezterm start -- btop", false)
			end)
		),
	})
	p._pill_tooltip = awful.tooltip({
		objects = { p },
		text = "System: click for details · right-click for System Monitor",
	})
	return p, bg
end

return setmetatable(resources, {
	__call = function(_, ...)
		return resources.new(...)
	end,
})
