# Quickshell desktop project status

Updated: 2026-07-30

## Outcome

Replace the fragmented Polybar/Rofi/Dunst-era UI with one resident Quickshell
system while retaining AwesomeWM as the X11 window manager. Every shell-owned
surface should use the existing Omarchy palette, metrics, components,
keyboard model, and output-placement rules.

## Completion handoff — Quickshell-only migration

- Awesome routes all nine shell actions through one exact selected-config
  Quickshell controller. No active callback launches Rofi, Dunst, Polybar, or
  Pillbar, and the bridge has a fresh heartbeat/generation contract.
- D-Bus health is independently PID-attested: shell IPC distinguishes loaded,
  owned by this process, foreign-owned, unowned, and malformed/unknown states for
  Notifications and StatusNotifierWatcher.
- Session actions use the serialized result-bearing transport, fixed argv, exact
  confirmation, `systemctl --no-block`, and an explicit Awesome logout sentinel.
  No destructive session action was run during completion.
- Output fallback is consistently focused → primary → first valid screen;
  clipboard execution has TERM/KILL timeout cleanup; launcher icon resolution is
  checked; and the retained compact controls have accessible semantics/targets.
- Muted and urgent small-text palette tokens meet the 4.5:1 contrast target.
- General native controls now default enabled. The accepted selected process
  reports `nativeMutationsEnabled:true`; the absent per-login `safe-mode` marker
  is the only general read-only recovery switch.
- Rofi, Polybar, Dunst, mixed retired helpers, and Pillbar source are held only in
  explicit top-level `*-archived` directories. Their profile/catalog entries and
  live config targets are absent, while the current Awesome, Quickshell, and
  helper packages all report `CURRENT`.
- The final normal Awesome restart preserved the accepted two-output topology and
  workareas. The selected Quickshell process restarted once, reacquired both
  D-Bus names, and retained fresh bridge/workspace state.

The detailed component sections below preserve chronological acceptance evidence.
Where an older process ID, gate state, or temporary fallback note conflicts with
this handoff, the handoff above is authoritative.

## Restart handoff — Flameshot and notification hardening

- The Picom Quickshell override is active and visually accepted; the user reports
  that shell-window motion is much better. The controls popup also presents the
  TuneD backend through three user-facing Saver, Balanced, and Performance pills,
  and that presentation is visually accepted.
- Print Screen is currently blocked before the Flameshot GUI opens. The active
  helper's hidden 16×16 preflight invokes Flameshot 14's default desktop-portal
  capture path, while `org.freedesktop.portal.Desktop` is unavailable because the
  installed portal user service is dependency-failed. Each attempt reproducibly
  emits three Flameshot notifications: portal failure, capture failure, and
  capture aborted.
- A sender-only D-Bus trace recorded ten attempts as thirty notifications. Each
  three-item burst arrived within roughly 100ms, then Quickshell expired the
  three items together after about five seconds. No sender `CloseNotification`
  request caused the transition. Notification text was not retained in the trace.
- Quickshell currently owns `org.freedesktop.Notifications`, reports no active
  popup or service error, and retains the thirty traced entries as seen history.
  The failure storm exposed two post-acceptance defects rather than an ownership
  regression: the shared toast window maps/resizes directly from model count, and
  automatic toast expiry incorrectly marks history seen.
- No Flameshot or notification fix has been applied. The clean restart follow-up
  is one bounded batch: set `useX11LegacyScreenshot=true` in the host-local regular
  file `~/.config/flameshot/flameshot.ini`; make timeout/overflow hide a toast
  without acknowledging its history row; preserve seen transitions for explicit
  user action and appropriate non-expiry native closure; and stabilize toast
  mapping by settling layout, freezing burst geometry, and briefly delaying
  unmap. Extend the existing notification smoke fixture rather than adding a new
  harness. Source editing and any live reload remain separately gated.

## Live baseline

- Runtime: Quickshell 0.3.0 on AwesomeWM 4.3/X11.
- Quickshell and the Awesome bridge start unconditionally from `rc.lua`.
- `shell.ping` returns `ok`; the bar and controls IPC targets are available.
- External `HDMI-0` is the primary output at `x=1920` and owns the bar.
- Internal `eDP-1-1` is the secondary output at `x=0`.
- Alt+Space toggles Quickshell visibility and reserves 26px only on `HDMI-0`.
- Mod+H/L focus navigation works in both directions, including a normal
  application whose Awesome client is floating.
