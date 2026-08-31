# GROK_QUICKSHELL_FIXES.md

Session report — 2026-08-25  
Workspace: `~/.dotfiles` (chezmoi source of truth under `home/`)  
Runtime: Quickshell 0.3.0 on AwesomeWM 4.3 / X11, Picom v13  
Primary output: `HDMI-0` at `x=1920` (1920×1080). Internal `eDP-1-1` at `x=0`.

This file records what was done in this session, why, what was verified, what failed, and what is still open. It does not replace `quickshell/docs/project-status.md` (that file is the older migration handoff; do not rewrite it to look current).

---

## 1. Session requests, in order

1. Full evaluation of the Quickshell desktop shell (services, top-bar windows, UI/UX).
2. Implement the ranked improvements, plus a centered Date–Time–Weather block.
3. Search official docs / user discussion; do not assume APIs.
4. Author in chezmoi source (`home/`). Remove Omarchy references from live source when done.
5. `chezmoi apply`, then explain how to inspect each change.
6. After Awesome restart, weather still on the right — diagnose and fix.
7. Safe Quickshell-only restart (authorized).
8. Should Awesome restart also restart Quickshell? If yes, wire it.
9. Analyze popout visual variance (“just pop”, split-second artifacts). Compare Omarchy animation on GitHub. Propose a more refined behavior.
10. Implement that popout change as a test.
11. Tailscale and notification menus cut from the top. Emulate/screenshot/diagnose.
12. Other panels show the same cut, inconsistently.
13. Fix it (first attempt failed after restart).
14. Think thoroughly, refer to docs, stop trial-and-error, implement a proven placement model.
15. Write this report.

Constraints in force the whole session (`AGENTS.md`):

- Source edits only when explicitly requested.
- No Git. No Syncthing.
- `chezmoi apply` and process restarts are separate authorizations from source edits.
- Quickshell under `home/dot_config/quickshell/` is **copies**, not `symlink_`. Editing the repo is not live until apply + Quickshell restart.
- Do not implement external HDMI brightness (no `ddcutil`, i2c 600 root, NVIDIA HDMI).
- Do not add a notification desktop-entry launch fallback unless asked.
- Do not rewrite historical `quickshell/docs/` Omarchy mentions; only live source was cleaned.

---

## 2. Environment and architecture (baseline)

### 2.1 Desktop

- AwesomeWM is the X11 window manager. Quickshell is the resident shell (bar, popouts, OSD, launcher, lock, toasts).
- Picom has a zero-duration rule for Quickshell windows (accepted earlier; shell-window motion is better).
- Native authorities: PipeWire, NetworkManager, BlueZ, MPRIS, NotificationServer, UPower. Power profiles via TuneD (`power-profiles-daemon` inactive).
- Mutations go through `CommandTransport`, gated by `QUICKSHELL_ENABLE_MUTATIONS=1` unless a `safe-mode` marker is present.
- `BarPopoutController` is a one-at-a-time umbrella over bar popouts (`umbrellaSurface = "bar-popout"`).

### 2.2 Chezmoi

- Source: `home/dot_config/quickshell/…`
- Live: `~/.config/quickshell/…` (copies).
- Awesome Lua is also copies unless noted.
- `chezmoi apply` is a live deploy on this host only.

### 2.3 Dual-output bar

- Bar is reserved on the primary output (`HDMI-0`), 26px, `exclusiveZone` = bar height.
- Weather was moved into the center cluster with the clock (Date–Time–Weather). Right cluster: Tailscale, notifications, media, tray, system controls.

---

## 3. Evaluation findings (pre-implementation)

The evaluation covered services, bar windows, and UI. Ranked issues that were then implemented (not merely discussed):

