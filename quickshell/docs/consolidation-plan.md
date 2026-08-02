# Quickshell desktop consolidation plan

Updated: 2026-07-29

> Historical chronological implementation record. Statements below describe the
> boundary at the time each batch landed and may intentionally mention temporary
> fallbacks that have since been retired. Current operational truth is in
> `project-status.md`; migration completion and residual acceptance boundaries
> are in `quickshell-only-awesomewm-migration.md`.

## Goal

Make Quickshell the single Omarchy-styled owner of the desktop's
shell surfaces while AwesomeWM remains responsible for X11 window management.
Replace the user-facing roles historically served by Polybar, Rofi, Dunst, and
the temporary Awesome Pillbar/Naughty layer without losing working behavior.

## Implementation status

- Batch 0A: repaired Rofi switcher fallback implemented and syntax-checked.
- Batch 0B: Quickshell window switcher implemented and accepted live on X11.
- Batch 0C: persistent, mathematically centered `ddd dd MMM - HH:mm` clock
  implemented and accepted live.
- Batch 1: global modal coordination is live for the controls, switcher, launcher,
  and session menu. The bar-local popout layer described below is still pending.
- Batch 2: application launcher, ranked search, terminal-entry handling, IPC, and
  Awesome callback implemented and accepted live.
- Batch 3: Mod+Escape session menu implemented and accepted live with two-step
  confirmation. No destructive session action was executed during acceptance.
- Batch 4: centered-clock calendar, pure date model, bar-popout ownership, IPC,
  and Awesome boundaries are implemented in source. Model checks, isolated X11
  focus/rendering, live QML reload, and popout handoff passed; the prepared
  Awesome rule and focused live keyboard/visual acceptance require a normal
  separately authorized Awesome reload.
- Batch 5: searchable keybind help, authoritative Awesome hotkey metadata bridge,
  IPC, Mod+S callback, and Rofi failure fallback are implemented in source.
  Bridge tests, live QML composition, 44-binding normalization, isolated focus,
  filtering, selection, and 1280px rendering passed; activation and live keyboard
  acceptance require the same separately authorized normal Awesome reload.
- The X11 modal focus recursion defect is fixed. Opening and closing the accepted
  modals no longer generates a notification flood.
- Batches 6–12: display/workspace authority, tray, native device panels, and
  MPRIS media control are implemented; their accepted and unexercised live
  boundaries are recorded below.
- Batch 13: Quickshell owns `org.freedesktop.Notifications`; bounded DND/history,
  replacement, action, expiry, persistence, and toast behavior passed isolated
  and live acceptance. Dunst is masked and inactive. A later Flameshot failure
  storm exposed pending Batch 13A hardening for acknowledgement semantics and
  burst-window geometry; ownership itself remains healthy.
- Batch 14: the reduced Tailscale indicator/panel, bounded status model, X11
  clipboard route, and gated exact-argv actions pass isolated and live read-only
  acceptance without changing network state.
- Batch 15: explicit-location weather, current conditions, five-day forecast,
  last-good persistence, malformed/offline staleness, location changes, popup
  ownership, and 1280/1920 capacity pass private fixtures. Production is live
  accepted for Hamad Town, Bahrain, with verified versioned host-local state.
- Final retirement: Awesome starts no longer load Pillbar or Naughty D-Bus
  ownership, no active route launches the retired stack, and all retired source
  is held only in explicit top-level `*-archived` reference directories. The
  normal Awesome reload plus selected-config Quickshell activation are accepted.
- Authoritative output placement remains `eDP-1-1` left/secondary and `HDMI-0`
  right/primary.

## Architecture

### One resident shell with two explicit ownership layers

Keep `ModalController` as the shell-wide owner for the launcher, window switcher,
session menu, keybind help, display manager, and one umbrella `bar-popout`
surface. Add a narrow bar-local owner for the controls, calendar, tray menus,
media popup, notification history, Tailscale, and weather.

The bar-local contract is:

- one logical popout at a time;
- clicking the active icon toggles it closed;
- clicking a sibling performs a one-click handoff without overlapping fade-outs;
- logical close releases keyboard focus immediately, even if a fade remains;
- opening a global modal closes the active bar popout and vice versa;
- Escape closes the innermost editor/confirmation before its parent surface;
- toasts, OSDs, and tooltips remain passive and outside both ownership layers.

The five device-control icons continue to share one popup. Do not create a
focusable X11 window per icon. Initial calendar acceptance does not require a
fullscreen click-away overlay; close it with Escape, a second clock click,
sibling/global activation, IPC, bar hide, or authoritative-output loss.

All new surfaces reuse `Palette.qml`, `Metrics.qml`, `PopupCard.qml`,
`PanelHero.qml`, `PanelSectionHeader.qml`, `OmarchyButton.qml`, and
`KeyboardNavigator.qml`. New style tokens are added only when an existing token
cannot express a verified visual need. Before tray and notifications, add only
the missing semantic roles actually consumed by those surfaces: popout,
tooltip, notification, keyboard cursor, selected/current, pressed, urgent/error,
icon slot, notification width, screen gap, and popout-switch timing. Borders
must not change geometry between interaction states.

### State from Awesome, actions through explicit services

Extend the existing bridge for read-only client/output/tag state. Keep action
programs static and validated; do not construct arbitrary shell commands from
window titles, application names, SSIDs, or notification text.

Split the current coarse action gate into three policies:

1. **Desktop-session actions:** focus/raise/unminimize a client, switch a tag,
   launch an application, and copy text. These are required for normal shell UI.
2. **Device actions:** audio, network, Bluetooth, display, brightness, and power
   profile mutations. Keep these explicitly gated until each backend is accepted.
3. **Destructive session actions:** logout, suspend, reboot, and poweroff. Require
   an explicit confirmation interaction and never execute on menu highlight.

`CommandTransport.qml` remains the required boundary for CLI-backed actions. New
reads use request generations so stale results cannot overwrite newer state.
Mutations remain pending until a fresh read verifies the result, and malformed
reads preserve the last known good state.

### One authority and bounded service lifecycle per domain

Do not assume that upstream's native Quickshell service is automatically better
than the accepted local adapter. Before completing audio, network, and Bluetooth,
compare the installed Quickshell 0.3.0 APIs with the current service on this host
and choose one authoritative owner per state domain. Do not keep two independent
pollers or mutation paths for the same device state.

Split services into:

