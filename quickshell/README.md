# Quickshell Work Area

This directory holds the AwesomeWM/X11-native Quickshell companion shell
that replaces Polybar, Rofi, and Dunst. See `../revamp/decisions.md` for
the full spec this was built against, and `../revamp/plan.md` for the
build plan/order.

- `.config/quickshell/` is the active implementation (stowed to
  `~/.config/quickshell/`).
- `reference-dms/` preserves an earlier DankMaterialShell-based attempt
  for reference only — do not port it wholesale.
- **Do not autostart Quickshell or replace Polybar/Rofi/Dunst** until the
  integration phase is explicitly authorized. See
  `../revamp/switch-to-quickshell.sh` for the (inert, non-executing)
  cutover checklist.

## Status: modular system complete, smoke-tested

Every surface described in `decisions.md` has been built and smoke-tested
on Xvfb (headless virtual X server, `:99`, 2026-07-06). **Six real bugs
were found and fixed during testing** (see `../revamp/plan.md` Section 8
for the full list). Seven surfaces + bridge simulation + lock screen all
pass cold-start with zero scene warnings. AwesomeWM's own config has not
been touched — Polybar/Rofi/Dunst are still the live system.

## Entry points

- `shell.qml` — main shell process. Loads Theme, BridgeState, and every
  surface below except Notifications (kept inert, see below).
- `lock.qml` — **separate** process, loads only `LockScreen.qml`. Not
  imported by `shell.qml` on purpose (see that file's header comment).

## Surfaces (all under `modules/`)

| Module | Trigger (planned) | Status |
|---|---|---|
| `OSD/OSD.qml` | automatic (volume changes) | Built. Preserves the exact IPC contract `quickshell-osd-volume.sh` already depends on. |
| `Bar/Bar.qml` | always visible | Built. Primary-monitor-only (`decisions.md` §6), tag indicator degrades to a placeholder until the bridge is wired in. |
| `QuickPanel/QuickPanel.qml` | Mod+Shift+A / bar click | Built. 2x2 tile grid: volume, network (placeholder), bluetooth, power. |
| `Launcher/Launcher.qml` | Mod+Space | Built. App search (`.desktop` via `DesktopEntries`) + inline calculator. Center-modal/bottom-sprout styles both implemented, switch via IPC (`launcher setStyle`). |
| `Launcher/WindowSwitcher.qml` | Mod+Tab | Built. Lists open windows from `BridgeState`; `activateSelected()` is a documented no-op stub until AwesomeWM has a command-listener, not just a state-writer. |
| `FullPanel/FullPanel.qml` | Mod+Shift+Space (conflict, see below) | Built. All 11 sections from `decisions.md` §5: Overview, Audio, Network, Bluetooth, Power, Display/Brightness, Theme, Notifications, AwesomeWM/Workspace, Keybinds, Calendar. Simple sections are fully functional; complex ones (Audio mixer, Network list, Bluetooth pairing) have working-but-simplified content with explicit `TODO(integration)` markers. |
| `QuickApps/QuickApps.qml` | Mod+Shift+Space (conflict, see below) | Built. All three layouts (grid/radial/hex) implemented, switchable via `quickapps-settings.json` or IPC. Pinned apps read from `quickapps.json`. |
| `LockScreen/LockScreen.qml` | via `lock.qml`, separate process | Built. PAM-based auth (`Quickshell.Services.Pam`), PAM service name `"login"` is an educated guess, not verified against this host's actual PAM stack. |
| `Notifications/Toast.qml`, `NotificationCenter.qml` | Mod+N (center) / automatic (toast) | Built but **inert** — see below. |

## Services (`services/`, registered as singletons via `services/qmldir`)

- `Theme.qml` — reads `theme_tokens.json` (same file already used by
  Polybar/Rofi theming today).
- `BridgeState.qml` — reads `$XDG_RUNTIME_DIR/awesome-bridge-state.json`,
  written by `awesome-integration/bridge.lua`. Degrades gracefully
  (`connected: false`, empty data) until that bridge is actually wired
  into AwesomeWM's `rc.lua` — which has NOT happened.
- `Notifications.qml` — exists, fully written, but **deliberately not
  registered in `qmldir`**. Registering it and starting its
  `NotificationServer` would fight Dunst for the notifications D-Bus
  name. Do not add it back to `qmldir` or import it into `shell.qml`
  without removing Dunst's autostart line in the same step (see
  `switch-to-quickshell.sh` step 3).

## AwesomeWM-side files (also inert)

- `awesome-integration/bridge.lua` — hand-built JSON state writer
  (tag/focus/per-client info). Lives here, not in the `awesome` stow
  package, specifically so it cannot accidentally get symlinked into
  `~/.config/awesome/` and loaded by `rc.lua` before integration is
  authorized. A prior session incident happened exactly this way — see
  `../revamp/ambiguities.md`.

## Known open items requiring your decision

1. **`Mod+Shift+Space` collision** — both the Full Control Panel and the
   Quick Apps menu want this key (per `decisions.md` §5 and §8
   respectively). Not resolved; flagged in `switch-to-quickshell.sh` step
   5 and must be settled before integration.
2. **Lock-backend persistence** — `FullPanel.qml`'s AwesomeWM/Workspace
   card has a cosmetic i3lock/Quickshell toggle that does not yet persist
   to `lock-settings.json`. Wiring that (plus the actual wrapper script
   xss-lock would call) is deferred to integration.
3. **PAM service name** (`LockScreen.qml`) — `"login"` is unverified
   against this host's PAM configuration.

## What integration will require

See `../revamp/switch-to-quickshell.sh` — a documentation stub (exits
non-zero, does nothing) listing the exact atomic steps needed. It is not
authorized to run and should not be executed without explicit
instruction.