| Area | Problem | Direction taken |
|---|---|---|
| Audio | Coalesce / capture tracking gaps | Coalesce pending percent; track capture streams; microphone-in-use indicator |
| Brightness | Shared transport / relative steps | Own transport; absolute percent; laptop-without-HDMI display helper coverage |
| Network | Scan left pending | Scan gated to panel-open / explicit refresh |
| Bluetooth | Discovery pending flag | Discovery not left pending |
| Display | Hardcoded helper path | `$HOME/.config/scripts/…` |
| Power | Mixed backends | Native UPower + TuneD pills (Saver / Balanced / Performance) |
| Notifications | Last-good snapshot; `expire_timeout` 0 | Last-good retained; Freedesktop 0 = never expire (ms on the wire) |
| Toasts | Map/unmap from model count; expiry marked seen | Suppress while bar popout open; fixed stack height; timeout hide without acknowledging history |
| OSD / keys | XF86 keys | OSD IPC + Awesome XF86 bindings |
| Weather placement | Weather on the right | Clock + Weather in a centered cluster |
| Omarchy naming | Types / comments in live source | Removed from live QML; historical docs left alone |
| External HDMI brightness | Cannot be 100% | Explicitly not implemented |
| Notification click | Sender open only if live `"default"` action | No desktop-entry fallback added |

Native checks used where cheap: `zsh -n` / `bash -n` not applicable to QML; display helper fixture 11/11; Lua controller test under `luajit` (system `lua` not installed). A `kill\0-TERM\01234` octal-vs-newline bug in the controller test was fixed to `"kill\0-TERM\0" .. "1234"`.

---

## 4. Service and bar improvements (first authorized batch)

Authored in `home/dot_config/quickshell/` and related Awesome/display helpers. Then applied with explicit authorization (Quickshell / Awesome / display only — not zsh/tmux/run-after).

### 4.1 Services (representative)

- `AudioService.qml` — coalesce; capture stream tracking.
- `BrightnessService.qml` — own transport; absolute `%`; fixture coalescing via `pendingPercent` / `callLater` so two Rights become one `set 50%`.
- `NetworkService.qml` — scan gated.
- `BluetoothService.qml` — discovery not pending.
- `DisplayService.qml` + display helper — `$HOME/.config/scripts/…`; laptop-without-HDMI needed extra fake `xrandr` argv; tests 11/11.
- `PowerService.qml` — UPower + TuneD.
- `NotificationService.qml` — last-good + expireTimeout 0.
- `NotificationToasts.qml` — suppress when `barPopoutController.activePopout !== ""`; fixed stack height.
- `WindowFocusRetry.qml` — bounded X11 activate retry; bar popouts must not self-close on failure.

### 4.2 Centered Date–Time–Weather

`PrimaryBar.qml` center cluster:

- `Clock` (calendar request)
- `WeatherWidget` immediately after

Weather removed from the right row. `placement: "center"` on the weather popup (later inherited by the shared host as `placement: "center"`).

### 4.3 Omarchy references

Removed from live Quickshell source (types, comments, control content). Historical `quickshell/docs/` mentions were **not** rewritten.

### 4.4 Apply vs live mismatch (weather still on the right)

User restarted AwesomeWM and still saw weather on the right.

Cause: live `PrimaryBar` already had center weather after apply, but the running Quickshell PID predated apply. `ensure_started` leaves a healthy instance alone, so Awesome reload did **not** replace the daemon.

Authorized fix: kill that PID, start a new process with the same env. New PID answered `shell.ping` = `ok` and owned D-Bus after ~1s.

This is the same class of bug as “Awesome restart should restart Quickshell.”

---

## 5. Awesome reload now restarts Quickshell

User mental model: Awesome restart = desktop reload. Quickshell is a daemon; `ensure_started` was insufficient.

### 5.1 Wiring

`home/dot_config/awesome/lib/quickshell_control.lua`:

- `restart_selected()` — inspect selected instance PID; `kill -TERM`; if still present, `kill -KILL`; then `start_selected_config`.
- `rc.lua` calls `quickshell_controller:restart_selected()` on load.

`ensure_started` still exists for “not running” recovery; reload uses `restart_selected`.

Lua octal trap: `"kill\0-TERM\01234"` is `TERM` + newline + `34` because `\012` is octal LF. Concatenate: `"kill\0-TERM\0" .. "1234"`.

### 5.2 Status

This wiring is in source and was applied in the earlier apply/restart cycle. It is independent of the later popout overlay work.

---

## 6. Popout visual analysis (before the test change)

### 6.1 What the user saw

Popouts did not behave the same. They “just popped.” Split-second artifacts on open/switch: map/unmap flash, tooltip overlap, restack, max-height host before mask.