- The `safe-mode` marker is absent, so general device/system controls are enabled.
  Fixed display and destructive session actions retain their separate boundaries.
- No Polybar, Dunst, or persistent Rofi process is running. Their live config
  targets and registrations are absent; source is reference-only under archives.

## Implemented in Quickshell

### Foundation and style

- `style/Palette.qml` and `style/Metrics.qml` define the shared visual language.
- `ui/X11Panel.qml`, `PopupCard.qml`, `PopupToolTip.qml`, `PanelHero.qml`,
  `PanelSectionHeader.qml`, `PanelSlider.qml`, `OmarchyButton.qml`, and
  `KeyboardNavigator.qml` provide reusable Omarchy-style primitives.
- Transparent X11 surfaces, explicit backgrounds, rounded cards, keyboard
  navigation, and output-aware placement are established patterns.

### Awesome bridge and action boundary

- `awesome-integration/bridge.lua` publishes primary/focused outputs, tags, and
  focused-client state through a private runtime JSON file.
- `services/AwesomeBridge.qml` validates and watches that state.
- `services/AwesomeActionService.qml` provides synchronized tag selection
  through a static `awesome-client` program.
- `services/CommandTransport.qml` serializes commands, applies timeouts, bounds
  the queue, and rejects mutations unless explicitly enabled.

### Primary bar

- One continuous 26px translucent bar is attached to the primary Awesome output.
- Left: synchronized tags and focused-client title.
- Center: independently centered persistent `date - time` clock using
  `ddd dd MMM - HH:mm`.
- Right: bounded weather, Tailscale, notification, media, StatusNotifier, and
  native Bluetooth/network/audio/display/power status. Optional labels remain
  outside the independently centered clock anchor.
- Alt+Space controls resident bar visibility through IPC.

### Controls popup

- One 380px content-fitted popup presents audio, network, Bluetooth, display,
  and power-profile views.
- The popup uses shared hero/section/button/slider components and supports
  pointer and keyboard operation.
- Read-only state remains available when mutations are locked.
- Implemented actions include volume/mute, Wi-Fi power/manager launch,
  Bluetooth power, brightness, and power profiles. Production execution is
  enabled by default and can be disabled only through the safe-mode boundary.
- Power-profile selection maps the TuneD backend to three user-facing Saver,
  Balanced, and Performance pills; the user accepted the resulting popup.

### OSD

- A passive bottom-center OSD accepts volume, microphone, and brightness events
  over Quickshell IPC.
- Payloads are normalized and bounded; unsupported event types are rejected.
- The OSD follows the focused output, then primary, then the first valid screen.

### Window switcher — live and accepted

- The bridge publishes a bounded ordinary-client model with numeric window ID,
  title, class, output, physical side, tag index, and window state.
- A focused-output Quickshell modal supports filtering, keyboard/mouse
  selection, minimized/fullscreen/maximized indicators, and explicit errors.
- Activation validates the published numeric ID, synchronizes the target tag,
  unminimizes, focuses the target output/client, and raises it.
- Desktop, dock, scratchpad, and Quickshell-owned clients are excluded.
- Mod+Tab now opens the Quickshell switcher; filtering, keyboard navigation,
  focused-output placement, and window activation are accepted live.

### Application launcher — live and accepted

- `DesktopEntries.applications.values` supplies the installed Quickshell 0.3.0
  model, which already excludes Hidden and NoDisplay entries.
- Search covers name, generic name, comment, keywords, categories, and desktop
  entry ID, with exact/prefix name matches ranked first.
- Theme icons use Quickshell's resolver with a generic application fallback.
- Normal applications use `DesktopEntry.execute()`; `Terminal=true` entries use
  fixed WezTerm argv plus Quickshell's parsed desktop-entry command list, with no
  shell interpolation.
- Mod+Space now opens the Quickshell launcher; filtering, keyboard navigation,
  and graphical/terminal application launch are accepted live.

### Session menu — live and accepted

