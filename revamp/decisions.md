# Quickshell Revamp — Decisions

This document lists every surface being built and, for each one, a set of
concrete options with plain-English descriptions. Fill in the `→ CHOICE:`
line under each decision point. Anything left blank is treated as
"undecided — default to the simplest option and revisit later."

This is the companion to `plan.md` (the build plan/architecture). Once this
file is filled in, its answers get folded back into `plan.md` as the
finalized spec.

---

## 0. How to use this document

Each section describes one surface or cross-cutting concern. Options are
lettered. Write your pick next to `→ CHOICE:` (you can pick more than one
where noted, e.g. launcher explicitly wants two styles available).

---

## 1. System-wide: Keyboard Navigation Contract

You said keyboard is your main mode of control across all menus. Before
designing individual surfaces, we need one consistent scheme so every menu
behaves predictably. This is the single most important decision in this
doc — everything else inherits it.

**Proposed baseline contract** (applies everywhere unless a surface has a
good reason to diverge, noted explicitly):

| Key | Action | Applies to |
|---|---|---|
| `j` / `k` | move selection down/up | lists, tile grids, notification stack |
| `h` / `l` | move selection left/right, OR switch tab/section | grids (left/right item) and tabbed panels (prev/next tab) — **needs your call, see 1a** |
| `gg` / `G` | jump to first/last item | long lists (notification history, device lists) |
| `Enter` | activate/confirm selected item | everywhere |
| `Esc` | close current panel / cancel | everywhere |
| `/` | start filter/search within current list | everywhere a list can be filtered |
| `Space` | toggle (checkbox-like: wifi on/off, mute, DND) | toggle rows |
| `x` or `d` | dismiss/delete (a notification, a pinned app in edit mode) | notification center, quick-launch edit mode |
| `Ctrl+j` / `Ctrl+k` (or `Down`/`Up`) | move selection in text-input surfaces (launcher search box) where `j`/`k` would be typed as letters instead | launcher, any search-first surface |
| `1`-`9` | jump directly to Nth item (workspace, pinned app, tab) | top bar tags, quick-launch grid, full panel tabs |

**1a — `h`/`l` semantics conflict to resolve:** In a single flat list,
`h`/`l` doing nothing (or left/right in a grid) is fine. In a **tabbed
panel** (Full Control Panel with sidebar sections), `h`/`l` more naturally
means "previous/next tab," which collides with "left/right in a grid" if a
tab ever contains a grid. Options:

- A. `h`/`l` = tab switch always; grids use `j`/`k` only for vertical
  movement and wrap row-by-row (no horizontal grid nav).
- B. `h`/`l` = grid-aware (moves within grid if one is focused, falls back
  to tab-switch if a flat list is focused).
- C. Dedicated tab-switch keys (`Tab`/`Shift+Tab` or bracket keys `[`/`]`),
  leaving `h`/`l` free for grid navigation everywhere.

→ CHOICE: C

**1b — Launcher text-input exception:** Since the launcher's main input
field captures every keystroke (including `j`,`k`,`h`,`l` as literal search
characters), the baseline `j`/`k` can't apply there directly. Confirm: use
`Ctrl+j`/`Ctrl+k` (or plain arrow keys) for result-list navigation while
typing? This mirrors how `bjarneo`'s omni-menu and most fuzzy launchers
already handle this problem.

→ CHOICE: Agree. also, whereever j/k (or ctrl+j/ctrl+k) apply, ctrl+n(for next)/ctrl+p(for previous) should apply. Double keybinds for these movements, unless it cannot be done straight forward.

---

## 2. System-wide: AwesomeWM Integration Bridge

Every surface that needs to know about tags/workspaces or focused-window
info needs this. One decision, used everywhere.

- **A. Shell-out per query** — Quickshell calls `awesome-client '<lua>'` via
  `Process` each time it needs data (e.g., every keybind press or every N ms
  via `Timer`). Simple, reuses patterns already in your scripts
  (`awesome-dump-state.sh` etc.), but has per-call process-spawn latency
  (small, likely <50ms, but not instant/live).