- **resident summary state** required for bar status;
- **open-only detail state** such as PipeWire node/application lists, Wi-Fi scans
  and credentials, Bluetooth discovery/device lists, and power-profile detail.

Keep the bar, Awesome bridge, command transport, tray, and notification server
resident. Load only expensive detail UIs on demand, cancel open-only scans when
their panel closes, and clear ownership if a loader/open operation fails. Do not
retrofit working small modals merely for architectural symmetry.

### Narrow persistence policy

Persist only genuine user state: DND/history, explicit weather location, and
optional tray pin/hide preferences. Runtime files are versioned, atomically
written, debounced, and retain last-known-good data after malformed input.
Modal openness, cursors, filters, scans, confirmations, and bar visibility remain
session-local.

### Output placement

- The bar remains on primary external `HDMI-0`.
- Searchable modals open on the currently focused output.
- Surfaces follow bridge output names, not Awesome screen indices.
- Display-layout changes must close or reposition all open modal surfaces.
- Remove arbitrary `Quickshell.screens[0]` placement fallbacks. If the
  bridge-authoritative output is unavailable, fail the surface unavailable
  rather than guessing.

### Bar capacity

The fixed clock remains mathematically centered and must not move as optional
widgets appear. Tray, media, Tailscale, weather, and status indicators need a
bounded right-side budget with compact/hidden-label behavior at narrower widths.
Validate both 1920-pixel and 1280-pixel output widths; no widget may collide with
the clock or focused-title region.

## Completed foundation

### Batch 0A — stabilize the current Rofi fallback

**Purpose:** Restore a dependable switcher before replacing it.

**Modify:**

- `awesome_wm_scripts/.config/scripts/rofi-window-switcher.sh`

**Changes:**

- import `awful` inside the selection-side `awesome-client` block;
- unminimize the selected target;
- keep `S` as display text but pass numeric `0` as untagged metadata;
- exclude the `scratchpad` class;
- return and check an explicit activation result instead of hiding Lua errors.

**Validation:**

- `bash -n`;
- select a window on each output;
- select a minimized client;
- verify synchronized workspace selection, target screen focus, unminimize,
  client focus, and raise.

No Awesome reload is required because Mod+Tab launches the script afresh.

### Batch 0B — Quickshell window switcher

**Create:**

- `.config/quickshell/modules/switcher/WindowSwitcher.qml`
- `.config/quickshell/services/ModalController.qml`

**Modify:**

- `.config/quickshell/awesome-integration/bridge.lua`
- `.config/quickshell/services/AwesomeBridge.qml`
- `.config/quickshell/services/AwesomeActionService.qml`
- `.config/quickshell/shell.qml`
- `awesome/.config/awesome/keys.lua`

**Behavior:**

- Mod+Tab toggles one focused-output Quickshell window.
- Entries show workspace, physical side/output, app class, title, and minimized
  state using the existing visual hierarchy.
- Typing filters; arrows or Ctrl+P/N navigate; Enter activates; Escape closes.
- Activation synchronizes the target workspace, unminimizes, focuses the target
  output/client, raises it, and closes the switcher.
- Desktop/dock/scratchpad clients are excluded.
- The fixed Rofi switcher remains an explicit recovery fallback until an
  equivalent emergency route is accepted.

**Acceptance:** internal→external and external→internal selection, current and
other workspaces, floating clients, minimized clients, long titles, client close
while open, and output topology changes.

### Batch 0C — persistent center `date - time`

**Modify:**

- `.config/quickshell/modules/bar/Clock.qml`

Replace the current time-first/click-for-date presentation with a persistent
date followed by a literal ` - ` separator and the time. The initial compact
target is `ddd dd MMM - HH:mm`; adjust only the date token widths during live
visual inspection if needed. The center must remain mathematically independent
of unequal left/right bar content.

The date never depends on clicking. Batch 4 adds calendar activation without
changing the exact clock format. Minute updates, wide weekday/month labels,
centered placement, and non-collision are already accepted.

### Batch 1 — modal and bar-popout coordination

`ModalController.qml` now coordinates the accepted global surfaces and controls.
Add `BarPopoutController.qml` when implementing Batch 4. The global controller
sees one `bar-popout` owner; the bar-local controller owns the exact child
(`controls`, `calendar`, `tray`, `media`, `notifications`, `tailscale`, or
`weather`). Focused-output placement and keyboard focus remain owned by each
surface.

Acceptance: invoking a second surface closes the first; Escape closes only the
active shell surface; focus is released on logical close; no bare global Escape
binding is introduced in Awesome.

### Batch 2 — application launcher (Mod+Space)

Implemented with the verified installed Quickshell 0.3.0 API. The launcher uses
the prefiltered `DesktopEntries.applications` model; ranked
name/generic-name/comment/keyword/category/ID search; theme icons; keyboard and
pointer selection; `DesktopEntry.execute()` for graphical apps; and fixed
WezTerm argv for parsed `Terminal=true` commands. `ModalController.qml` provides
mutual exclusion. The prepared Mod+Space callback uses Quickshell IPC and falls
back to Rofi drun on IPC failure. The route is live and accepted.

### Batch 3 — power/session menu (Mod+Escape)

Implemented with Suspend, Logout, Restart, and Poweroff plus a second explicit
confirmation state. Escape/back cancels; there is no countdown or default action.
Power-profile selection remains in the non-destructive power control.

Before destructive live-action acceptance, replace detached Awesome logout with
captured `awesome-client` output and an explicit success sentinel. Successful
process creation alone does not prove that logout was requested successfully.
Actual execution of each destructive action requires separate authorization.

## Next: calendar, remaining Rofi windows, and tray parity

### Batch 4 — centered-clock calendar

Replace the stale Rofi/copy concept with the current Omarchy calendar. The
centered clock is the activation surface; no new Awesome keybinding is required.

**Create:**

- `.config/quickshell/modules/calendar/CalendarModel.js`
- `.config/quickshell/modules/calendar/CalendarPanel.qml`
- `.config/quickshell/modules/calendar/qmldir`
- `.config/quickshell/services/BarPopoutController.qml`

**Modify:**

- `.config/quickshell/modules/bar/Clock.qml`
- `.config/quickshell/modules/bar/PrimaryBar.qml`
- `.config/quickshell/services/qmldir`
- `.config/quickshell/shell.qml`
- `awesome/.config/awesome/rules.lua`
- `awesome/.config/awesome/signals.lua`

**Take from current Omarchy:**