### 6.2 Then-current model

Each bar widget owned a `Ui.PopupCard` that **was itself a `PanelWindow`**:

- `anchors.top: true`, `anchors.right` for right-side popouts
- `margins.top: barHeight + 8` (or `panelGap` for weather)
- `visible: open \|\| cardOpacity > 0`
- 140ms opacity, `Easing.OutCubic`
- `lockSizeWhileOpen` kept the X11 window at max height while open
- `BarPopoutController.activate()` on sibling switch set `dismissImmediately`, cleared `activePopout`, emitted `closeRequested(previous)` — **instant unmap** of the old window, then map of the new one

Weather/calendar: `placement: "center"` (no right anchor). Others: right edge of the output, not under the triggering icon.

Tooltips (`PopupToolTip` / `StatusText`) were not gated on “any bar popout open.”

### 6.3 Omarchy (GitHub, quattro)

`shell/Ui/KeyboardPanel.qml` + `shell/Ui/PopupCard.qml`:

- One overlay
- Card anchored to the triggering icon
- 140ms OutCubic
- Keep the overlay mapped on sibling switch (`popoutSwitching`)
- Skip outgoing fade on switch

### 6.4 Proposed test (user: “ok. Now let’s make this change for a test.”)

- One bar-popout `PanelWindow` that stays mapped across sibling switches
- Card under the triggering icon; weather and calendar stay center
- Keep 140ms OutCubic; add ~6–8px Y slide
- Hide status tooltips while a bar popout is active
- Focus-loss unmap stays instant

---

## 7. Shared popout host — implementation (test)

Source-only at first; user later applied and restarted (that live process is what we screenshotted).

### 7.1 New / reworked pieces

| File | Role |
|---|---|
| `home/dot_config/quickshell/ui/BarPopoutHost.qml` | **New.** One overlay `PanelWindow` for all bar popouts |
| `home/dot_config/quickshell/ui/PopupCard.qml` | **Reworked.** Inner card `Item`, not a `PanelWindow` |
| `home/dot_config/quickshell/ui/qmldir` | Export `BarPopoutHost` |
| `home/dot_config/quickshell/services/BarPopoutController.qml` | `switching` flag; do not unmap overlay on sibling activate; `release()` is a no-op while switching |
| `home/dot_config/quickshell/style/Metrics.qml` | `popupSlidePx: 8` |
| `home/dot_config/quickshell/modules/bar/PrimaryBar.qml` | Instantiates host; passes `popoutHost` to widgets |
| `home/dot_config/quickshell/shell.qml` | `calendarPanel.popoutHost: primaryBar.popoutHost` |
| Weather, media, notifications, Tailscale, tray, tray items, system controls, calendar | Stop owning windows; content stays in `PopupCard`; focus retry centralized on the host |
| `PopupToolTip.qml`, `StatusText.qml` | Hide while `barPopoutController.activePopout !== ""` |

### 7.2 Controller contract after the test

`activate(next)` when another popout is already open:

1. `switching = true`
2. `closeRequested(previous)` — previous card `open = false` (snap, no fade)
3. `switching = false`
4. `activePopout = next` — host stays mapped
5. `modalController.activate("bar-popout")`

`closeActive(true)` (focus loss): `dismissImmediately = true`, clear `activePopout`, unmap immediately.

`release(popout)` returns false while `switching`, so widgets’ `onOpenChanged` cannot drop the umbrella during a sibling swap.

### 7.3 Intended card motion

- Opacity 140ms OutCubic
- `Translate { y: slideY }` with `slideY` 8→0 on open
- Placement `"center"` for weather and calendar
- Placement `"anchor"` otherwise: horizontal center on the trigger, clamped to `edgeInset`

### 7.4 First overlay geometry (the mistake)

The first `BarPopoutHost` used:

```qml
anchors { top: true; left: true; right: true; bottom: true }
exclusionMode: ExclusionMode.Ignore
exclusiveZone: 0
```

Quickshell `PanelWindow` docs: **when two opposite anchors are set, that dimension is forced to the screen size.** Four-edge anchors ⇒ fullscreen overlay whose origin is the top of the output, **including the 26px bar**.