- **B. Persistent bridge process** — one long-running helper (Lua companion
  loaded into AwesomeWM, or a small daemon) that pushes tag/focus-change
  *events* to Quickshell over a Unix socket (`Quickshell.Io.Socket`) the
  moment they happen, instead of Quickshell asking. Feels instant, matches
  how the built-in Hyprland/i3 IPC modules behave, but is real one-time
  engineering work (a signal handler in `signals.lua` that serializes state
  and writes to a socket).
- **C. Hybrid** — B for the top bar's tag indicator and focused-window
  title (things that should feel live), A for anything less frequent (e.g.,
  a "reload Awesome" button in the control panel).

→ CHOICE: B

---

## 3. System-wide: Theming Pipeline

- **A. Keep `theme-apply` as the single source, extend it** — it already
  writes `awesome/theme/colors.lua`, `polybar/colors.ini`,
  `rofi/colors.rasi`, and (after the earlier path fix)
  `quickshell/theme_tokens.json`. Once Polybar/Rofi are retired, trim the
  script down to just AwesomeWM colors + Quickshell tokens.
- **B. Move to a Quickshell-first singleton (`Theme.qml`)** — Quickshell
  reads `theme_tokens.json` live (it already does — confirmed in your
  prototype via `FileView { watchChanges: true }`), and `theme-apply`
  becomes just "regenerate `theme_tokens.json` + AwesomeWM's `colors.lua`,"
  dropping the Polybar/Rofi-specific output blocks once those tools are
  gone.
- **C. No change now** — decide this later, once the retirement of
  Polybar/Rofi actually happens.

→ CHOICE: B

---

## 4. Quick Control Panel (minimal, inspired by bjarneo's Quick-mode grid)

You referenced `bjarneo/quickshell`'s window-centered control panel but
want something **more minimal** — a fast glance/toggle surface, not the
full dashboard. This is the "check/flip something in 2 seconds" surface.

**Trigger options:**