- pure date-key, locale/week-start, ISO-week, day/year-progress, fixed 6x7 month
  grid, and month-stepping model logic;
- hero date, year-progress rail, weekday headers, ISO-week gutter, dimmed padding
  and weekends, current-day outline, month/year label, and navigation chevrons;
- read-only day cells, midnight rollover, wheel stepping, and today reset.

**Adapt for the local X11 shell:**

- preserve the exact `ddd dd MMM - HH:mm` clock label;
- left click toggles a top-centered popup under the clock on the
  bridge-authoritative primary output;
- Left/Right move month, Up/Down move year, Enter returns to today, and Escape
  closes. Do not silently add H/J/K/L or Tab navigation;
- use the proven X11 map/activate/focus handshake and the bar-popout ownership
  contract;
- expose `openCalendar`, `closeCalendar`, `toggleCalendar`, and `status` IPC;
- add a `quickshell-calendar` Awesome class boundary without adding a custom
  `request::activate` handler;
- close on bar hide or authoritative-primary loss/change;
- keep week-start locale/config-derived and session-local initially.

**Defer:** format cycling/persistence, timezone mutation, Memento Mori, date
selection, events/agenda integration, clipboard actions, plugin manifests,
multi-monitor bar variants, and fullscreen click-away capture.

**Acceptance:** first-open keyboard focus, second-click/Escape close, bar/global
mutual exclusion, month/year rollover, today reset, midnight rollover, fixed
clock text, primary-output placement, 1920/1280 width safety, and no focus or
notification recursion. Use a lightweight pure-model boundary check and native
QML/source validation; do not create a broad calendar test harness.

### Batch 5 — keybind help (Mod+S)

Move the current categorized key list into a searchable Quickshell model and
modal. Keep the key list near `keys.lua` or generate a static bridge-safe model
so help does not silently drift from active bindings.

**Implemented in source:**

- `awesome-integration/bridge.lua` snapshots the active
  `require("awful.key").hotkeys` registry into bounded display-only records and
  normalizes modifier, letter, special-key, and workspace-keycode labels;
- `services/AwesomeBridge.qml` validates and exposes that optional bridge array;
- `modules/keybinds/KeybindHelp.qml` provides categorized token search, pointer
  selection, Up/Down and Ctrl+P/N navigation, Escape close, focused-output
  placement, global modal ownership, and status/open/close/toggle IPC;
- `keys.lua` keeps descriptions/groups beside the real bindings and routes Mod+S
  through an injectable callback; `rc.lua` refreshes bridge state after key
  registration and falls back to `rofi-keybinds.sh` if IPC is unavailable;
- Awesome modal rules/signals recognize `quickshell-keybind-help` without a
  custom activation handler.

The prior Rofi list had already drifted: it advertised a nonexistent theme
selector and omitted Ctrl from two workspace-move bindings. Runtime hotkey
metadata is now authoritative, so those errors are not copied into Quickshell.
Source verification covers all 44 current bindings, bridge lifecycle/refresh,
QML registration, isolated first-open focus, category/action filtering,
selection movement, modal ownership, and centered unclipped 1280x720 rendering.
After the normal Awesome reload, the calendar and Mod+S route were accepted live:
the bridge reported all 44 bindings and the user confirmed both surfaces work.

### Batch 6 — display manager (Mod+P)

Port Dual, External Only, Laptop Only, and Mirror choices. Display the exact
output names and intended geometry before applying. Treat RandR execution as a
device mutation, close/reposition surfaces after a change, and preserve the
confirmed default dual layout:

- `eDP-1-1` at `x=0`, left/secondary;
- `HDMI-0` at `x=1920`, right/primary.

Never infer physical placement from output type or screen index.

**Implemented in source:**

- `services/DisplayService.qml` exposes only four fixed profile IDs and sends a
  serialized mutating request through `CommandTransport`;
- `modules/display/DisplayManager.qml` presents exact output names, resolution,
  coordinates, primary/secondary state, and a two-step confirmation before
  dispatch. It unmaps before RandR and reopens on command failure;
- `rofi-display-manager.sh` retains its no-argument Rofi UI and adds a bounded
  `--apply dual|external|laptop|mirror` backend with connected-output/mode
  preflight and exact post-apply geometry verification;
- Mod+P uses Quickshell through a dedicated display-only `CommandTransport`.
  That capability is always available to the fixed confirmed profile runner,
  while the general native-mutation transport stays gated. Rofi remains only an
  IPC/unavailable fallback. `busy` is treated as handled so a second RandR menu
  cannot race the first;
- Awesome rules/focus boundaries recognize `quickshell-display-manager`.

Source verification passed `bash -n`, `awesome -k`, resident QML composition,
IPC registration/status, rejected-invalid-argument behavior, and scoped
capability checks. The live modal opened focused on the authoritative focused
output and closed cleanly; the general mutation transport remained disabled and
the dual-output topology stayed unchanged. No RandR profile, wallpaper action,
mutation marker, Awesome reload, or real display change was executed. Profile
application acceptance remains separate.

### Batch 6A — bundled workspaces and tag-bar authority (live)

The source repair restores the single-logical-workspace contract before more
bar state is added. One workspace index is selected across every Awesome
screen, and every view/move-follow path converges on that index rather than
advancing each screen's independent tag stack.

The read-only assessment found five concrete drift sources:

- `signals.lua` accepts the generic client title `quickshell` as shell identity.
  An ordinary terminal whose title temporarily matches can be permanently made
  floating, sticky, and skipped from the task list. Live evidence showed the
  focused WezTerm assigned to tag 2 with `sticky=true`, therefore visible while
  both screens and the bar reported tag 1;
- relative navigation calls `viewnext`/`viewprev` independently per screen, so
  an existing offset is preserved instead of healed;
- reload state stores and restores one tag index per screen, preserving any
  divergence across restart;
- native bar Mod+click move/toggle handlers operate on one screen/tag and do not
  use the global follow policy;
- the bridge publishes selected, occupied, and urgent state from the primary
  screen only, so the Quickshell bar cannot represent secondary-screen clients
  or diagnose divergence.

Implement one shared Awesome workspace coordinator used by absolute navigation,
relative navigation, client move-and-follow, native bar actions, and Quickshell
IPC. Compute relative targets once from the authoritative focused workspace and
apply that exact index to every screen. Persist and restore one global index,
not one index per screen. Add/restore absolute move-and-follow bindings if the
audit confirms they were lost.

