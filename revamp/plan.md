# Quickshell Revamp — Build Plan

This is the architecture/build plan for replacing Polybar, Rofi, and Dunst
with a Quickshell-based setup, while keeping **AwesomeWM** as the window
manager on **X11/Xorg**. It is the companion to `decisions.md` (the options
menu you fill in) — this document describes the *shape* of the system and
the order things get built in; `decisions.md` fills in the *specifics* of
each surface.

Once `decisions.md` is answered, this plan's file list and build order
don't change structurally, but the actual QML content of each file follows
whatever was picked (e.g. `QuickPanel.qml` becomes either the icon-row,
tile-grid, or list-layout depending on `decisions.md` Section 4).

See also: `findings.md` (baseline assessment of the current AwesomeWM setup
and fixes already applied) and `quickshell-research.md` (the research this
plan is built on, including live compatibility tests performed on
servalws).

---

## 1. Scope and guiding principles

- Window manager stays **AwesomeWM**, display server stays **X11/Xorg**.
  Nothing here changes the WM or migrates to Wayland.
- Quickshell replaces: **Polybar** (top bar), **Rofi** (launcher + all
  `rofi-*-menu.sh` control menus), and **Dunst** (notifications, once the
  new notification center is ready — see rollout order in Section 5).
- **Keyboard-first**: every menu gets vim-style navigation per
  `decisions.md` Section 1. Mouse interaction (click-to-open,
  click-to-toggle) is supported everywhere but never required.
- Everything is **optional and chosen**, not assumed — `decisions.md` is
  the actual spec once filled in; this plan describes the machinery that
  serves whatever is picked.