- Mod+Escape opens the Quickshell session menu on the focused output.
- Suspend, logout, restart, and poweroff use an explicit two-Enter confirmation
  contract and result-bearing execution. Immediate failure leaves the menu open
  with the error; no destructive action was executed during acceptance.

### Calendar — live and accepted

- Clicking the fixed center clock toggles a top-centered Omarchy-style calendar
  on the authoritative primary output.
- The pure date model provides locale week start, ISO weeks, fixed 6x7 month
  grids, leap-year handling, year progress, and month/year rollover.
- Calendar IPC, bar-popout/global-modal mutual exclusion, Awesome boundaries,
  keyboard focus/navigation, and real-output rendering are verified and accepted
  live after the normal Awesome reload.

### Keybind help — live and accepted

- The bridge exports the active Awesome `awful.key.hotkeys` metadata rather than
  duplicating the stale Rofi rows; 44 current bindings normalize into categorized
  display-only records.
- The centered searchable modal filters by key, category, or action; supports
  pointer selection, Up/Down, Ctrl+P/N, and Escape; and joins global modal
  ownership on the focused output.
- Mod+S calls the selected Quickshell config through the bounded controller. The
  bridge reports the active bindings and the searchable modal is accepted live;
  failure reports an Awesome-local Quickshell error instead of launching Rofi.

### Display manager — live UI, profile application pending

- Four fixed profiles cover Dual, External Only, Laptop Only, and Mirror using
  exact `eDP-1-1`/`HDMI-0` names and explicit 1920×1080 coordinates.
- The focused-output modal displays the intended topology and requires two-step
  confirmation before dispatching through the serialized mutation boundary.
- The generic `x11-display-profile.sh` backend provides bounded fixed-profile
  preflight and post-apply geometry checks without an interactive Rofi path.
- A dedicated display-only command transport permits only this fixed confirmed
  profile runner; the general mutation transport remains disabled.
- Resident IPC/composition, shell/Awesome syntax, focused open/close behavior,
  modal boundaries, and unchanged real topology are verified. Mod+P now owns the
  Quickshell-only route. No real profile has been applied through Quickshell yet.

### Workspace synchronization — implemented and live

- One coordinator now owns absolute and relative view, move-and-follow, external
  selection repair, post-screen-change repair, native-bar actions, Quickshell
  actions, and one-index reload persistence.
- Bridge tag state aggregates occupied/urgent flags across corresponding tag
  indices on all outputs and publishes the authoritative index plus a
  synchronization-health flag.
- Super+Shift+1…5 move-and-follow bindings are restored. Workspace commands use
  a dedicated scoped transport without enabling general device/system writes.
- Generic `quickshell` title matching was removed; stable shell identity and
  explicit modal names remain.
- Super+Ctrl+J/K select the previous/lower and next/higher workspace; adding
  Shift moves the focused client and follows globally. Relative view and move
  wrap cyclically across workspaces 1–5.
- Ordinary applications are normalized to non-sticky state while intentional
  Quickshell docks/modals retain shell geometry ownership. The contaminated
  WezTerm was repaired without changing its maximized/floating state.
- Source checks and authorized normal reloads passed. The live bridge reports 49
  bindings, both outputs and the Quickshell bar report one synchronized index,
  no ordinary sticky client remains, and the user confirmed synchronized
  view/move behavior.

### Primary-bar system tray — live and accepted

- Quickshell owns the previously unowned `org.kde.StatusNotifierWatcher` name
  through one resident tray host on the primary bar.
- Passive items are suppressed. The tray collapses while empty and uses no more
  than five 24px bar slots; slot five becomes an overflow count only when more
  than five active items exist.
- Direct icon URLs, left/menu-only activation, right-click menus, middle
  activation, wheel forwarding, and dynamic removal are wired through the
  installed Quickshell 0.3.0 API.
- Overflow and `QsMenuOpener` menu/submenu pages share one bar-owned Omarchy
  popup with pointer and keyboard navigation.
- A temporary real `nm-applet --indicator` item arrived without a shell restart.
  The user confirmed its correctly identified icon, right-click menu, and
  submenu navigation; terminating the exact test process removed it immediately
  while watcher ownership and resident process identity remained stable.
- Live status is currently a healthy empty tray. Six-item overflow and a
  physical 1280 layout remain source-bounded rather than live-exercised.