Narrow shell-client identity to stable class/instance/type plus explicit modal
names; remove the generic-title ownership trap. Ordinary application clients are
normalized to non-sticky state on manage, property change, and Awesome reload;
intentional Quickshell docks/modals remain sticky. The stale shell-rule
`sticky+skip_taskbar` signature is repaired without changing maximized/floating
state.

Aggregate tag occupancy and urgency by corresponding tag index across all
screens. Publish the selected global index plus a synchronization flag, and make
the Quickshell tag bar render that authoritative model. Awesome's EWMH desktop
count remains ten (five tags per screen); do not mistake that implementation
detail for failed bundling or try to flatten Awesome's per-screen tag objects.

Live acceptance: Mod+number, relative next/previous, Quickshell bar click, native bar
click/scroll, move-and-follow, reload restoration, and post-RandR screen rebuild
all select the same tag index on both outputs. Moving a client preserves its
target screen while both screens follow the destination workspace. Occupied and
urgent bar states include clients from either output. Ordinary terminals never
become sticky when their title changes, and no live client property is repaired
without an explicit targeted authorization.

Implementation is source-complete:

- `signals.lua` exports the single workspace coordinator. It computes one
  relative destination, applies one index to every screen, moves clients within
  their current screen's tag stack, follows globally, repairs external tag
  selections, and repairs after screen add/remove events;
- keyboard paths, the native fallback bar, reload restoration, bridge actions,
  and Quickshell tag clicks use that coordinator. Super+Shift+1…5 move-and-follow
  bindings are restored. Multi-tag toggle gestures are synchronized view aliases
  because the desktop model intentionally permits one logical workspace;
- reload state now writes one index and reads both the new format and the old
  per-screen format, selecting the previously focused screen's old value;
- bridge tags aggregate occupied/urgent state by index across every output and
  publish `workspaceIndex` plus `workspaceSynchronized`;
- workspace commands have a dedicated mutation-capable transport. The general
  device/system transport remains disabled;
- generic `quickshell` window-title matching is removed from rules and geometry
  ownership. Stable class/instance/type and explicit modal names remain;
- relative view and move-follow are cyclic across 1–5. Super+Ctrl+J/K select the
  previous/lower and next/higher workspace respectively; adding Shift moves the
  focused client to that destination and follows globally;
- reload focus restoration refuses to focus a saved client that is hidden on a
  different workspace, preventing EWMH from overriding the restored global
  index.

Verification passed `awesome -k`, the focused workspace-coordinator regression,
the bridge lifecycle regression, and the isolated QML bridge smoke. The resident
Quickshell composition reports `workspaceMutationsEnabled:true`. After authorized
normal Awesome reloads, the active bridge reports 49 bindings and exact J/K
directions, both outputs and the bar report workspace 1 with synchronization
healthy, and no ordinary sticky client remains. The user confirmed synchronized
view/move behavior; the final requested lower/higher J/K direction is active.
Awesome/Xorg/Quickshell process identities and the two-output topology remained
unchanged, with no startup or state-restore error.

### Batch 7 — primary-bar system tray (implemented, live, and accepted)

Add the release-critical StatusNotifier tray before retiring the Pillbar/recovery
bar. Use the installed `Quickshell.Services.SystemTray` API.

Initial scope: one primary-bar host, active-item filtering, direct icon URLs,
left activation or menu-only behavior, right-click `QsMenuOpener` menus, middle
secondary activation, wheel forwarding, dynamic removal, bounded icon slots,
and a compact overflow affordance. Tray activation is ordinary desktop
interaction and does not require the device-mutation gate.

Defer animated drawer management and persistent pin/hide editing until real tray
crowding warrants them. Acceptance includes item arrival/removal, menu and
submenu actions, passive-item suppression, one-owner behavior, and 1920/1280 bar
capacity without moving the center clock.

Implementation is live:

- `modules/bar/SystemTray.qml` is the single primary-bar
  `StatusNotifierWatcher` host. It snapshots the installed
  `Quickshell.Services.SystemTray` model, suppresses passive items, and collapses
  to zero width while empty;
- `modules/bar/TrayItem.qml` renders direct icon URLs and forwards left
  activation/menu-only behavior, right-click menus, middle secondary activation,
  and vertical/horizontal wheel events;
- five 24px slots bound bar usage. Up to five items render directly; when more
  than five exist, four render directly and slot five becomes a compact overflow
  count. The independently anchored center clock does not depend on tray width;
- one bar-owned `PopupCard` renders overflow entries and `QsMenuOpener` menu
  pages. Submenus drill into the same surface, with pointer and keyboard
  navigation plus Back/Escape handling;
- shell/bar IPC publishes active, direct, overflow, and menu-open state for
  health checks.

The resident Quickshell process claimed the previously unowned
`org.kde.StatusNotifierWatcher` name without restarting. A temporary Fedora
`nm-applet --indicator` registered as a real Ayatana StatusNotifier item; the
bar changed from 0 to 1 active/direct item, the user confirmed the correctly
identified icon plus right-click menu and submenu navigation, and terminating
that exact test process returned the model to zero immediately. The watcher
remained resident and the bar geometry remained 1920x26. No tray QML error was
logged. Six-item overflow and a physical 1280 output were not live-exercised;
their capacity is enforced by the bounded slot/slice source contract rather than
claimed as visual acceptance.

Post-Batch 7 focus-loss correction is implemented, live, and accepted:

- `ModalController.qml` and `BarPopoutController.qml` now distinguish initial
  X11 activation from a later focus loss. A surface is dismissible only after it
  has first become active;
- all focusable global modals and bar popouts report their QWindow active state
  through the matching ownership controller. The shared system-controls popup
  now requests QWindow activation after the established 80ms focus handshake;
- clicking another application closes the active surface immediately, avoiding
  the deactivated-window fade/restack flash. Escape and normal ownership handoff
  keep their existing animated close path;
- three live reloads completed without a QML error. The user confirmed clean
  outside-click dismissal for a fixed top-bar control and the launcher, and
  confirmed that Escape still works. Final IPC showed every focusable surface
  closed with the resident shell, workspace synchronization, and tray healthy.

## Device and media completion

### Batch 8 — backend authority and detail-lifecycle spike

