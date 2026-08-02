# Quickshell-only operations and recovery

Quickshell is a permanent part of the AwesomeWM session. Awesome loads the
canonical heartbeat bridge, starts one exact selected-config Quickshell process,
and routes every shell key action through one bounded controller. There is no
Rofi, Dunst, Polybar, or Pillbar runtime fallback.

Saving these source files does not authorize an Awesome reload. A normal reload
re-runs `x11-monitor-setup.sh`, which performs a live two-pass RandR mutation.

## Current state

- Quickshell and `awesome-integration/bridge.lua` start unconditionally.
- External `HDMI-0` is right/primary and owns the bar; internal `eDP-1-1`
  is left/secondary.
- Quickshell starts with `QUICKSHELL_ENABLE_MUTATIONS=1` unless the private
  per-login `safe-mode` marker exists. The fixed display-profile service keeps
  its separate token/confirmation boundary.
- Awesome workspace/tag actions use a second scoped capability. It can only
  dispatch static Awesome workspace programs and cannot reach device services.
- Pillbar, Rofi, Polybar, Dunst, and the retired mixed helpers exist only in
  top-level `*-archived` reference directories and are not active recovery paths.
- Quickshell owns the session's `org.kde.StatusNotifierWatcher` name. The tray is
  resident on the primary bar and collapses while no active item is registered.
- Every shell action first calls typed IPC on `~/.config/quickshell`. On failure,
  the controller checks only that selected config, starts it only when absent,
  retries once, and reports an Awesome-local error otherwise.
- The bridge publishes only
  `${XDG_RUNTIME_DIR}/quickshell-awesome/state.json`, with a two-second heartbeat
  and opaque generation. Quickshell disables workspace/window actions when the
  producer becomes stale.
- Quickshell owns all accepted searchable/modal and direct control routes plus
  notifications; Awesome loads only `naughty.core` for local errors.

## Health checks

```text
quickshell --path ~/.config/quickshell ipc call shell ping
quickshell --path ~/.config/quickshell ipc call shell status
quickshell --path ~/.config/quickshell ipc call bar status
quickshell --path ~/.config/quickshell ipc call controls status
quickshell --path ~/.config/quickshell ipc call notifications status
busctl --user --no-pager status org.freedesktop.Notifications
busctl --user --no-pager status org.kde.StatusNotifierWatcher
busctl --user get-property org.kde.StatusNotifierWatcher /StatusNotifierWatcher org.kde.StatusNotifierWatcher RegisteredStatusNotifierItems
xrandr --listmonitors
```

Expected essentials: shell ping `ok`, resident/ready true, `bridgeReady:true`,
`bridgeStale:false`, a nonempty `bridgeGeneration`, bounded `bridgeAgeMs`,
`nativeMutationsEnabled:true`, `workspaceMutationsEnabled:true`,
`workspaceSynchronized:true`, `dbusOwnershipHealthy:true`, `HDMI-0`
primary at `+1920+0`, `eDP-1-1` at `+0+0`, `trayReady:true`, and one
Quickshell-owned StatusNotifier watcher. A healthy empty tray reports zero active,
direct, and overflow items.

## Live behavior to observe

- Quickshell bar appears on the primary monitor (26px, translucent).
- Awesome has been normally reloaded and no Pillbar instance is loaded.
- Tags and focused-title update in real time.
- Super+Ctrl+J/K select the previous/lower and next/higher workspace on both
  outputs; adding Shift moves the focused client and follows globally. Both
  directions wrap across workspaces 1–5.
- The selected tag indicator is identical on both outputs and matches
  `workspaceIndex`; ordinary application clients do not remain sticky.
- Control popouts and global modals close with Escape. After a focusable surface
  has opened normally, clicking inside another application closes it immediately
  without the X11 fade/restack flash.
- Registered StatusNotifier items appear immediately before the fixed Bluetooth,
  network, audio, display, and power controls. The tray disappears while empty;
  it has no separate bar or permanent placeholder.
- Right-click tray menus and drill-in submenus use one coordinated popout. More
  than five active items retain four direct slots plus one overflow affordance.
- The bar reserves 26px only on the external primary output while visible.
- No new relevant QML error appears in the normal live-reload output.

## Recovery boundary

If Quickshell IPC fails, the requested key route starts the selected config only
when no selected instance exists; it never kills or duplicates a resident
instance and never launches an archived UI. Stopping Quickshell or reloading
Awesome are live operations requiring separate approval; an Awesome reload also
reapplies the monitor layout. Dormant package source is not a runtime rollback.

Do not claim full rollback from deleting a marker or killing a process: the
unconditional startup path will start Quickshell again on the next Awesome
reload or login. A durable rollback is an explicit source change with a reviewed
activation plan. Reinstating a future `*-archived` package additionally requires
profile/catalog registration and a separately approved Stow plan/apply.

## Native control safe mode

Quickshell mutations (volume, Wi-Fi, Bluetooth, power profile, and brightness)
are enabled by default. Awesome disables them for the next selected-config start
only when this private per-login marker exists:

```
${XDG_RUNTIME_DIR}/quickshell-awesome/safe-mode
```

Creating/removing the marker does not alter the environment of the already
running process. Activation therefore requires a separately approved process
restart. Safe mode is a Quickshell-only read-only recovery boundary; it never
launches an archived UI. The accepted production state has the marker absent and
reports `nativeMutationsEnabled:true`.

The display manager is an explicit exception: its own `CommandTransport`
instance is wired only to `DisplayService`, which accepts four fixed profile
tokens and requires two-step confirmation. This does not grant display
permission to any other service and does not change the general marker state.

Workspace focus and activation are also explicit exceptions. Their dedicated
`CommandTransport` is wired only to `AwesomeActionService`, whose programs accept
validated numeric tag/window identifiers and call the shared Awesome workspace
coordinator. This does not enable audio, network, Bluetooth, brightness,
power-profile, display-profile, or session mutations.

Only the canonical environment, X11 identity, safe-mode marker, and bridge path
are supported. The previous runtime state and opt-in mutation marker are retired.