- Nothing gets removed from the working system (Polybar/Rofi/Dunst keep
  running) until its Quickshell replacement is built and proven — this
  mirrors the caution already written into the existing
  `quickshell/README.md` ("do not autostart Quickshell or replace
  Polybar/Rofi/Dunst until a component is proven manually").
- Consistent with `AGENTS.md`/`.hermes.md` repo rules: no file/config
  changes without explicit request, no git operations without explicit
  request, and nothing gets deleted without a prior cross-host symlink
  check. This plan is documentation and design only until implementation
  work is explicitly authorized step by step.

---

## 2. Architecture overview

```
~/.dotfiles/quickshell/.config/
├── shell.qml                 # thin entry point; loads the pieces below
├── Theme.qml                 # Singleton — live theme tokens (colors, font, radius, spacing)
├── theme_tokens.json         # source data Theme.qml watches (already exists, already wired to theme-apply)
├── AwesomeBridge.qml         # Singleton — tag/focus state + actions (decisions.md Section 2)
├── services/
│   ├── Notifications.qml     # wraps NotificationServer, exposes history + toasts
│   └── LockSettings.qml      # tiny singleton: which lock backend is active (i3lock vs qs lock)
├── bar/
│   └── Bar.qml               # PanelWindow per screen (Variants over Quickshell.screens)
├── panels/
│   ├── QuickPanel.qml        # FloatingWindow — decisions.md Section 4
│   ├── FullPanel.qml         # FloatingWindow or full-screen overlay — decisions.md Section 5
│   └── NotificationCenter.qml# FloatingWindow — decisions.md Section 9, opened by Mod+N
├── launcher/
│   ├── LauncherCenter.qml    # FloatingWindow, center-modal style — decisions.md Section 7 Style 1
│   └── LauncherSprout.qml    # FloatingWindow, bottom-sprout animation — decisions.md Section 7 Style 2
├── quickapps/
│   └── QuickApps.qml         # FloatingWindow — decisions.md Section 8, radial/hex/grid per decision
├── osd/
│   └── Osd.qml                # extends the existing volume-OSD prototype to brightness/mic
└── lockscreen/
    └── Lock.qml               # only built if decisions.md Section 10 chooses to build it now
```

Each top-level surface is its own file with its own `IpcHandler`
(`qs ipc call <target> toggle`), so AwesomeWM keybinds call into Quickshell
the same simple way regardless of which internal QML file handles it —
this is what makes the keybind migration in Section 5 incremental instead
of all-or-nothing.

---

## 3. Component inventory and build order

Ordered by dependency and risk, not by preference ranking — items later in
the list depend on earlier ones being solid:

1. **`Theme.qml` singleton** — everything else reads colors/fonts from
   here. Trivial, but must exist first so no surface hardcodes colors that
   later need hunting down.
2. **`AwesomeBridge.qml` singleton** — implements whichever option was
   chosen in `decisions.md` Section 2. The top bar's tag indicator, the
   Full Control Panel's WM section, and the launcher's window-switcher mode
   all depend on this existing and being reliable.
3. **OSD extension** (volume already works) — smallest surface, proves the
   `Theme.qml` + service-integration pattern end-to-end with minimal new
   surface area, per the "finish what's half-done first" logic from
   `quickshell-research.md`.
4. **Top Bar** — next smallest well-defined surface once the bridge
   exists; also the thing looked at 100% of the time, so getting it solid
   early matters. Built with `Variants { model: Quickshell.screens }` from
   day one (per the verified strut caveat in `quickshell-research.md`),
   one bar per monitor per whatever `decisions.md` Section 6 chooses.
5. **Quick Control Panel** — reuses Pipewire/Bluetooth/UPower/Networking
   services already proven live on this machine (verified in
   `quickshell-research.md`'s live test); no new integration risk, just UI.
6. **Notification Center + toast system** — this is the one step that
   requires an atomic cutover (Dunst off, Quickshell notification server
   on, at the same moment) — sequenced after the bar/quick-panel are stable
   so debugging notifications and a new bar don't happen simultaneously.
7. **Launcher** (both styles) — biggest net-new logic (app
   search/indexing, fuzzy matching), sequenced after the above so the
   "plumbing" (theme, bridge, services) is already trustworthy.
8. **Full Control Panel** — the biggest single surface (many sections),
   deliberately last among the "core" pieces since it's the least urgent
   (Quick Panel covers day-to-day needs) and benefits most from patterns
   already proven in bar/launcher.
9. **Quick Launch Menu** — independent of everything except the app-list
   logic already built for the Launcher in step 7 (can share code).
10. **Lock screen switcher** — lowest priority; `i3lock` already works
    fine today, this is a "nice consistency" item, build only once
    everything above is settled, per `decisions.md` Section 10.

---

## 4. Integration map (what talks to what)

- **Bar ↔ Quick Panel**: bar's status icons (volume/network/bt/battery)
  and the Quick Panel's tiles read the *same* service singletons
  (Pipewire/Bluetooth/UPower/Networking) — they will always agree with
  each other since neither owns the data, they just both display it.
- **Bar ↔ AwesomeBridge**: bar's tag indicator and window-title module are
  the bridge's primary consumers.
- **Quick Panel ↔ Full Panel**: Quick Panel tiles can each have an "expand
  to full detail" affordance that deep-links into the matching Full Panel
  section, rather than duplicating detailed UI in both places.
- **Full Panel ↔ LockSettings**: the WM/Awesome section's lock-screen
  toggle writes to `LockSettings.qml`'s singleton state, which the
  `xss-lock` wrapper script (`decisions.md` Section 10) reads on the next
  lock event.
- **Notification Center ↔ toasts**: both read from the same
  `Notifications.qml` history buffer — a toast is just "the newest entry,
  shown transiently," the center is "the whole buffer, browsable."
- **Launcher ↔ AwesomeBridge**: window-switcher mode inside the launcher
  queries the bridge for the live client list (same data the existing
  `awesome-dump-state.sh` script already extracts).
- **theme-apply ↔ Theme.qml**: `theme-apply` keeps writing
  `theme_tokens.json`; `Theme.qml`'s `FileView { watchChanges: true }`
  (already present in the existing prototype) picks up changes live with
  no Quickshell restart needed.

---

## 5. Rollout / cutover plan

1. Build steps 1-5 from Section 3 above (Theme, Bridge, OSD, Bar, Quick
   Panel) with Polybar/Rofi/Dunst **still running and still autostarted**
   — Quickshell surfaces are launched manually for testing only, no
   keybind changes yet, no autostart changes yet. This matches the
   existing `quickshell/README.md` caution.
2. Once the Bar is trusted, flip **one** thing: comment out Polybar's
   autostart line in `rc.lua`, uncomment/enable Quickshell's autostart.
   Keep the Polybar launch script and config in the repo (don't delete) in
   case of rollback.
3. Migrate keybinds **one at a time** per the table in `decisions.md`
   Section 12 — e.g. `Mod+Shift+A` moves from `rofi-audio-menu.sh` to
   `qs ipc call quickpanel focusAudio` only once the Quick Panel's audio
   tile is confirmed working, not before. Rofi itself doesn't need to be
   uninstalled; it just stops being called.
4. Notification cutover (Dunst → Quickshell) happens as one atomic step
   per Section 4's note above — stop Dunst's autostart line and start
   Quickshell's notification server in the same `rc.lua` edit, so there's
   no window where notifications silently vanish.
5. Full Panel, Quick Launch Menu, and Lock Screen switcher get their own
   keybinds added (not replacing anything) once built, per the
   free/resolved keys in `decisions.md` Section 12.
6. Only after everything above is confirmed working for a while: retire
   the now-unused Rofi `.rasi` theme files, the `rofi-*-menu.sh` scripts,
   and Polybar's config from active use (archive, don't delete outright,
   consistent with repo rules on deletions requiring explicit sign-off and
   a prior cross-host symlink check).

---

## 6. Relationship to `decisions.md`

This plan describes the *shape* of the system. `decisions.md` fills in the
*specifics* — which layout each panel uses, which keybinds go where, which
sections exist. Once `decisions.md` is answered, this plan's file list and
build order don't change structurally, but the actual QML content of each
file follows whatever was picked (e.g. `QuickPanel.qml` becomes either the
icon-row, tile-grid, or list-layout depending on `decisions.md` Section 4's
answer).

---

## 7. Known risks / open engineering questions (not choices, just honesty about difficulty)

- **AwesomeBridge latency** (`decisions.md` Section 2, option A vs B): if
  the simple shell-out approach is picked initially, the tag indicator may
  feel slightly less instant than Hyprland/i3 users are used to with
  Quickshell's native IPC modules. Upgradeable to the socket-based
  approach later without changing anything else.
- **Multi-monitor struts**: confirmed via live test
  (`quickshell-research.md` Section 1) that a bar's reserved space isn't
  automatically per-monitor — this is now a known, designed-around
  constraint (one `PanelWindow` per screen via `Variants`), not a
  surprise, but worth remembering if a third monitor is ever added.
- **Dunst/Quickshell notification handoff**: has to be atomic (Section 5,
  step 4 above) — the one place a half-migrated state is actually broken,
  not just incomplete.
- **`Quickshell.Networking` maturity**: confirmed real and working on the
  exact installed build (Quickshell 0.3.0, Fedora COPR
  `errornointernet/quickshell`) per the live test in
  `quickshell-research.md`, but it's a less-traveled module than
  Pipewire/Bluetooth/UPower (which are used by essentially every
  Quickshell config in the wild). Worth keeping an eye on stability as the
  Network tile gets built.

---

## 8. Status

**Build complete. Smoke-tests passed on 2026-07-06.**

All 13 components from Section 3 have been implemented in QML under
`quickshell/.config/quickshell/`. The full inventory:

| # | Component | File(s) | Smoke-test result |
|---|-----------|---------|-------------------|
| 1 | Theme singleton | `services/Theme.qml` | Loads, fileChanged→reload fix applied |
| 2 | BridgeState singleton | `services/BridgeState.qml` | Parses bridge JSON; poll timer+fileChanged reload fix applied |
| 3 | OSD | `modules/OSD/OSD.qml` | IPC tested, renders correctly, legacy script compatible |
| 4 | Bar | `modules/Bar/Bar.qml` + TagIndicator/FocusedTitle/ClockLabel | Renders; tags active(teal)/urgent(red) verified via bridge simulation |
| 5 | QuickPanel | `modules/QuickPanel/QuickPanel.qml` + QuickPanelTile | 2x2 tile grid renders centered |
| 6 | Notifications | `services/Notifications.qml` + Toast/NotificationCenter | **Inert** (not in qmldir) — avoids Dunst D-Bus conflict |
| 7 | Launcher | `modules/Launcher/Launcher.qml` | DesktopEntries spread-to-array fix applied; app list renders |
| 8 | FullPanel | `modules/FullPanel/FullPanel.qml` + FullPanelCard | All 11 sections render fullscreen |
| 9 | QuickApps | `modules/QuickApps/QuickApps.qml` + QuickAppsTile | Grid/radial/hex layouts all render; modelData fix applied |
| 10 | WindowSwitcher | `modules/Launcher/WindowSwitcher.qml` | Lists windows from bridge state; tag markers work |
| 11 | Lock screen | `modules/LockScreen/LockScreen.qml` + `lock.qml` | Fullscreen PanelWindow renders; PAM signal handlers fixed |
| 12 | Bridge Lua | `awesome-integration/bridge.lua` | Hand-built; emits per-client info; **not wired** to rc.lua |
| 13 | Switch script | `revamp/switch-to-quickshell.sh` | Exits non-zero; documents 7 atomic cutover steps |

### Critical bugfixes found and applied during smoke-testing

1. **`Window` → `PanelWindow`** (all 8 surfaces): plain `Window{}` nested
   under `ShellRoot` never maps to a real X11 window in Quickshell 0.3.0 on
   X11 (IPC returns `ok` but nothing renders). Replaced with `PanelWindow`
   throughout — centered popups use no anchors, fullscreen overlays use
   all-four-anchors.
2. **`DesktopEntries.applications.values` is not a JS Array**: it's a
   `QObjectList` that QML exposes as array-like but `Array.isArray()` returns
   `false` on it. Fixed with `[...raw]` spread instead of the `isArray` guard.
3. **`modelData` context property requires explicit declaration**: delegates
   that declare `required property int index` must also declare `required
   property var modelData` — QML stops injecting implicit context when any
   required property is declared (QuickApps 3× delegates).
4. **`FileView.watchChanges` does not auto-reload**: the `fileChanged` signal
   fires but the file content is NOT re-read unless `onFileChanged: reload()`
   is explicitly wired (applied to BridgeState.qml and Theme.qml).
5. **PAM signal naming**: `PamContext` signal is `pamMessage`, not `message`;
   handler is `onPamMessage`, not `onMessage`. Also `onCompleted`/
   `onError` used arrow-function form to avoid collision with
   `Component.onCompleted`.

### Not yet done (deferred to integration phase)

- Notification cutover (Dunst → Quickshell, must be atomic)
- AwesomeWM `rc.lua` bridge wiring (bridge.lua stow + require step)
- `keys.lua` keybind migration (all 7 Quickshell IPC calls)
- xss-lock wrapper script (reads lock-settings.json, dispatches i3lock or lock.qml)
- `Mod+Shift+Space` collision resolution (FullPanel vs QuickApps)
- PAM service name verification against Fedora 44
- Lock-backend persistence from FullPanel toggle to lock-settings.json

### Boundaries respected

No AwesomeWM config files were touched during the build or smoke test.
`bridge.lua` lives in the quickshell package (not the awesome package)
specifically to prevent accidental symlinking into `~/.config/awesome/`.
Polybar, Rofi, and Dunst continue to be the live system on `servalws`.

### Test environment

All runtime tests were conducted on Xvfb (`:99`, 1920x1080x24) — a headless
virtual X server invisible to the user's live `:0` session. The bridge state
was simulated by hand-writing a sample `awesome-bridge-state.json`. No
interactive PAM authentication was attempted during testing (the lock screen
verified load+render, not auth flow).