Before changing the three device panels, compare the installed native PipeWire,
Networking/NetworkManager, and Bluetooth/BlueZ APIs with the current services.
This is a read-only evaluation: verify summary completeness, object lifetime,
action/error reporting, X11 behavior, and whether open-only detail can be
cancelled cleanly. Select one owner per domain and record the decision in the
implementation notes. Native parity is not a reason by itself to replace a
working `CommandTransport` adapter.

**Decision — completed read-only on 2026-07-28:**

The installed build is `quickshell-git` 0.3.0 at revision
`4df562dfb2475a9057f0f33a8db75808efad8670`. Its native PipeWire,
NetworkManager, and BlueZ modules cover the object/state models required by
Batches 9–11. The current three adapters launch 38 resident read commands per
minute and expose only sink-level audio, the first active NetworkManager row,
and the first connected Bluetooth device. On this host NetworkManager currently
has four active connections and BlueZ has two paired devices, so those collapsed
summaries are not sufficient for the planned detail panels.

- **Audio authority:** `Quickshell.Services.Pipewire`. Keep native default
  sink/source summary state resident. Build sink, source, playback-stream, and
  capture detail as panel-local snapshots keyed by node ID; clear those snapshots
  and disable peak monitors when the panel closes. The native singleton graph
  remains resident because the bar needs its defaults. Observe state convergence
  with a bounded timeout because the installed API exposes writable mute, volume,
  and preferred defaults but no operation-failure signal. Retain a gated
  `CommandTransport` fallback only if live acceptance proves that moving already
  active streams or a host-specific DSP route cannot be completed natively.
- **Network authority:** `Quickshell.Networking` with its NetworkManager backend.
  Keep connectivity plus wired/Wi-Fi summary resident. Enable
  `WifiDevice.scannerEnabled` only while the network panel is open; on close,
  disable it, clear result snapshots and credential state, and stop detail
  timers. Use native PSK connection so secrets do not enter argv. Serialize each
  action by stable network identity, consume `connectionFailed`, and also require
  observed state convergence or a bounded timeout. Any later enterprise helper
  must receive secrets through stdin and cannot become a second state poller.
- **Bluetooth authority:** `Quickshell.Bluetooth`/BlueZ. Keep adapter power and
  connected-device summary resident. Snapshot device rows by Bluetooth address
  only while the panel is open. Discovery must be bounded and must explicitly set
  `adapter.discovering = false` on every close/error path. The refreshed Omarchy
  panel omits that close-time stop, and its `omarchy-bluetooth-device` helper
  suppresses all failures with `|| true`; neither behavior is copied. Native
  pair/trust/connect/disconnect/forget operations are observed by address with
  pending state and timeouts. Add a serialized, mutation-gated Fedora helper only
  after a real native sequencing failure is demonstrated.

All native writes remain behind the existing general mutation gate; importing a
native module does not authorize direct property writes from presentation QML.
PipeWire, NetworkManager, and BlueZ are compositor-neutral backend services, so
the authority change adds no Wayland dependency and leaves the established X11
`PanelWindow` focus/placement boundary unchanged. The command-backed services
remain in place until their respective implementation batches replace them; each
old poller is then removed atomically so no domain has two resident authorities.

### Batch 9 — complete audio management and microphone privacy

Extend the current audio panel with output/input selection, microphone
mute/state, volume control, per-application playback streams, and an optional
external settings action. Reuse the selected authoritative service rather than
create a separate menu. Snapshot dynamic PipeWire object lists before rendering,
preserve device identity across refreshes, and keep labels bounded.

Add a compact microphone privacy indicator only while capture is active; click
toggles mute or opens audio controls. Do not permanently consume bar width while
the microphone is idle.

**Implementation state — accepted within the available live topology on
2026-07-28:**

- `AudioService.qml` now imports `Quickshell.Services.Pipewire` and no longer
  launches `wpctl` reads or owns a refresh poller. Native default sink/source,
  volume, mute, and microphone-in-use state stay resident. Output, input, and
  playback-stream rows are plain snapshots keyed by PipeWire node ID; the rows,
  detail tracker, refresh timer, and `PwNodePeakMonitor` exist only while Audio is
  open and are cleared/stopped on close.
- Output/input volume and mute, preferred defaults, and per-stream volume/mute
  resolve the current native node immediately before each write. Every action
  rechecks the general mutation gate, exposes one stable pending key, and requires
  observed native convergence before success; disappearance and timeout become
  visible service errors. No command fallback remains because no native gap has
  been demonstrated. The optional external-settings action is intentionally
  omitted.
- The existing Omarchy control popup now contains bounded output and input rows,
  microphone level, playback applications, pointer controls, and one keyboard
  cursor across all sections. Content is capped and scrollable. A conditional
  microphone privacy glyph joins the right-anchored status group only while an
  unmuted capture stream exists; the independently centered clock is unchanged.
- The production hot reload completed without a new QML warning. Read-only IPC
  reports PipeWire ready, matching `ALC1220 Analog` output/input defaults, zero
  detached detail rows while closed, microphone idle, and the general mutation
  gate disabled. The resident Quickshell PID remained `17595`.
- Existing audio fixtures were converted from CLI response parsing to injected
  fake PipeWire objects so they cannot inherit or mutate the host graph. The
  isolated service and UI fixtures pass with clean diagnostics after correcting
  their stale expected-error and pre-settle timing assumptions. They verify
  native detail, gate denial, stable-ID validation, observed volume convergence,
  capped scrolling, focus, conditional microphone state, and keyboard routing.
- The live Audio surface attached one output and one input row, mapped at
  `380x313` on the right/primary output, and retained zero playback rows because
  no stream was active. Its capture showed aligned sections, sliders, device
  rows, and locked/read-only footer without clipping or overlap. Focus-loss
  dismissal then unmapped the panel, detached all detail arrays back to zero,
  and left PID 17595 resident. At this read-only checkpoint the gate stayed
  disabled and no audio state changed. The user visually accepted the panel; the
  separately authorized native-mutation check documented below completed
  afterward.
- The older Awesome/Xvfb geometry runner was not used as evidence. Its Xvfb test
  RC logged one synthetic `screen`, but inherited session D-Bus made
  `awesome-client` report the live `eDP-1-1`/`HDMI-0` topology. Before its
  geometry assertion failed, the runner's broad fixture preparation changed
  border/floating/sticky/task-list properties on then-present live clients.
  Read-only inventory identified surviving contamination only on ordinary Chrome
  and WezTerm clients. An explicitly authorized recovery restored Chrome to
  tiled, border 2, non-sticky, task-list-visible policy and restored WezTerm's
  task-list visibility while preserving its legitimate maximized/floating/border
  state. Quickshell and scratchpad policy was already correct and remained
  untouched; AwesomeWM was not reloaded or restarted.