Old per-widget popouts never did this. They used `anchors.top` (and maybe `right`), plus `margins.top: barHeight + 8`, so the **window** started below the bar. That is the documented way to disconnect a panel from a monitor edge: *“Margins can be used to create anchored windows that are also disconnected from the monitor sides. Only applies to edges with anchors.”*

Cards were also JS-reparented (`parent = host.cardLayer`) from the bar widget into the overlay. Qt visual-parent change keeps scene position by writing `x`/`y`, which destroys declarative `x`/`y` bindings. Combined with a fullscreen overlay at `y=0`, preserved Y is the bar’s Y (~0). The bar dock is stacked above the overlay, so the top ~26px of the card is covered.

---

## 8. “Cut from the top” — diagnosis with live screenshots

Authorized live inspection: IPC open of notifications and Tailscale, `xwininfo`/`xprop`, `maim` of `:0`. Panels were closed afterward.

### 8.1 X11 geometry (HDMI-0)

| Window | Geometry |
|---|---|
| `quickshell-shell` (bar) | 1920×**26** at `+1920+0` |
| `quickshell-bar-popout` (overlay) | 1920×**1080** at `+1920+0` |
| Intended card top (first design) | layout `y = 26 + 8 = 34` |
| Actual card top | `y ≈ 0` (under the bar) |

Both windows `_NET_WM_WINDOW_TYPE_DOCK`. Overlay mapped fullscreen over the same origin as the bar.

### 8.2 Pixel rows (right 430px of HDMI-0)

- Rows 0–25: bar
- Rows 26–27: bar bottom edge (~71,82,88)
- Rows 28+: card body
- Bar icons (bell, tray, bluetooth, volume) drawn **on top of** card chrome

Crops: `/tmp/qs-popout-diag/notifications-card.png`, `tailscale-card.png` (and full desktop PNGs). Headers (`Notifications` / `Tailscale` hero) only become readable below the bar. That is occlusion by the 26px bar, not missing QML content.

### 8.3 Inconsistency

User: other panels show the same cut, only inconsistently.

Same overlay, same reparent. Frozen Y depends on scene Y at the moment that widget first changed visual parent:

- Reparent while still at `y = 0` (not laid out / still invisible) → header under the bar
- Reparent after a `y = 34` binding had applied → looks fine
- Later opens of that widget do not reparent again → that widget keeps whichever Y it froze

Not a different layout per menu. Weather/calendar/media/controls are on the same host.

---

## 9. Failed fix (do not repeat)

After the screenshot diagnosis, a patch **only** restored `x`/`y` with `Qt.binding()` after JS reparent and moved the 8px slide onto `Translate`.

Why it was the wrong fix:

1. It assumed the overlay origin was correct and only bindings were broken.
2. The overlay was still a four-edge fullscreen window at screen `y=0`. Even a perfect `y=34` is a card coordinate inside a window that includes the bar; stacking and reparent races remain.
3. `Qt.binding()` after `parent = …` is not the documented Qt rule. The documented rule is: after a visual-parent change, **assign `x` and `y`**. Parent-change can write `x`/`y` after `onParentChanged`, so restored bindings can lose.
4. User restarted; the cut remained. This was slop: a speculative binding patch on top of a wrong window.

That approach was discarded.

---

## 10. Placement fix that matches the docs (current source)

Two documented facts, used together:

**Quickshell PanelWindow** (`https://quickshell.org/docs/v0.2.1/types/Quickshell/PanelWindow/`):

- Opposite anchors force that dimension to the screen.
- `margins` offset from **anchored** edges; they exist specifically to disconnect a panel from a monitor side.
- Setting `exclusiveZone` forces `ExclusionMode.Normal`. Ignore mode: *“You cannot set an exclusion zone in this mode.”*

**This repo’s already-working popouts** (pre-overlay): `anchors.top` (+ `right` for right-side), `margins.top: barHeight + 8`, implicit size = card. Window origin already below the bar. No per-card `y = barHeight`.

**Qt Item**: `x`/`y` are relative to the visual parent. After changing `parent`, set `x` and `y` against the new parent. Prefer never parenting the card to the 26px bar.

