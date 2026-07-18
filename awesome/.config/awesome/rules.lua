local awful = require("awful")
local beautiful = require("beautiful")

local rules = {}

function rules.get(clientkeys, clientbuttons)
    return {
        {
            rule = {},
            properties = {
                border_width = beautiful.border_width,
                border_color = beautiful.border_normal,
                focus = awful.client.focus.filter,
                raise = true,
                keys = clientkeys,
                buttons = clientbuttons,
                screen = awful.screen.preferred,
                placement = awful.placement.no_overlap + awful.placement.no_offscreen,
                titlebars_enabled = false
            }
        },
        {
            rule_any = {
                type = { "dialog" },
                instance = { "copyq", "pinentry" },
                class = { "Arandr", "Blueman-manager", "Pavucontrol", "Nm-connection-editor" },
                name = { "Event Tester" },
                role = { "AlarmWindow", "ConfigManager", "pop-up" },
            },
            properties = { floating = true },
        },
    }
end

return rules