### Focus-loss dismissal — live and accepted

- The global modal and bar-popout controllers now arm dismissal only after the
  active X11 popup has actually received focus. Losing that focus to another
  application closes the owned surface through its existing close path.
- Launcher, window switcher, session menu, keybind help, display manager,
  calendar, system controls, and tray menu/overflow all report their QWindow
  activation state to the appropriate controller.
- The fixed system-controls popup now uses the same delayed QWindow activation
  handshake as the other keyboard-driven surfaces; focusing only its child QML
  item was insufficient for outside-click dismissal on X11.
- Focus-loss dismissal unmaps immediately to avoid animating a deactivated and
  restacked X11 window. Escape retains the normal fade. The user confirmed clean
  outside-click dismissal for both a fixed top-bar control and the launcher,
  with Escape still working.

### Backend authority and detail lifecycle — Batch 8 decision complete

- Read-only assessment used the exact installed `quickshell-git` 0.3.0 revision
  `4df562dfb2475a9057f0f33a8db75808efad8670`, its QML type descriptions, the
  current command-backed services, live read-only host state, and the refreshed
  Omarchy panel sources.
- The three current adapters issue 38 read commands per minute and collapse the
  state needed by the remaining panels. Native PipeWire, NetworkManager, and
  BlueZ are therefore selected as the sole state authorities for audio, network,
  and Bluetooth respectively; this is a recorded design decision, not an active
  service replacement in Batch 8.
- Audio keeps native default sink/source state resident and creates node/stream
  snapshots plus peak monitoring only while its panel is open. Network keeps
  connection summary resident but enables Wi-Fi scanning and credential/detail
  state only while open. Bluetooth keeps adapter/connected summary resident but
  must start bounded discovery only while open and explicitly stop it on close.
- Native operations must pass the existing general mutation gate and confirm
  success through observed state plus bounded timeout/error state. A serialized
  `CommandTransport` helper is allowed only for a demonstrated native gap; it
  cannot become a second poller or state authority.
- Omarchy's silent Bluetooth helper and its missing close-time discovery stop
  were rejected. Its audio model-detachment and network scan-cancellation
  patterns were retained as implementation guidance. The native backend modules
  are compositor-neutral and do not change the existing X11 window boundary.

### Native audio management — Batch 9 accepted within live topology

- The command-backed audio polling adapter has been replaced atomically by the
  installed native PipeWire service. Default output/input, mute/volume, and
  capture privacy remain resident; device, playback-stream, and input-peak detail
  attaches only while Audio is open and clears/stops on close.
- The existing control popup now provides output/input defaults and sliders,
  microphone mute/level state, per-application playback volume/mute, bounded
  labels, capped scrolling, and pointer plus keyboard navigation. Native writes
  are centralized in `AudioService.qml`, recheck the general mutation gate, and
  require observed convergence with finite pending/error state.
- A compact microphone privacy glyph consumes no bar width while idle. It opens
  Audio on activation and does not alter the independently centered clock.
- Production composition reloaded cleanly. Read-only IPC reports native PipeWire
  ready with `ALC1220 Analog` as both current output and input, no detail rows
  retained while the popup is closed, microphone idle, and
  `nativeMutationsEnabled:false`; PID 17595 remained resident.
- The fake-PipeWire service and complete-panel fixtures pass under bounded Xvfb
  with clean diagnostics. They cover native snapshots, gate denial, stable-ID
  validation, observed 65-to-70% convergence, capped scrolling, focus,
  microphone privacy state, and keyboard routing without touching the host graph.
- Live read-only opening attached one output and one input, no playback streams,
  and a `380x313` primary-output panel. The captured hierarchy was aligned and
  unclipped. Focus-loss dismissal detached every detail row back to zero while
  PID 17595 stayed resident. The gate remained disabled throughout that stage,
  and the user visually accepted the live read-only panel.
- A separately authorized Quickshell-only restart enabled the gate for one
  bounded output test. Keyboard routing kept 100% unchanged on cursor reveal,
  converged 100-to-95%, then restored exactly 100%. No fallback restoration was
  needed. The normal shell is now PID 489627 with the gate environment and both
  markers absent, detail detached, bridge/audio ready, and volume 100%.