### 10.1 `BarPopoutHost.qml` now

```qml
anchors { top: true; left: true; right: true }  // not bottom
margins.top: barHeight + edgeInset             // 26+8 = 34
exclusionMode: ExclusionMode.Ignore            // do not set exclusiveZone
implicitHeight: targetScreen.height - topGap   // remainder of the output
mask: Region { item: active card background }
```

Expected live geometry after apply + Quickshell restart: **1920×1046 at `y=34`**, not 1920×1080 at `y=0`.

### 10.2 `PopupCard.qml` now

- Visual parent binding: `parent: host && host.cardLayer ? host.cardLayer : null` (not JS `parent =` from the bar).
- Layout `y = 0` always — the window, not the item, is below the bar.
- `x` assigned in `applyPosition()` after parent is the card layer (horizontal: center / right / under trigger via `mapToGlobal` / `mapFromGlobal`).
- Open motion: opacity + `Translate { y: slideY }` (8px). Translate does not change layout Y.
- `applyPosition()` on host/parent/open/width; `Qt.callLater(applyPosition)` on open in case parent application is deferred one frame.

### 10.3 What this does **not** change

- One overlay, sibling switch keeps it mapped.
- Weather/calendar still `"center"`.
- Tooltips still blocked while a popout is open.
- Focus-loss still instant unmap.
- Widget contents (notification list, Tailscale peers, etc.) were not redesigned.

---

## 11. File inventory (this session)

### 11.1 Popout overlay (latest source)

- `home/dot_config/quickshell/ui/BarPopoutHost.qml` (new)
- `home/dot_config/quickshell/ui/PopupCard.qml` (rewritten twice; current is §10)
- `home/dot_config/quickshell/ui/qmldir`
- `home/dot_config/quickshell/ui/PopupToolTip.qml`
- `home/dot_config/quickshell/services/BarPopoutController.qml`
- `home/dot_config/quickshell/style/Metrics.qml`
- `home/dot_config/quickshell/shell.qml`
- `home/dot_config/quickshell/modules/bar/PrimaryBar.qml`
- `home/dot_config/quickshell/modules/bar/WeatherWidget.qml`
- `home/dot_config/quickshell/modules/bar/MediaWidget.qml`
- `home/dot_config/quickshell/modules/bar/NotificationWidget.qml`
- `home/dot_config/quickshell/modules/bar/TailscaleWidget.qml`
- `home/dot_config/quickshell/modules/bar/SystemTray.qml`
- `home/dot_config/quickshell/modules/bar/TrayItem.qml`
- `home/dot_config/quickshell/modules/controls/SystemControls.qml`
- `home/dot_config/quickshell/modules/controls/StatusText.qml`
- `home/dot_config/quickshell/modules/calendar/CalendarPanel.qml`

### 11.2 Awesome restart wiring

- `home/dot_config/awesome/lib/quickshell_control.lua` (`restart_selected`)
- `home/dot_config/awesome/rc.lua` (call on load)

### 11.3 Earlier improvement batch (services / bar / toasts / OSD)

Representative, not exhaustive: `AudioService`, `BrightnessService`, `NetworkService`, `BluetoothService`, `DisplayService`, `PowerService`, `NotificationService`, `NotificationToasts`, `WindowFocusRetry`, `PrimaryBar` center weather, control content Omarchy-type removal, display helper, OSD XF86 IPC, `keys.lua` XF86 bindings.

### 11.4 This report

- `GROK_QUICKSHELL_FIXES.md` (this file, repo root, requested by name)

---

## 12. Verification log

| Check | Result |
|---|---|
| Display helper fixture | 11/11 |
| Brightness coalesce fixture | Two Rights → one `set 50%` |
| `luajit` controller argv | Pass after octal fix |
| `chezmoi apply` (authorized, earlier) | QS/Awesome/display; not zsh/tmux/run-after |
| Weather still right after Awesome restart | Stale QS PID; `ensure_started` left it; killed and replaced |
| `restart_selected` on Awesome load | Wired in source and applied |
| IPC `notifications.openPanel` / `tailscale.openPanel` | Opened; screenshots taken; closed |
| Overlay geometry at screenshot time | 1920×1080+1920+0 (four-edge host — the bug) |
| Header cut | Confirmed visually and by row luminance |
| `Qt.binding` restore after user restart | **Failed** — cut remained |
| `margins.top` + three-edge host | **In source.** Not screenshot-verified after a later apply/restart in this session |
| QML brace balance on edited popout files | Balanced |
| Git / Syncthing / other hosts | Not touched |