- A. Dedicated new keybind (e.g. `Mod+A` — currently your audio-menu key,
  natural reuse point since this panel would absorb that menu's job).
- B. Click on a top-bar icon (mouse-based open, keyboard-based navigation
  once open).
- C. Both A and B simultaneously.

→ CHOICE: C

**Layout/content options:**

- A. **Icon-only toggle row** — a thin horizontal strip of icons
  (wifi/bluetooth/DND/mic-mute), each a pure on/off toggle, `Space` to
  flip, `h`/`l` to move between them. No sliders, no expandable detail.
  Closest to "minimal."
- B. **Compact tile grid (subset of bjarneo's 4x3)** — pick ~4-6 tiles only:
  volume, wifi, bluetooth, battery/power. Each tile shows current state
  (e.g. "Wi-Fi · KSM · 78%") and `Enter` expands it into a one-line detail
  (slider or short list), `Esc` collapses back. This is literally
  bjarneo's Quick mode, cut down to fewer tiles.
- C. **Single vertical list** — one row per item (volume with inline
  slider, wifi with inline status, bluetooth, battery), `j`/`k` to move,
  `Enter`/`Space` to act on the focused row. No grid at all, just a short
  list — probably the most "minimal quick menu" reading of your note.

→ CHOICE: B

**Position on screen:**

- A. Anchored under the top-right corner of the bar (where a
  systray/quick-toggle area usually lives).
- B. Small centered popup (like an OSD, but interactive).
- C. Anchored to whichever monitor currently has keyboard focus.

→ CHOICE: B+C. Small centererd popup anchored to whichver monitor currently has keyboard focus

---

## 5. Full Control Panel (Noctalia v4 + Caelestia pattern)

This is the "sit down and actually configure things" surface — the deep
version.

**Overall shape options:**

- A. **Sidebar + content pane (Noctalia v4 style)** — a persistent left (or
  right) list of sections (Home, Audio, Network, Bluetooth, Power, Display,
  Theme, Notifications, Awesome/WM), `h`/`l` or number keys switch
  sections, `j`/`k` navigate within the active section's content.
- B. **Card-based dashboard (Caelestia style)** — no sidebar; instead one
  scrollable/paged surface with self-contained "cards" (a media-player
  card, a sliders card, a calendar card, a quick-tiles card) all visible at
  once or paged through, more visual/glanceable, less strictly
  hierarchical.
- C. **Hybrid** — sidebar navigation (from A) but each section renders as a
  card-style layout (from B) rather than a plain list.

→ CHOICE: B

**Presentation options:**

- A. Full-screen overlay (dims/covers the whole screen while open, like
  Noctalia's control center typically does).
- B. Large floating panel, not full-screen (e.g. right 40% of screen, or a
  big centered card) — lets you still see what's behind it.
- C. Docked sidebar that pushes/overlaps from one screen edge, always the
  same size.

→ CHOICE: A

**Sections to include** (check off — this becomes the sidebar/card list):

- [x] Home/overview (at-a-glance: time, weather if desired, quick status of
  everything)
- [x] Audio (full device list, per-app volume mixer if you want that level
  of detail)
- [x] Network (Wi-Fi list, saved networks, connect/forget)
- [x] Bluetooth (device list, pairing flow)
- [x] Power (battery detail, power-profile switch, suspend/restart/poweroff
  — absorbs `rofi-power-menu.sh`)
- [x] Display/Brightness (brightness slider; monitor layout switch —
  absorbs `rofi-display-manager.sh`)
- [x] Theme picker (replaces `theme-select`/`Super+Ctrl+T`, once a real
  theme library exists or is abandoned per earlier findings)
- [x] Notifications (embedded history view, or just a shortcut button to
  open the dedicated `Mod+N` center — see Section 9)
- [x] AwesomeWM/Workspace controls (tag overview, and — per your note below
  — the i3lock/Quickshell-lock switch)
- [x] Keybind cheat-sheet (replaces `rofi-keybinds.sh`, now searchable
  instead of static)
- [x] Calendar (replaces `rofi-calendar.sh`)

→ CHOICE (which sections, and in what order): all sections. Follow noctalia and Caelestia for order - chose a reasonable one.

**Trigger keybind:** current audio/wifi/bluetooth/power keys
(`Mod+Shift+A/W/B`, `Mod+Escape`) could either (a) each jump straight into
the matching section of this one panel, or (b) stay as separate quick-panel
shortcuts (Section 4) with this full panel getting one single dedicated key
(e.g. `Mod+Shift+Space` — currently "next layout," would need to move that
elsewhere, or a fresh key like `Mod+C`).

→ CHOICE: B. mod+shift+space sounds good.

---

## 6. Top Bar

**Style reference note (flagging an ambiguity in your links):** the image
you linked (`Ax-Shell/.../1.png`) is from the **Ax-Shell** project
(Fabric-based, not Quickshell), while the repo link alongside it points to
**nucleus-shell** (formerly Aelyx Shell, Quickshell-based). These are two
different projects that happen to sit near each other on the
awesome_shells comparison page. I'm treating your intent as "I like *that
visual style* (shown in the Ax-Shell image) and want it *built in
Quickshell* (using nucleus-shell as a structural reference where useful)" —
flag if that's not what you meant.

**Bar visual style options (based on that reference image's minimal
aesthetic):**

- A. **Rounded pill/segment style** — modules grouped into small
  rounded-rectangle "capsules" with gaps between them (not one continuous
  bar strip), floating slightly off the screen edge. Closest to the
  minimal look in the reference image.
- B. **Flat full-width bar** — a direct structural replacement of your
  current Polybar layout (edge-to-edge, no gaps between modules), just
  re-themed/re-implemented in Quickshell. Lower visual risk, less "wow,"
  easy to reason about since it matches what you have today.
- C. **Compact icon-only bar** — same pill style as A, but numbers/text are
  hidden by default and only appear on hover or when a value changes (e.g.
  volume % flashes briefly after a scroll, then fades back to icon-only).
  Most minimal, but requires more animation/reveal logic.

→ CHOICE: I want to have both A and B as options. I should be able to choose between them from the control panel. I think noctalia does something similar

**Bar content modules (check off what you want, left-to-right order is
your call too):**

- [x] Workspace/tag indicator (rebuilt correctly this time — 5 labels, not
  10, via the AwesomeWM bridge from Section 2)
- [x] Focused window title
- [x] Clock
- [x] CPU %
- [x] Memory %
- [x] Volume icon (click → Quick Control Panel's audio tile)
- [x] Network icon
- [x] Bluetooth icon
- [x] Battery icon
- [x] Power-profile icon
- [x] System tray (background app icons)
- [ ] DND (do-not-disturb) toggle icon

→ CHOICE: All should be options in the control panel. Noctalia offers customization - I want similar customization capability

**Bar position:**

- A. Top (current).
- B. Bottom.

→ CHOICE: A

**Multi-monitor behavior** (directly informed by the live test I ran — a
bar's `exclusiveZone` reserves space on *both* monitors even if only one
`PanelWindow` exists, so this has to be an explicit choice, not an
accident):

- A. Bar on both monitors, identical content.
- B. Bar on primary monitor only (matches your current Polybar setup —
  right/external monitor only), other monitor gets zero top padding
  (matches AwesomeWM's current `padding_top` split).
- C. Bar on both monitors, but the secondary monitor gets a reduced module
  set (e.g. just clock + workspace indicator, no full status row).

→ CHOICE: B

---

## 7. Launcher

You want **both** styles available (not a single either/or):

**Style 1 — Center-screen modal** (classic centered box, closest to how
Rofi behaves today).
**Style 2 — Bottom-sprout** (Caelestia-style: launcher visually
grows/expands upward from the bottom screen edge on open, collapses back
down on close/launch).

**How the two coexist — trigger mapping options:**

- A. Two separate keybinds — e.g. `Mod+Space` stays center-modal (matches
  current muscle memory from `rofi -show drun`), a new key (e.g.
  `Mod+Shift+Space` — currently "next layout," would need relocating, or
  `Mod+Grave` collides with your scratchpad, so likely a genuinely new
  binding) opens the bottom-sprout version.
- B. One keybind, a setting in the (Full) Control Panel decides which style
  opens (simpler keybind surface, less immediate/discoverable).
- C. One keybind opens center-modal by default; a modifier on the same key
  (e.g. holding Shift while pressing it) opens bottom-sprout.

→ CHOICE: both should exist as customization option. I choose one from the control panel, not coexisting

**Content/features to include** (both styles share the same underlying
search/logic, just different presentation shells):

- [ ] App search (fuzzy match against `.desktop` files) — baseline,
  absorbs `rofi -show drun`
- [ ] Window switcher mode (absorbs `rofi -show window`) — as a mode you
  switch into within the same launcher, or a fully separate keybind
  (`Mod+Tab` stays as-is, could point at this instead of Rofi)
- [ ] Inline calculator (type `12*4`, get instant result)
- [ ] Command-palette/action prefix (bjarneo-style: type `>` or similar to
  run system actions — reload Awesome, open theme picker, toggle
  lock-screen mode, etc., instead of memorizing separate keybinds for each)

→ CHOICE: I'm not fully sure about which option to choose here. I want to search .desktop files, switch to open windows if there is one and inline calc. No need for command-pallet/action prefix

---

## 8. Quick Launch Menu (customizable, inspired by `bjarneo/omarchy-quickapps`)

A separate, dedicated "my favorite apps, one keypress away" surface —
distinct from the general launcher in Section 7 (that one searches
*everything*; this one is a small curated set you configure yourself).

**Layout options** (both variants exist in the reference project):

- A. **Radial layout** — pinned apps arranged in a circle around a center
  point; `h`/`l` or arrow keys rotate the selection around the ring,
  `Enter` launches.
- B. **Hex-grid layout** — pointy-top hexagonal tiles in a HUD-style
  arrangement (the `quickapps2` variant in the reference) — same idea,
  different visual language (more "tactical display" than "radial menu").
- C. **Simple flat grid** — a plain grid of icons (2-4 columns), most
  predictable to navigate with `hjkl`, least visually distinctive.

→ CHOICE: All options, especially ones in bjareneo/omarchy-quickapps. I choose the style from the control panel (should have a dedicated tab)

**Customization mechanism:**

- A. Plain config file (JSON/QML data file) you hand-edit to list which
  apps are pinned and in what order/position.
- B. An "edit mode" toggled from within the menu itself (e.g. press `e`)
  that lets you add/remove/reorder pinned apps live, no file editing
  needed.
- C. Both — file is the source of truth, edit mode is a convenience layer
  that writes back to the file.

→ CHOICE: A and control panel as mentioned above

**Navigation/trigger:**

- Direct number-key shortcuts (`1`-`9`) to instantly launch the Nth pinned
  app without moving a selection cursor at all, in addition to
  `hjkl`/arrow navigation for browsing.
- Trigger keybind: needs a free key — candidates: `Mod+Shift+Space` (if not
  already claimed by bottom-sprout launcher in Section 7) or a fresh
  binding.

→ CHOICE (trigger key): numbers, hjkl and tab/shift+tab for selection. trigger is mod+space (confirm it's not occupied)

---

## 9. Notification Center (Quickshell native, Dunst dropped)

**Toast/popup behavior** (transient notifications that appear briefly when
something happens, separate from the history you open with `Mod+N`):

- A. Top-right corner, matches Dunst's current position exactly
  (`origin = top-right`, `offset = (10, 40)` in your current `dunstrc`) —
  least disruptive to muscle memory.
- B. Top-center.
- C. Bottom-right.

→ CHOICE: A

**History/center behavior (`Mod+N`, vim-navigable):**

- `j`/`k` move between stacked notifications, `x`/`d` dismiss the focused
  one, `Enter` triggers its default action (if it has one, e.g. opening
  the app that sent it), `c` clears all, `Esc` closes the center.
- Grouping option: **A.** flat chronological list. **B.** grouped by
  sending app (like Android's notification shade), collapsible per group.

→ CHOICE: A

**Do-not-disturb control placement:**

- A. Quick Control Panel only (Section 4).
- B. Top bar icon only (Section 6).
- C. Both, same underlying toggle.

→ CHOICE: No need for DND

**Migration note (engineering, not a choice):** Dunst currently owns the
notification D-Bus name; it must be stopped (removed from `rc.lua`'s
autostart) at the same time Quickshell's `NotificationServer` starts owning
it, or notifications will silently go nowhere in between. This needs to
happen as one atomic step in the rollout, not gradually.

---

## 10. Lock Screen

You want the **option to switch** between your current `i3lock` and a
Quickshell-native lock screen, switchable from the control panel.

**Implementation approach options:**

- A. A setting (stored in a small config file or the same theme-tokens-style
  JSON) that a thin wrapper script reads: `xss-lock`'s trigger command
  changes from the current hardcoded `i3lock -c 1e1e2e` to something like
  `lock-wrapper.sh`, which checks the setting and launches either `i3lock`
  or `qs -c lockscreen` accordingly. The Control Panel's toggle just flips
  that setting.
- B. Two separate `xss-lock --transfer-sleep-lock -- <cmd>` configurations,
  and switching "restarts" the idle-lock hookup with the new command — more
  moving parts, not recommended over A.

→ CHOICE: B. I think it's cleaner - confirm

**Quickshell lock screen visual style** (if/when you actually build it —
can be deferred):

- Match the active theme tokens (background/accent colors) same as
  everything else, simple centered password field + clock, optionally your
  wallpaper blurred behind it.

→ CHOICE (build now vs. defer, since i3lock already works): build now as you described it

---

## 11. On-Screen Display (OSD)

Already agreed as "nice to have," and you already have a working volume
OSD prototype. Scope for this pass:

- [ ] Volume (already prototyped — needs the hardcoded pixel position
  `x=2700,y=112` replaced with a screen-relative anchor so it doesn't
  break on monitor layout changes)
- [ ] Brightness
- [ ] Microphone mute toggle
- [ ] Caps Lock toggle (optional, cosmetic)

→ CHOICE (which of the above, beyond volume): All except caps lock toggle

---

## 12. Proposed Keybind Map (for your confirmation/edits)

Cross-referencing against your **current** `keys.lua` to flag every
collision honestly:

| Key | Current binding | Proposed new binding | Collision? |
|---|---|---|---|
| `Mod+Space` | `rofi -show drun` | Launcher (Style 1, center) | No — direct replacement |
| `Mod+Tab` | `rofi -show window` | Launcher window-switcher mode | No — direct replacement |
| `Mod+Shift+A` | `rofi-audio-menu.sh` | Quick Control Panel, audio tile focused | No — direct replacement |
| `Mod+Shift+W` | `rofi-wifi-menu.sh` | Quick Control Panel, network tile focused | No — direct replacement |
| `Mod+Shift+B` | `rofi-bluetooth-menu.sh` | Quick Control Panel, bluetooth tile focused | No — direct replacement |
| `Mod+Escape` | `rofi-power-menu.sh` | Full Control Panel, Power section (or Quick Panel, your call) | No — direct replacement |
| `Mod+P` | `rofi-display-manager.sh` | Full Control Panel, Display section | No — direct replacement |
| `Mod+Ctrl+T` | `theme-select` (currently broken — no library on this host) | Full Control Panel, Theme section | No — direct replacement, also fixes the broken keybind |
| `Mod+S` | `rofi-keybinds.sh` (static cheat-sheet) | Full Control Panel, Keybinds section (searchable) | No — upgrade |
| **`Mod+N`** | *unused* | **Notification Center (new, per your note)** | **Free — no collision** |
| `Mod+Shift+Space` | "select next layout" | **Wanted for:** bottom-sprout launcher (7) or quick-launch menu (8) — **pick one, the other needs a different key** | **Real collision — your "next layout" binding would need to move (e.g. to `Mod+Shift+L` or stay accessible another way)** |
| `Mod+Grave` | scratchpad toggle | unchanged | No |

→ Resolve the `Mod+Shift+Space` three-way conflict (layout-cycle vs.
bottom-sprout launcher vs. quick-launch menu — at most two of these can
share sensible keys, the third needs a fresh binding): ok. This should be the definitive comment - comments above should be overridden by these: 1. mod+space=laucnher, 2. mod+tab=should be a floating menu as in the quick control panel that would show open apps and navigate to their window (should also include a search for open windows). 3. mod+shift+A=quick-control-panel 4. mod+shift+W/B/Escpe=no longer needed, replaced with quick-control-panel. 5. mod+p=same as quick-control-panel for available modes 6. drop theme keybind 7. create a quickshell menu for keybinds cheatsheet (are there good references?). 8. mod+n=for notifications. 9. mod+shift+space=quick-apps-menu 10. mod+grave=unchanged

---

## 13. Summary of open ambiguities needing your direct answer

Pulling these together so nothing gets missed:

1. Section 1a/1b — exact `h`/`l` and launcher-input navigation semantics.
2. Section 6 — confirm the Ax-Shell-image-vs-nucleus-shell-repo reference
   was intentional or a mix-up.
3. Section 12 — the three-way `Mod+Shift+Space` conflict.
4. Whether the Full Control Panel (Section 5) subsumes the individual
   quick-menu keybinds (`Mod+Shift+A/W/B` etc.) or those stay pointed at
   the Quick Control Panel (Section 4) instead — i.e., do the old menu keys
   become "quick panel shortcuts" or "deep-link into the full panel"?
