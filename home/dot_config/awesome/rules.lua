local awful = require("awful")
local beautiful = require("beautiful")

local rules = {}

function rules.get(clientkeys, clientbuttons)
    return {
        {
            rule_any = {
                type = { "dialog", "normal", "splash", "utility" },
            },
            except_any = {
                class = { "quickshell-shell" },
                instance = { "quickshell-shell" },
                name = { "quickshell-shell" },
                type = { "desktop", "dock" },
            },
            properties = {
                border_width = beautiful.border_width,
                border_color = beautiful.border_normal,
                focus = awful.client.focus.filter,
                raise = true,
                keys = clientkeys,
                buttons = clientbuttons,
                titlebars_enabled = false
            }
        },
        {
            rule_any = {
                class = { "quickshell-shell" },
                instance = { "quickshell-shell" },
                name = { "quickshell-shell" },
                type = { "dock" },
            },
            properties = {
                border_width = 0,
                floating = true,
                sticky = true,
                skip_taskbar = true,
                titlebars_enabled = false,
            },
        },
        {
            rule_any = {
                name = {
                    "quickshell-application-launcher",
                    "quickshell-window-switcher",
                    "quickshell-session-menu",
                    "quickshell-calendar",
                    "quickshell-keybind-help",
                    "quickshell-display-manager",
                },
            },
            properties = {
                border_width = 0,
                floating = true,
                sticky = true,
                skip_taskbar = true,
                ontop = true,
                focus = true,
                raise = true,
                titlebars_enabled = false,
            },
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