- Input/mute, alternate-device, and per-stream writes were unavailable or outside
  the selected bounded live scope. They remain explicitly unexercised; Batch 9 is
  accepted within the available topology rather than claiming those absent paths.
- A rejected legacy Awesome/Xvfb run exposed a separate harness isolation defect:
  X11 was synthetic, but inherited session D-Bus connected `awesome-client` to
  live AwesomeWM. Its broad fixture-preparation expression changed mutable client
  properties before the topology mismatch failed the run. Exact read-only
  inventory found surviving contamination on Chrome and WezTerm only. Authorized
  recovery restored Chrome to configured tiled/border/task-list policy and
  WezTerm task-list visibility without changing its legitimate maximized state;
  intentional Quickshell and scratchpad properties were untouched.
- `run-awesome-xvfb.py` and its dedicated RC are now source-hardened with private
  D-Bus, nonce plus startup-marker attestation, exact Awesome/RandR topology
  agreement, live-output rejection, and one-dock-only fixture preparation. Static
  Python/Lua and parser/guard checks pass. The harness was deliberately not rerun
  and provides no Batch 9 evidence.

### Native Wi-Fi management — Batch 10 implemented and read-only accepted

- The command-polled network adapter has been replaced atomically by the
  installed `Quickshell.Networking` NetworkManager authority. Summary state is
  resident; Wi-Fi scanning, plain stable-ID rows, and credentials exist only
  while Network is open and are cleared on close.
- Native radio, connect/disconnect, PSK-connect, and forget writes are centralized
  in `NetworkService.qml`. Every write rechecks the general mutation gate,
  serializes one pending action, and requires observed convergence or a bounded
  timeout. Presentation QML does not write native properties. Enterprise and
  unsupported security retain a gated external-manager fallback only.
- The control popup now has bounded network rows, saved-profile removal,
  pointer/keyboard navigation, and a password-aware inline editor. Credential
  text is wiped on submit/cancel/close and never enters argv, IPC status, logs,
  bridge state, command history, or fixture results.
- Explicit fake-NetworkManager service and complete-panel fixtures pass with
  clean diagnostics. They cover scanner lifecycle, stable snapshots, gate
  denial, native convergence, PSK wiping, focus restoration, and keyboard
  routing without touching the host graph.
- Production PID 489627 reloaded cleanly. The gate-off read-only panel mapped at
  `380x209`, showed connected Ethernet `eno0`, and rendered aligned and unclipped.
  Wi-Fi hardware was enabled but the radio was disabled and `wlp0s20f3` was
  unavailable, so zero rows and no scanning were expected. NetworkManager state
  was identical before and after opening; close detached detail and retained no
  rows or pending action.
- Live scan/results, radio mutation, connect/disconnect/forget, PSK submission,
  and failure recovery remain unexercised. The old Wi-Fi helper is archived and
  is not an active fallback; the Awesome/Xvfb runner was not used as Batch 10
  evidence.

### Native Bluetooth management — Batch 11 implemented and read-only accepted

- The command-polled Bluetooth adapter has been replaced by the installed
  `Quickshell.Bluetooth` BlueZ authority. Adapter power and connected summary are
  resident; stable-address Connected, Paired, and Available snapshots exist only
  while Bluetooth is open and are cleared on close.
- Native discovery, adapter power, pair/trust/connect, disconnect, and forget are
  centralized in `BluetoothService.qml`. Starts and staged writes recheck the
  general mutation gate, one action is serialized at a time, and success requires
  observed native convergence before a 20-second timeout. Owned discovery is
  capped at 15 seconds and always stopped during teardown. No helper is retained.
- The popup now has adapter/scan controls, grouped device rows, battery/status
  metadata, paired-device removal, stable-address selection, and unified
  pointer/keyboard navigation. Gate-off controls are disabled and explicitly
  labeled read-only.
- Explicit fake-BlueZ service and complete-panel fixtures pass with zero failures
  and clean diagnostics. They exercise discovery lifecycle, snapshots, battery,
  gate denial, pair/trust/connect, disconnect, forget, power convergence,
  keyboard activation, teardown, and zero Bluetooth command actions without
  touching the host graph. The Awesome/Xvfb runner was not used.
