# AwesomeWM → Quickshell Revamp

This directory tracks the planning and research for revamping the servalws
window-manager stack: fixing the current AwesomeWM/Polybar/Rofi setup, then
migrating the bar, control panel, launcher, and notifications to Quickshell
while keeping AwesomeWM as the window manager (X11, not Wayland).

## Contents

- `findings.md` — full assessment of the AwesomeWM/Polybar/Rofi/Picom/Dunst
  setup as it stood before this revamp: visual issues, functional bugs, dead
  weight, and what was fixed vs. deferred. All fixes described here are
  live and confirmed on servalws.
- `quickshell-research.md` — deep research on Quickshell compatibility with
  AwesomeWM + Xorg, a catalog of community shells/components to draw from,
  plain-English explanations of the building blocks, and hands-on X11
  compatibility tests performed on this machine (verified live, not just
  read about).
- `plan.md` — the architecture/build plan: component inventory, build
  order, integration map (what talks to what), and the rollout/cutover
  sequence for retiring Polybar/Rofi/Dunst safely.
- `decisions.md` — the options menu. Every surface (top bar, quick control
  panel, full control panel, launcher, quick-launch menu, notification
  center, lock screen, OSD) is broken down into lettered options with
  plain-English descriptions, awaiting your picks. This is the actual spec
  once filled in; `plan.md`'s structure will be finalized against it.
- `assets/` — reference screenshots downloaded for the research doc
  (Caelestia, DankMaterialShell; Noctalia's screenshot link was broken at
  fetch time — browse docs.noctalia.dev/v4 directly for that one).

## Reading order

If you're picking this up fresh: `findings.md` → `quickshell-research.md`
→ `plan.md` → `decisions.md` (the one that needs your answers).

## Status

**Fixes applied directly to the live AwesomeWM config, confirmed live
(2026-07-05):**
1. Workspace switching resynced across both monitors (single desktop
   model) — `keys.lua`.
2. Broken path/monitor-name bugs fixed (`quickshell_work` → `quickshell`,
   `HDMI-0` → `HDMI-1-0`, wallpaper mode consistency).
3. `theme-select`/`theme-apply` given a graceful failure message instead of
   a raw `ls` error, since the theme library isn't synced to this host.
4. `useless_gap` increased 50% (1 → 1.5) per request — live, awaiting your
   feel-check.

All four were confirmed live via an `awesome.restart()` performed later in
the session (see `findings.md` §"Live verification performed" for detail);
Polybar, Picom, and Dunst all survived that restart intact.

**Quickshell build itself has not started.** `quickshell-research.md`
documents live compatibility testing (a throwaway test bar was launched
against the real AwesomeWM/X11 session and cleaned up — never part of the
dotfiles repo), but no production Quickshell surfaces exist yet beyond the
pre-existing volume-OSD prototype in `quickshell/.config/shell.qml`.

**Current stage: awaiting your answers in `decisions.md`.** Once filled
in, those choices get folded back into `plan.md` as the finalized spec and
implementation starts at the top of `plan.md`'s build order (Theme
singleton → AwesomeWM bridge → OSD → Bar → Quick Panel → ...).

Not yet under git version control in this session (repo has no `.git` at
this checkout on servalws — see note in `findings.md`).