- The runner is now source-hardened with a private `dbus-run-session`, a random
  nonce published by the dedicated test RC, a required `config-loaded` marker,
  exact Awesome/RandR topology agreement, rejection of live output names, and a
  fixture write narrowed to exactly one named dock. Python compilation, pure
  topology-parser fixtures, Lua bytecode parsing, and direct-entry nonce refusal
  pass. Per authorization, the harness was not rerun, so it contributes no
  runtime acceptance evidence.
- For the separately approved live mutation check, Quickshell alone restarted
  once with a one-process mutation environment. The first Left key exposed the
  audio cursor without changing 100%; the second converged natively to 95%; Right
  restored exactly 100%. The gated PID was then stopped and the normal shell
  relaunched as PID 489627 with both mutation variables and both per-login markers
  absent. No emergency CLI restoration was needed. Input/mute, alternate-default,
  and per-stream writes were unavailable or outside the selected bounded scope
  and remain explicitly unexercised rather than implied.

### Batch 10 — complete Wi-Fi management

Add scan/results, saved-profile matching, connect/disconnect/forget, and a
focused credential prompt. Preserve selection by stable SSID/network identity
across scans; serialize actions; show timeout/failure state; and restore panel
focus after the credential editor closes. Keep secrets out of logs, bridge state,
argv, and command history. Use native secret APIs or stdin. DNS switching,
throughput/ping dashboards, and speed tests are outside this consolidation.

**Implementation state — source-complete and accepted read-only on 2026-07-28;
live Wi-Fi mutation paths remain pending:**

- `NetworkService.qml` now uses the installed `Quickshell.Networking`
  NetworkManager backend as the only resident network-state authority. The old
  `nmcli` reads and refresh poller are gone. Connectivity plus wired/Wi-Fi
  summary stays resident; scanner ownership, plain network snapshots, and
  credential state attach only while Network owns the control popup. Close
  disables scanning and clears every detail and credential snapshot.
- Network rows use stable device/SSID/security identities and expose signal,
  security, known, connected, and state-changing status. Native radio,
  connect/disconnect, PSK-connect, and forget operations are centralized in the
  service. Every write rechecks the general mutation gate, serializes one pending
  action, and requires observed convergence or a 15-second timeout. Enterprise
  and unsupported security retain only the gated external connection-manager
  fallback; that fallback does not poll or mirror network state.
- The existing Omarchy control popup now includes bounded available-network
  rows, connect/disconnect and saved-profile removal, unified pointer/keyboard
  navigation, and a focused `PanelTextField` credential editor. Closing or
  submitting the editor wipes its text and restores panel focus. The PSK is
  passed only to native `connectWithPsk`; it is absent from argv, IPC status,
  logs, bridge state, command history, and fixture result payloads.
- The isolated service and complete-panel fixtures inject explicit fake
  NetworkManager objects and pass with clean diagnostics. They exercise scanner
  attach/detach, stable snapshots, gate denial, radio and row-action
  convergence, PSK submission/wiping, credential keyboard routing, and the
  connection-manager fallback without mutating the host. The UI fixture waits
  100 ms for the service's intentional 75 ms detail-refresh coalescer.
- Production composition reloaded cleanly in resident PID 489627. With the
  general mutation gate disabled, live opening attached Network detail in a
  `380x209` primary-output panel. The host had Ethernet `eno0` connected,
  Wi-Fi hardware enabled but its radio disabled, and `wlp0s20f3` unavailable;
  therefore zero rows and no scanner were expected. A before/after NetworkManager
  comparison was identical, no pending action appeared, and closing detached
  detail with scanning off and zero retained rows. The captured locked/read-only
  surface was aligned and unclipped.
- This is read-only live acceptance, not live mutation acceptance. Real scan
  results, radio changes, connect/disconnect/forget, PSK submission, and failure
  recovery remain unexercised on the current host state. The legacy Rofi Wi-Fi
  route remains a fallback. The Awesome/Xvfb runner was not invoked and provides
  no Batch 10 evidence.

### Batch 11 — complete Bluetooth management

Add bounded scan state, known/available device lists, pair/trust/connect,
disconnect, and remove operations. Preserve current adapter power and connected
summary plus device battery when BlueZ exposes it. Preserve selection by stable
Bluetooth address as devices move between sections. Scans time out and remain
cancellable without killing unrelated processes. A Fedora-safe helper may be
retained where native APIs do not provide reliable sequencing.

**Implementation state — source-complete and accepted read-only on 2026-07-28;
live Bluetooth mutation paths remain pending:**

- `BluetoothService.qml` now uses the installed `Quickshell.Bluetooth` BlueZ
  backend as the sole Bluetooth-state authority. The old `bluetoothctl` reads,
  parser, and 15-second refresh poller are gone. Adapter power and connected
  summary stay resident; stable-address plain device snapshots attach only while
  Bluetooth owns the control popup and are cleared on close.
- Open-only rows are sorted into Connected, Paired, and Available sections and
  preserve identity by normalized Bluetooth address as native state changes.
  Address/UUID-only noise is omitted, and battery percentage is included when
  BlueZ exposes it. Discovery is explicitly owned, capped at 15 seconds, and
  stopped on close, gate revocation, power-off, error, timeout, or destruction.
- Native adapter power, discovery start, pair/trust/connect, disconnect, and
  forget sequencing are centralized in the service. Every initiating or staged
  write rechecks the general mutation gate, serializes one action, and requires
  observed state convergence or a 20-second timeout. Pairing observes paired or
  bonded state before trust, observes trust before connect, and forget first
  observes disconnect when required. Errors clear after a bounded interval.
  No command helper is retained because the installed native API covers the
  required surface; presentation QML performs no native write.
- The Omarchy control popup now exposes adapter and scan controls, grouped device
  rows, battery/status metadata, disconnect/connect activation, and paired-device
  removal with unified pointer/keyboard navigation. Selection remains stable by
  address, and the gate-off state is visible both through disabled actions and a
  `CONTROLS LOCKED · READ-ONLY MODE` footer.