- Production PID 489627 reloaded cleanly. A gate-off open mapped an aligned,
  unclipped `380x303` panel with `Majestouch Convertible3` and
  `Soundcore Life Q20+` connected; the Soundcore battery displayed 80%. Discovery
  stayed off, no action was pending, and BlueZ was identical before and after:
  powered, not discovering, with the same two paired/connected devices. Close
  removed both detail snapshots.
- Live discovery/results, adapter power, pair/trust/connect, disconnect, forget,
  timeout/failure recovery, and pairing-challenge behavior remain unexercised.
  The old Bluetooth helper is archived and is not an active fallback.

### MPRIS media control — Batch 12 live accepted with YouTube

- `MediaService.qml` is the resident `Quickshell.Services.Mpris` authority. It
  filters dormant endpoints, preserves explicit source choice by session-stable
  D-Bus identity, otherwise prefers a playing source, and centralizes every
  capability-checked native playback method. There is no `playerctl`, process,
  command transport, or refresh poll, and presentation QML makes no native call.
- A conditional right-bar label is plain text, right-elided at 180 px, and does
  not marquee or alter the independently centered clock. The existing bar-local
  controller owns a `340` px popup with on-demand artwork, bounded metadata,
  previous/play-pause/next, stable source rows, and pointer/keyboard navigation.
- The private-D-Bus fake-MPRIS fixture passes cleanly at 1920 and 1280. It covers
  dormant filtering, source preference/stability/fallback, fake playback routes,
  popup ownership, and empty close/release. An isolated `340x267` popup and
  `1280x26` bar are aligned, unclipped, and preserve center-clock separation.
- Production PID 489627 loaded cleanly. Its only Chromium MPRIS endpoint is
  stopped with every playback capability false, so native readiness is true but
  IPC correctly reports zero actionable players, no indicator, and no popup. A
  read-only open returned `unavailable`; no real playback method was invoked.
- The user then played YouTube through Chromium and accepted the conditional
  indicator, live metadata/artwork, popup, and previous/play-pause/next controls.
  Multiple simultaneous real players and live source disappearance remain
  unexercised; fixture coverage retains the source-selection/fallback boundary.

### Native notifications — Batch 13 live and accepted

- Quickshell now owns `org.freedesktop.Notifications`; normal/critical delivery,
  replacement IDs, actions, expiry, DND, bounded history, seen/clear behavior,
  persistence recovery, and toast/history rendering pass isolated and live checks.
- Awesome loads only `naughty.core` for its own errors and does not load
  `naughty.dbus`. Dunst is masked and inactive.
- Post-acceptance Flameshot failure tracing confirmed healthy current D-Bus
  ownership but exposed two pending hardening items: automatic expiry must not
  imply user acknowledgement, and burst presentation must not map/resize the
  shared X11 toast window before its layout is stable. The restart handoff above
  is the current defect record.

### Reduced Tailscale panel — Batch 14 live read-only accepted

- One bounded `tailscale status --json` adapter preserves last-good state and
  exposes self, peer, online, OS, and exit-node information.
- Copy uses an exact-byte X11 `xclip` service. Device/network writes stay gated;
  private fixtures prove exact argv while no live Tailscale mutation was run.

### Explicit-location weather — Batch 15 live and accepted

- The bar and 400px Omarchy popup provide explicit Open-Meteo geocoding, current
  conditions, metrics, and a five-day forecast. Summary refresh is resident only
  after configuration; detail refresh occurs while the panel is open.
- Versioned atomic host-local state retains the selected coordinates and last-good
  data. Fixtures pass location change, malformed/offline staleness, persistence,
  popup ownership, and 1280/1920 center-clock capacity.
- Production is configured for Hamad Town, Northern Governorate, Bahrain. Live
  geocoding, current conditions, five forecast days, popup lifecycle, and
  non-stale status pass. The version-1 snapshot is verified under
  `~/.local/state/quickshell/weather/weather-v1.json`.

### Integration and fallback

- Awesome starts the exact selected Quickshell config and canonical bridge
  permanently.
- Quickshell surfaces are excluded from normal Awesome client geometry rules.
- Every shell key route uses the centralized controller. On IPC failure it
  inspects only the selected config, starts it only when absent, retries once,
  and reports a bounded Awesome-local error without a legacy UI fallback.
