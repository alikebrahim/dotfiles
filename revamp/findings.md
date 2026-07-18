# servalws AwesomeWM Setup — Findings & Fixes (2026-07-05)

Full assessment of the AwesomeWM + Polybar + Rofi + Picom + Dunst stack on
servalws, done before starting the Quickshell revamp. This is the baseline
the revamp works from.

Note on tooling: `~/.dotfiles` on servalws has no `.git` directory at this
checkout (confirmed via `git status` failing with "not a git repository").
The repo is synced here via Syncthing; git history lives on whichever host
currently holds the clone with `.git` (e.g. `~/.dotfiles_from_remote`, which
does have `origin` pointing at `git@github.com:alikebrahim/dotfiles.git`).
The edits below were made directly against the Syncthing-synced files on
servalws and will propagate to other hosts the normal way. They have not
been committed to git from this machine.

---

## 1. Functional: duplicated/desynced workspaces (root cause + fix)

**Symptom:** Polybar's workspace module showed `1 2 3 4 5 1 2 3 4 5` instead
of a single `1 2 3 4 5`, and switching workspaces on one monitor didn't
switch the other.

**Root cause:** AwesomeWM ties tags (workspaces) to a single screen — there
is no built-in "one workspace spans all monitors" concept the way
GNOME/Pop!_OS/KDE model it. `rc.lua` creates 5 tags *per screen*, so with two
monitors you get 10 independent EWMH desktops (confirmed via
`xprop -root _NET_NUMBER_OF_DESKTOPS` → `10`). `keys.lua` already had a
partial workaround (`Ctrl+j/k` stepping every screen's tag in lockstep), but
the primary `Super+1..5` keys only called `view_only()` on the *focused*
screen — so a single `Super+3` press while focused on screen 1 would desync
the two screens permanently (screen 1 → tag 3, screen 2 unchanged), and the
"synced" `Ctrl+j/k` keys would then just advance both screens from their
now-mismatched positions.

**Fix applied** (`awesome/.config/awesome/keys.lua`):
- Added `view_tag_index_all_screens(index)`, which calls `tag:view_only()`
  on the same tag index on every screen at once.
- `Super+1..5` now calls this helper instead of only touching
  `awful.screen.focused()`. Viewing a workspace now always syncs both
  monitors — matching Pop!_OS/GNOME-style behavior.
- `Super+Shift+K` / `Super+Shift+J` ("move client to next/prev workspace and
  follow") now also re-syncs both screens to the destination tag index after
  moving the client, instead of only calling `view_only()` on the client's
  own screen.
- `Super+Shift+1..5` ("move focused client to workspace N") was left
  unchanged — it only affects the focused client's own screen, which is
  correct since a client can only live on one screen's tag list.

**Not fixed as part of this pass:** Polybar's `internal/xworkspaces` module
still queries the raw EWMH desktop list, so it will keep rendering all 10
labels (`1 2 3 4 5 1 2 3 4 5`) even with perfect sync — the module has no
concept of "collapse per-monitor duplicates into one set." Fixing the
*display* requires either a Polybar scripting workaround or, more likely,
a custom Quickshell workspace widget that talks to AwesomeWM directly and
renders 5 shared labels. Tracked as a Quickshell bar requirement in
`quickshell-research.md`.

Validated with `awesome -k` (syntax OK) after the edit.

---

## 2. Functional: broken paths and inconsistent scripts (fixed)

Four small but real bugs, all fixed directly:

1. **`polybar/.config/polybar/launch.sh`** — `PREFERRED_MONITOR="HDMI-0"`
   never matched the live output name `HDMI-1-0` (confirmed via
   `xrandr --query`). The script silently fell through to its "connected
   primary" fallback, which happened to produce the right monitor by
   coincidence. Fixed to `HDMI-1-0`.
2. **`awesomewm-bin/theme-apply`** — wrote Quickshell theme tokens to
   `$HOME/.dotfiles/quickshell_work/.config/theme_tokens.json`, but the real
   package directory is `quickshell` (no `_work` suffix). Fixed the path.
3. **`awesome_wm_scripts/.config/scripts/quickshell-osd-volume.sh`** — same
   `quickshell_work` vs `quickshell` typo, pointing at a `shell.qml` that
   doesn't exist. Fixed the path. (This script is currently unreferenced by
   any keybind/hook — see "dead weight" below — so the bug was latent, but
   worth fixing before it's wired up.)
4. **Wallpaper mode inconsistency** — `rc.lua`'s autostart used
   `feh --bg-center`, while `awesome_wm_scripts/.config/scripts/wm-stabilize.sh`
   (fired on `Super+U` or after a monitor hotplug) used `feh --bg-fill`. Same
   image, two different crop/scale behaviors depending which path ran last.
   Standardized both on `--bg-center`.

---

## 3. Functional: theme-select/theme-apply had no graceful failure (fixed)

`awesomewm-bin/theme-select` (bound to `Super+Ctrl+T`) did a bare
`ls ~/.dotfiles/themes/library`, but that directory doesn't exist on this
host — the `themes` Stow package is intentionally excluded from fleet-wide
sync (per `AGENTS.md`: "too large for the shared dotfiles sync folder").
Pressing the keybind produced a raw `ls: cannot access ...` error with no
user-facing feedback.

**Fix applied:** `theme-select` now checks for the library directory (and
for it being non-empty) before invoking Rofi, and shows a `notify-send`
critical alert explaining *why* it failed (host has no theme library synced)
instead of leaking a shell error. It exits cleanly either way.

This does not create a theme library — it only makes the existing gap
visible and non-broken. Whether to build/sync a real theme library for this
host, or retire the theme-switcher keybind while it's unusable, is still an
open decision (see "Open decisions" below).

---

## 4. Visual: tiling gap increased 50% per request (applied, pending feel-check)

`theme.useless_gap` was `1` (Blender-tight — deliberately minimal per your
stated preference, but part of what read as "a little off"). Increased to
`1.5` (50% up) in `awesome/.config/awesome/theme.lua`, per your instruction
to test a moderate bump rather than guess at a bigger jump. Live-reload via
`Super+Shift+R` (or restart) to feel it; report back and we can tune further.

Not touched in this pass (still on the table): the low-contrast unfocused
border color (`#475258` on `#2d353b` background) that makes multiple tiled
windows on one screen hard to visually separate. That's a bigger visual call
than the gap and is being held for after you've felt the gap change.

---

## 5. Visual: Polybar dead space / duplicate workspace labels (documented, not fixed here)

Confirmed via cropped screenshots and vision inspection: there's a large
unused gap in the center of the bar between the (duplicated) workspace
group and the date module — no window-title widget or anything else fills
it. This is cosmetic and Polybar-specific; since Polybar is being replaced by
Quickshell, it wasn't worth patching Polybar's layout for a component on its
way out. The Quickshell bar plan in `quickshell-research.md` accounts for
this (see "what the new bar should NOT inherit").

---

## Dead weight / cleanup candidates (documented, left alone)

Per repo rules, nothing was deleted without explicit instruction. Recorded
here for a future decision:

- **Orphaned scripts** (present, executable, not referenced by any keybind
  or Polybar module, per `scripts/check-wm-servalws.sh`'s own diagnostic):
  `awesome-dump-state.sh`, `screenshot-quick.sh`, `wm-health.sh`,
  `quickshell-osd-volume.sh`. These look like manual-use diagnostic/utility
  tools rather than mistakes — worth a keep/prune decision, not urgent.
- **Vendored `bling`** (40 Lua files under `awesome/.config/awesome/vendor/bling/`)
  is used for exactly one feature: the scratchpad module
  (`dynamism.lua`). `window_switcher`, `task_preview`, `tag_preview`,
  `flash_focus`, `tabbed`, and `window_swallowing` are all vendored but
  unused; `flash_focus` and `window_swallowing` are explicitly commented out
  in `dynamism.lua` due to past NVIDIA screen-corruption issues. A lot of
  carried weight for one feature, but removing/trimming vendored code is a
  separate decision from this pass.

---

## Live verification performed

- `awesome -k` from `~/.config/awesome`: syntax OK, both before and after
  edits.
- `awesome-client` used throughout to inspect live screen/tag/workarea
  state and confirm the workspace-sync root cause.
- `xrandr --query`, `xprop -root`, and `awesome-client` cross-checked to
  confirm the `HDMI-1-0` vs `HDMI-0` mismatch and the 10-desktop EWMH state.
- `awesome.restart()` was later triggered during the Quickshell
  compatibility testing in `quickshell-research.md` (to clear a stale
  workarea left over from a throwaway test bar). That restart picked up
  all the Lua edits above cleanly — confirmed via `awesome -k`,
  `awesome-client` screen/tag/workarea queries, and a check that all
  clients, tags, and running WM processes (picom/dunst/polybar) survived
  the restart intact. So as of the end of this session, all four fixes
  (workspace sync, path bugs, theme-select fallback, gap increase) are
  live and confirmed, not just written to disk.
