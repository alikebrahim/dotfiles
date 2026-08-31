# Quickshell desktop shell

This is the Quickshell layer for this AwesomeWM/X11 desktop. The end state is
one Quickshell-owned visual system for the bar, status/control panels,
launchers, window selection, session actions, and notifications.

## Current state — 2026-07-28

Quickshell 0.3.0 is permanently integrated with AwesomeWM and currently owns:

- the continuous 26px primary-output bar;
- synchronized Awesome tags, focused-client title, and centered
  `date - time - weather` block;
- a resident bounded StatusNotifier tray plus Bluetooth, network, audio,
  display, and power status;
- native notification toasts/history, a reduced Tailscale panel, MPRIS media,
  and an explicit-location weather pill/panel;
- one keyboard-navigable controls popup;
- a live, accepted Mod+Tab window switcher, Mod+Space application launcher, and
  guarded Mod+Escape session menu;
- a live, accepted centered-clock calendar with bar-popout coordination;
- a live, accepted searchable Mod+S keybind-help modal sourced from Awesome's
  active hotkey metadata;
- a confirmed four-profile display manager implemented in source behind the
  native mutation gate;
- volume, microphone, and brightness OSD surfaces;
- output-aware placement through the Awesome bridge;
- Alt+Space bar visibility through Quickshell IPC.

The live output contract is:

- internal `eDP-1-1`: left at `x=0`, secondary;
- external `HDMI-0`: right at `x=1920`, primary and bar owner.

Native device/system mutations are disabled by default. Quickshell owns the
notification D-Bus name; Dunst is masked. Future Awesome starts no longer load
the native Pillbar, while its source remains dormant and undeleted. Rofi remains
the explicit fallback for accepted searchable/session/display routes and retains
direct device-menu bindings where live write acceptance is incomplete.

## Current implementation boundary

The shell consolidation batches are implemented through weather. Notifications
are live under Quickshell, Tailscale is accepted read-only, and weather passes
explicit-location, persistence, stale/offline, popup, and 1280/1920 fixture
checks. Production weather is live for Hamad Town, Bahrain, with current
conditions, five forecast days, and verified host-local state. Pillbar
retirement is live accepted: the normal Awesome reload preserved topology and
the Alt+Space Quickshell route.

## Documents

- `docs/project-status.md` — implemented features, live ownership, boundaries,
  and known issues.
- `docs/consolidation-plan.md` — phased Rofi/Naughty/Pillbar consolidation plan.
- `docs/live-canary-and-rollback.md` — current live integration, health checks,
  mutation gate, and recovery boundary.
- `docs/visual-proof/README.md` — historical isolated visual milestone.

## Operating boundary

Source edits, live activation, Awesome reloads, display changes, and destructive
session actions are separate scopes. Routine development uses the smallest
native syntax check plus live rendering and user visual acceptance; the old
Xvfb harness is not a default development gate.
