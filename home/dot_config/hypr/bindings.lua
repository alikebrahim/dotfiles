-- Personal keybinding overrides for Omarchy (thinkpad).
-- Managed by chezmoi on thinkpad. Scaffold vendored from Omarchy 4.0.2;
-- personal changes below.

-- See current bindings and descriptions:
--   omarchy menu keybindings --print

-- To disable every Omarchy default binding, set this in
-- ~/.config/hypr/hyprland.lua before require("default.hypr.omarchy"):
--   omarchy_default_bindings = false
--
-- To disable only preinstalled app/webapp bindings:
--   omarchy_preinstalled_bindings = false

-- Change an existing binding by unbinding it first, then binding the key again.
-- hl.unbind("SUPER + SPACE")
-- o.bind("SUPER + SPACE", "Omarchy menu", "omarchy-menu toggle root")

-- ═══════════════════════════════════════════════════════════════════
-- Window management
-- ═══════════════════════════════════════════════════════════════════

-- Close window: SUPER+W -> SUPER+Q.
hl.unbind("SUPER + W")
o.bind("SUPER + Q", "Close window", hl.dsp.window.close())

-- Fullscreen variants: use M, and swap full / full-width.
-- SUPER+M = full width (maximized), SUPER+ALT+M = full screen.
-- SUPER+CTRL+F (tiled fullscreen) is left as-is.
hl.unbind("SUPER + F")
hl.unbind("SUPER + ALT + F")
o.bind("SUPER + M", "Full width", hl.dsp.window.fullscreen({ mode = "maximized" }))
o.bind("SUPER + ALT + M", "Full screen", hl.dsp.window.fullscreen({ mode = "fullscreen" }))

-- Focus windows with vim keys (h/j/k/l).
-- SUPER+J/L were layout toggles (moved below); SUPER+K was keybindings help.
hl.unbind("SUPER + J")
hl.unbind("SUPER + L")
hl.unbind("SUPER + K")
o.bind("SUPER + H", "Focus on left window", hl.dsp.focus({ direction = "l" }))
o.bind("SUPER + J", "Focus on below window", hl.dsp.focus({ direction = "d" }))
o.bind("SUPER + K", "Focus on above window", hl.dsp.focus({ direction = "u" }))
o.bind("SUPER + L", "Focus on right window", hl.dsp.focus({ direction = "r" }))

-- Layout toggles moved off SUPER+J / SUPER+L.
o.bind("SUPER + ALT + J", "Toggle window split", hl.dsp.layout("togglesplit"))
o.bind("SUPER + ALT + L", "Toggle workspace layout", "omarchy-hyprland-workspace-layout-toggle")

-- ═══════════════════════════════════════════════════════════════════
-- Help (keybindings menus) — consolidated on SUPER+SHIFT+CTRL
--   SUPER+SHIFT+CTRL+K  Hyprland keybindings
--   SUPER+SHIFT+CTRL+T  tmux keybindings
--   SUPER+SHIFT+CTRL+H  herdr keybindings
-- ═══════════════════════════════════════════════════════════════════

o.bind("SUPER + SHIFT + CTRL + K", "Keybindings", "omarchy-menu-keybindings")

hl.unbind("SUPER + CTRL + K")
o.bind("SUPER + SHIFT + CTRL + T", "Tmux keybindings", "omarchy-menu-tmux-keybindings")

hl.unbind("SUPER + ALT + K")
o.bind("SUPER + SHIFT + CTRL + H", "Herdr keybindings", "omarchy-menu-herdr-keybindings")

-- ═══════════════════════════════════════════════════════════════════
-- Swap windows with vim keys (alongside the default SUPER+SHIFT+arrows)
-- ═══════════════════════════════════════════════════════════════════

hl.unbind("SUPER + SHIFT + K")
o.bind("SUPER + SHIFT + H", "Swap window to the left", hl.dsp.window.swap({ direction = "l" }))
o.bind("SUPER + SHIFT + J", "Swap window down", hl.dsp.window.swap({ direction = "d" }))
o.bind("SUPER + SHIFT + K", "Swap window up", hl.dsp.window.swap({ direction = "u" }))
o.bind("SUPER + SHIFT + L", "Swap window to the right", hl.dsp.window.swap({ direction = "r" }))

-- ═══════════════════════════════════════════════════════════════════
-- Apps (SUPER+SHIFT + first letter)
-- ═══════════════════════════════════════════════════════════════════

-- Files on SUPER+F (was fullscreen, now on SUPER+M).
-- SUPER+SHIFT+F remains as the Omarchy default alias.
o.bind("SUPER + F", "File manager", { omarchy = "nautilus" })

-- Proton Mail replaces the HEY email webapp on SUPER+SHIFT+E.
hl.unbind("SUPER + SHIFT + E")
hl.unbind("SUPER + SHIFT + ALT + E")
o.bind("SUPER + SHIFT + E", "Proton Mail", { launch = "proton-mail" })

-- Discord replaces Docker on SUPER+SHIFT+D.
hl.unbind("SUPER + SHIFT + D")
o.bind("SUPER + SHIFT + D", "Discord", { launch = "discord" })

-- WhatsApp replaces Omawrite on SUPER+SHIFT+W.
hl.unbind("SUPER + SHIFT + W")
hl.unbind("SUPER + SHIFT + ALT + G")
o.bind("SUPER + SHIFT + W", "WhatsApp", { webapp = "https://web.whatsapp.com/", focus = true })

-- ChatGPT replaces Calendar on SUPER+SHIFT+C; Calendar moves to ALT+C.
hl.unbind("SUPER + SHIFT + C")
hl.unbind("SUPER + SHIFT + A")
o.bind("SUPER + SHIFT + C", "ChatGPT", { webapp = "https://chatgpt.com" })
o.bind("SUPER + SHIFT + ALT + C", "Calendar", { webapp = "https://app.hey.com/calendar/weeks/" })

-- Grok replaces Signal on SUPER+SHIFT+G.
hl.unbind("SUPER + SHIFT + G")
hl.unbind("SUPER + SHIFT + ALT + A")
o.bind("SUPER + SHIFT + G", "Grok", { webapp = "https://grok.com" })

-- Removed apps: Music/Spotify (SUPER+SHIFT+M) and Google Photos
-- (SUPER+SHIFT+P). Music TUI (SUPER+SHIFT+ALT+M) is kept.
hl.unbind("SUPER + SHIFT + M")
hl.unbind("SUPER + SHIFT + P")

-- ═══════════════════════════════════════════════════════════════════
-- Terminal scratchpad (SUPER+`)
--   Toggled by ~/.local/bin/scratch-term; the window rule pins the
--   terminal to special workspace "scratchterm" as a floating window.
-- ═══════════════════════════════════════════════════════════════════

o.window("org.omarchy.scratchterm", { workspace = "special:scratchterm silent", float = true, center = true, size = { 1100, 600 } })
o.bind("SUPER + code:49", "Terminal scratchpad", "~/.local/bin/scratch-term")