- The isolated service and complete-panel fixtures inject explicit fake BlueZ
  adapters/devices and pass with zero failures and clean diagnostics. They cover
  bounded discovery, filtered/grouped snapshots, battery state, gate denial,
  pair/trust/connect, disconnect, forget, native power convergence, keyboard row
  activation, close cleanup, and absence of Bluetooth command actions. The
  Awesome/Xvfb runner was not invoked and contributes no Batch 11 evidence.
- Production PID 489627 reloaded cleanly. With the general mutation gate off, a
  live read-only open mapped a `380x303` primary-output panel with two connected
  rows: `Majestouch Convertible3` and `Soundcore Life Q20+`; BlueZ exposed the
  Soundcore battery at 80%. The panel was aligned, unclipped, visually consistent,
  and explicitly marked read-only. IPC reported two open-only snapshots,
  discovery off, and no pending action. Before/after BlueZ state was identical:
  adapter powered, discovery off, and the same two devices paired and connected.
  Close detached detail and retained zero snapshots.
- This is read-only live acceptance, not live mutation acceptance. Real scan and
  available-device discovery, adapter power changes, pair/trust/connect,
  disconnect, forget, timeout/failure recovery, and pairing-challenge behavior
  remain unexercised on the production adapter. The Rofi Bluetooth route remains
  a fallback until those live paths are separately accepted.

### Batch 12 — MPRIS media control

Use installed `Quickshell.Services.Mpris`; do not add `playerctl`. Show a compact
conditional indicator only while a controllable player exists. The bar label
must be bounded and must not marquee or move the centered clock. The popout shows
title, artist, artwork when available, previous/play-pause/next, and stable
multiple-player selection. Media ownership remains resident; artwork/detail UI
may load on demand.

**Implementation state — source-complete, isolated behavior/visuals accepted,
and user-accepted live with YouTube on 2026-07-28:**

- Resident `MediaService.qml` now uses the installed
  `Quickshell.Services.Mpris` singleton directly. It retains no `playerctl`,
  command transport, process, or refresh poll. A source is exposed only when it
  has at least one usable previous/next/play/pause/toggle action, so dormant bus
  endpoints do not leave an empty indicator. Session identity is the player
  D-Bus name with bounded fallbacks.
- Explicit source choice remains stable until that source disappears; otherwise
  selection prefers a playing actionable source and then a deterministic
  fallback. Every native playback method is centralized in the service. The bar
  and popup perform no native call and never update playback state optimistically.
- `MediaWidget.qml` conditionally occupies the right bar section before the tray.
  Its plain-text title/artist label is capped at 180 px, right-elided, and never
  marquee-animated. The independently centered clock remains unchanged. The
  existing bar-local controller owns a single `340` px popup with on-demand
  artwork, bounded title/artist/album text, capability-aware transport buttons,
  stable source rows, and pointer/keyboard navigation.
- A private-D-Bus, Xvfb, fake-MPRIS fixture passes at both 1920 and 1280 widths
  with zero failures and clean diagnostics. It covers dormant filtering,
  playing-source preference, explicit-source stability, fake
  previous/play/pause/next routes, disappearing-source fallback, 180 px label capping,
  popup ownership, and empty-state close/release. The isolated `340x267` popup
  and `1280x26` full bar are aligned and unclipped; the latter visibly preserves
  the centered clock with clear separation from both side sections.
- The existing two-screen primary-bar regression still passes every assertion
  and reports no media diagnostic. Its pre-existing null-fixture warnings from
  SystemTray and controls remain outside Batch 12. The Awesome/Xvfb runner was
  not invoked and contributes no Batch 12 evidence.
- Production PID 489627 loaded the final graph cleanly at 19:55:07. Native MPRIS
  readiness is true, but the sole Chromium endpoint is stopped and reports every
  playback capability false, so IPC correctly reports zero actionable players,
  a hidden indicator, and a closed popup. A read-only open request returned
  `unavailable`; before/after state was identical and no playback method ran.
- The user then played YouTube through Chromium and accepted the conditional bar
  indicator, real metadata and artwork, popup presentation, and all exposed
  previous/play-pause/next controls. This completes single-player live acceptance.
  Multiple simultaneous real players and live source disappearance/fallback
  remain unexercised; their selection and teardown behavior is fixture-proven.

## Notification cutover

### Batch 13 — Quickshell notification server, DND, and history

Build toast presentation plus bounded history using the installed Quickshell
notification API after verifying its 0.3.0 ownership/lifecycle behavior.
Notification fields are untrusted display text and must use plain text or safe
escaping.

Required semantics:

- resident ownership after cutover;
- DND suppresses presentation, not collection;
- non-transient notifications received during DND enter pending/unseen history;
- explicit user dismissal/action moves a notification to past/seen history;
- automatic toast timeout or visible-overflow eviction hides presentation without
  acknowledging the history row on the user's behalf;
- `replaces_id` deduplication across toast and history;
- plain snapshots in `ListModel`, never retained live `Notification` QObjects;
- hover-paused expiry and persistent critical notifications;
- critical urgency alone does not bypass DND; only narrowly trusted local action
  feedback may bypass it;
- default-action invocation, mark-seen, clear, and a true browsable history path;
- bounded, versioned, atomic state under `XDG_STATE_HOME`, with debounced writes
  and last-known-good recovery;
- passive focus-free toast windows on one authoritative output.

Persistent image-cache machinery and application-focus heuristics may follow
basic toast/history acceptance; do not make them first-cut prerequisites.

Cutover must be atomic:

1. Quickshell notification service is implemented but not instantiated.
2. Toast/history UI is inspected in isolation.
3. In one approved activation, disable Awesome Naughty ownership/history and
   instantiate the Quickshell server.
4. Verify the D-Bus owner, normal/critical notifications, replacement IDs,
   timeout/dismiss, and history behavior.

Dunst is already absent; do not start it during migration.

**Implementation state — live accepted on 2026-07-28:** Quickshell is the
resident D-Bus owner. Normal and critical delivery, replacement IDs, action
invocation, hover-paused expiry, DND collection/suppression, bounded history,
clear/seen behavior, persistence recovery, and generic icon fallback passed at
1920×1080 and 1280×800. Awesome retains `naughty.core` only for its own error
reporting and does not load `naughty.dbus`; Dunst is masked and inactive.

### Batch 13A — post-acceptance expiry and burst-window hardening

**Assessment complete; implementation pending explicit approval after restart.**

A read-only sender trace of the broken Print Screen path recorded ten repeatable
Flameshot bursts. Each attempt emitted three notifications within roughly 100ms;
Quickshell then expired each group after about five seconds. There was no sender
`CloseNotification` request. Current D-Bus ownership is healthy, with no active
toast or notification-service error.