- Awesome starts do not load Pillbar or Naughty D-Bus ownership. Retired source
  is archived and none is reachable through active shell key routing.

## Current ownership map

| Surface | Current owner | Consolidation state |
|---|---|---|
| Primary bar | Quickshell | Implemented and live |
| Center date/time | Quickshell | Implemented and live |
| Status/control popup | Quickshell | Live; mutations enabled by default, safe mode available |
| Volume/mic/brightness OSD | Quickshell | Implemented |
| Window switcher (Mod+Tab) | Quickshell | Live and accepted; bounded Quickshell-only recovery |
| Application launcher (Mod+Space) | Quickshell | Live and accepted; bounded Quickshell-only recovery |
| Power/session menu (Mod+Escape) | Quickshell | Live and accepted; destructive actions untested |
| Keybind help (Mod+S) | Quickshell | Live and accepted; bounded Quickshell-only recovery |
| Display manager (Mod+P) | Quickshell | Live/focused; real profile acceptance pending; generic backend |
| Primary-bar system tray | Quickshell | Live and accepted; empty when no StatusNotifier item is registered |
| Full audio menu | Quickshell | Native live accepted within available topology; general gate on |
| Full Wi-Fi menu | Quickshell | Native detail accepted read-only; writes enabled but unexercised paths remain |
| Full Bluetooth menu | Quickshell | Native detail accepted read-only; writes enabled but unexercised paths remain |
| MPRIS media control | Quickshell | Live accepted with YouTube; multiple-real-player boundary pending |
| Center-clock calendar | Quickshell | Live and accepted |
| Toast notifications/history | Quickshell | Live ownership accepted; expiry semantics and burst-window hardening pending |
| Tailscale | Quickshell | Live read-only accepted; writes gated and fixture-proven |
| Weather | Quickshell | Live and accepted for Hamad Town, Bahrain |
| Recovery bar | Quickshell start-on-missing hook | Pillbar retired and live accepted |
| Polybar | None | Runtime replacement complete |
| Dunst | None | Masked and inactive; Quickshell owns notifications |

## Accepted surfaces and current activation boundary

The Mod+Tab switcher, Mod+Space launcher, Mod+Escape session menu, center-clock
calendar, Mod+S keybind help, and primary-bar StatusNotifier tray are live and
accepted. Their failure boundary is now selected-config Quickshell recovery and
an Awesome-local error; there is no Rofi runtime fallback.
The display manager is live through a display-only capability while general
native mutations are enabled; no real display profile has been applied through
Quickshell.

## Residual acceptance boundaries

- The global modal coordinator covers the switcher, launcher, session menu,
  keybind help, display manager, and the bar-popout umbrella.
- Batches 6A–15 are implemented at their recorded live boundaries. Batch 15 is
  live accepted for Hamad Town with current/forecast data and verified versioned
  persistence. Final Pillbar retirement is live accepted: the normal
  Awesome reload preserved topology/workareas, loaded neither `pillbar_init` nor
  `naughty.dbus`, and Alt+Space passed a visible → hidden → visible round trip.
- Actual suspend/logout/restart/poweroff execution remains separately unverified.
- The audio popup now has read-only runtime parity for input/output selection,
  microphone state, and playback-stream presentation. The user accepted its live
  appearance and bounded output-volume mutation path; unavailable mutation paths
  remain explicitly unexercised. The Network popup has read-only live acceptance,
  but live Wi-Fi scan/results, radio/connect/disconnect/forget, and password flow
  remain outside because the radio was disabled and the adapter unavailable.
  The Bluetooth popup also has read-only live acceptance, but live
  scan/results, adapter power, pair/trust/connect, disconnect, forget, and
  failure recovery remain outside. Display-layout selection also remains
  outside. MPRIS multiple-real-player selection and live source disappearance
  remain outside acceptance, although their fallback behavior is fixture-proven.
- Quickshell owns `org.freedesktop.Notifications`; Awesome retains only local
  error reporting through `naughty.core`.
- Device writes are enabled by default but the unavailable hardware-specific
  paths listed above remain explicitly unexercised. Destructive session actions
  still require exact confirmation and separate live authorization.
- OS package removal remains optional; installed but unused legacy binaries do
  not constitute an active runtime path.