Native QML “compile” is `quickshell` actually running the config. There is no `qs --check`. Visual acceptance belongs to the user.

---

## 13. How to inspect the current source on this host

Separate steps (user-owned):

1. `chezmoi diff` on Quickshell paths — confirm `BarPopoutHost` has **no** `anchors.bottom`, has `margins.top`, and does **not** set `exclusiveZone`.
2. `chezmoi apply` for Quickshell (explicit).
3. Quickshell restart (Awesome reload now does this if `restart_selected` is live; otherwise a QS-only restart).
4. `xwininfo -root -tree | grep quickshell-bar-popout` **while a popout is open**. Expect width 1920, height **1046**, absolute Y **34** on HDMI-0 — not 1080 at Y 0.
5. Open Tailscale, notifications, weather, volume: headers fully below the bar; first open and sibling switch; click-away instant close; no tooltip while open.

IPC (if used): `qs ipc call notifications openPanel`, `qs ipc call tailscale openPanel`, `qs ipc call weather openPanel`, `qs ipc call controls openAudio`. Close with the matching `closePanel` / `close`.

---

## 14. Open items and residual risk

1. **The §10 placement fix is not live-verified in this session.** The screenshots were of the four-edge overlay. After `margins.top`, confirm geometry with `xwininfo` before calling it done.
2. **Horizontal `mapToGlobal` / `mapFromGlobal` across two X11 `PanelWindow`s** is Qt 6 API and is used only for X. If it is wrong on this compositor, cards still appear but may not sit under the icon (fallback is right-edge or center).
3. **First map of the overlay** can still flash once (Picom + dock map). Sibling switch should not remap. That was the original test goal.
4. **Mask vs `Translate`**: during the 140ms slide the mask tracks `cardBackground`. If Quickshell `Region` ignores the parent transform, hit-testing is 8px off for that duration only.
5. **External HDMI brightness** — not implemented; hardware/tooling gap.
6. **Notification click → sender** — only live `"default"` action; no desktop-entry fallback.
7. **Flameshot / portal** — recorded in `project-status.md` as a separate residual; not part of this session’s edits.
8. **Historical `quickshell/docs/` Omarchy wording** — left as historical.
9. **zotac-box / other hosts** — not inspected; user owns propagation.

---

## 15. Lessons (for later work on this shell)

- On this setup, **window** placement is `PanelWindow` anchors + margins. Do not emulate a gap by putting `y = barHeight` inside a fullscreen overlay.
- Do not set `anchors.bottom` together with `anchors.top` unless a true fullscreen layer is intended. Quickshell will force screen height.
- Do not set `exclusiveZone` on a window that must `ExclusionMode.Ignore`.
- Do not JS-reparent items out of the 26px bar and then fight Qt’s scene-position write with `Qt.binding()`. Either declarative `parent: host.cardLayer` from the start, or assign `x`/`y` after the parent change.
- Awesome reload ≠ Quickshell reload unless `restart_selected` runs. `ensure_started` will keep a stale healthy PID.
- Live `~/.config/quickshell` is copies. Source edits are invisible until apply + process replace.
- One failed visual patch is a signal to re-read PanelWindow docs and `xwininfo`, not to add another binding helper.

---

## 16. Current intended popout behavior (spec)

When the §10 source is running:

- One overlay window per output, titled `quickshell-bar-popout`.
- Window top edge = bar bottom + 8px.
- One card visible at a time; sibling switch does not unmap the overlay.
- Open: 140ms OutCubic fade + 8px Y translate.
- Close on focus loss: immediate unmap.
- Weather + calendar: horizontally centered on the output.
- Other popouts: horizontally centered on the trigger, clamped to 8px inset.
- Status/tray tooltips: suppressed while any bar popout is active.
- Toasts: already suppressed while a bar popout is active (earlier batch).