Two shell defects were exposed:

- `expirePopup()` and visible-overflow handling currently mark history `seen`, so
  passive timeout is conflated with acknowledgement despite the center's explicit
  New/Past tabs and `Mark seen` action;
- the shared `NotificationToasts` `PanelWindow` maps and resizes directly from
  `popupCount`, allowing a rapid burst to expose unsettled or repeatedly changing
  X11 geometry as top-right flicker.

The bounded follow-up changes only `NotificationService.qml`,
`NotificationToasts.qml`, and the existing `notification-smoke.qml` fixture.
Timeout/overflow should remove presentation while preserving New history;
explicit dismissal, action invocation, `Mark seen`, and appropriate non-expiry
native closure retain acknowledgement semantics. Toast presentation should let
layout settle before mapping, retain the largest geometry through a burst, limit
input to actual content, and briefly delay unmap after the final toast. Do not add
a general deduplication/queue framework unless a later real workload requires it.

The triggering application defect is separate: Flameshot 14 defaults to the
desktop portal, but the installed portal user service is dependency-failed on this
Awesome/X11 session. The clean application fix is the upstream
`useX11LegacyScreenshot=true` switch in host-local
`~/.config/flameshot/flameshot.ini`. No application or shell fix was applied during
this assessment.

## Included post-core bar features

### Batch 14 — reduced Tailscale panel

Use the installed `tailscale` CLI through `CommandTransport`; do not copy
Omarchy's Wayland clipboard or privileged helper assumptions.

First deliver the read-only surface: installed/running/login-needed state,
tailnet/self identity, IPv4 address, peer list, online state, OS, and current exit
node. Poll at a bounded interval, preserve last-known-good status on malformed or
failed reads, and refresh promptly while the panel is open. Copy actions use the
accepted X11 clipboard service, never `wl-copy`.

After read-only acceptance, separately gate `up`/`down` and exit-node selection
as device/network mutations with serialized execution and verified refresh.
Defer account switching, operator authorization via `pkexec`, file sending, and
automatic login/browser flow. The bar indicator and popout obey the width and
bar-local ownership contracts.

**Implementation state — source-complete and read-only live accepted on
2026-07-28:** `tailscale status --json` supplies one bounded last-good model, the
panel exposes self/peer/exit-node state, and copy actions use `xclip` through the
X11 clipboard service. Private fixtures verify malformed-data recovery, popup
ownership, exact clipboard bytes, and gated `down`, `up`, exit-set, and exit-clear
argv. Live status reported five peers and no network mutation was executed.

### Batch 15 — weather pill and forecast panel

Add a compact weather pill outside the fixed center-clock anchor plus an anchored
detail panel. Require an explicit user-selected location; do not silently use IP
geolocation. Keep location state host-local, versioned, and atomically written.

Use bounded HTTPS requests with short timeouts, a conservative refresh interval,
last-known-good display on transient failure, and a visible stale/unavailable
state. The panel may show current conditions, temperature, wind, precipitation,
sunrise/sunset, and a short forecast. Do not poll while hidden for detail that is
not needed by the bar summary. Acceptance includes offline/timeout behavior,
location change, stale-data recovery, popup coordination, and 1920/1280 bar
capacity without shifting `ddd dd MMM - HH:mm`.

**Implementation and live state — accepted:** Open-Meteo current/forecast and geocoding
reads use four-second `curl` bounds. No request occurs without an explicit
selection. A version-1 atomic host-local file stores coordinates and last-good
current/forecast data. The fixture verifies geocoding, location changes,
five-day bounds, malformed-response staleness, persistence, popout ownership,
and 400×472 rendering. Live selection resolves Hamad Town to Northern
Governorate, Bahrain; current conditions and five forecast days are non-stale.
The missing-`XDG_STATE_HOME` fallback was corrected to `~/.local/state`, the
version-1 snapshot was verified there, and the accidental null-based path was
removed after validation.

## Final retirement

Only after each replacement is accepted live:

- route all relevant Awesome keybindings to Quickshell IPC;
- remove Rofi from these shell flows while retaining any independently desired
  Rofi use;
- retain the native Pillbar/Rofi recovery paths until an equivalent emergency
  route exists, then retire them only after bar/modal recovery is proven;
- retire Awesome Naughty after Quickshell owns notifications;
- remove legacy scripts/themes only through a separately approved migration;
- run a final search for Polybar/Rofi/Dunst/Pillbar/Naughty launch references.

No package deletion, Stow reorganization, or bulk cleanup is part of an earlier
implementation batch.

**Live accepted on 2026-07-28:** `rc.lua` no
longer loads `pillbar_init` or emits Pillbar visibility signals. Alt+Space calls
Quickshell and, on IPC failure, starts it only when its process is missing. The
default key route has the same bounded recovery. Pillbar modules remain dormant
and were not deleted. Rofi modal and device routes remain deliberate recovery or
unaccepted-write fallbacks. `naughty.core` remains for Awesome errors without
claiming the notification D-Bus name. `awesome -k` passes. A normal reload kept
the same Awesome/Xorg processes, two-output geometry, synchronized workspace 1,
and 26px primary workarea; `pillbar_init` and `naughty.dbus` were both unloaded,
and the real Alt+Space binding passed visible → hidden → visible.

## Validation model

Use proportional native checks and the real desktop:

- QML/source validation available from Quickshell and a live-reload log check;
- `awesome -k` for any Awesome Lua edit;
- `bash -n` for retained helper scripts;
- IPC status calls for surface state;
- focused live keyboard round trips for each accepted keybind;
- representative offline/timeout/malformed-data checks for weather, Tailscale,
  notifications, and CLI-backed device services;
- user visual acceptance for placement, typography, spacing, selection, and
  transitions.

Do not revive or expand the old Xvfb harness as a routine gate. Never reload
Awesome without separately disclosing that its startup path runs the two-pass
RandR monitor setup.

## Definition of consolidated

The project is complete when the Quickshell bar, window switcher, application
launcher, power/session menu, calendar, keybind help, display/device controls,
system tray, media/microphone state, notification server/history, Tailscale,
weather, and OSD are live and accepted; Rofi/Polybar/Dunst no longer own the
replaced surfaces; Awesome retains only window-management responsibilities and
deliberate recovery hooks; and no destructive action can execute without explicit
user confirmation.
