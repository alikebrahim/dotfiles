# Quickshell-only AwesomeWM migration plan

> Historical plan and current execution record. This is the canonical project copy; Quickshell records belong under `quickshell/docs/`, not `.hermes/`. Remaining source, live, deployment, device, session, package-manager, Git, and Syncthing operations retain the approval boundaries defined below.

**Prepared:** 2026-07-29  
**Last updated:** 2026-07-30  
**Evidence:** `quickshell/docs/implementation-audit-2026-07-29.md` and current source/runtime inspection  
**Target:** AwesomeWM remains the X11 window manager; Quickshell becomes the only bar, launcher, switcher, notification server, tray host, settings UI, display UI, and session UI.

## Execution status at completion

- Waves 1–8 are complete in source, deployment, and accepted live state.
- The generic fixed-profile display backend remains independent of Rofi; no real
  display profile was applied during completion.
- All nine Awesome shell routes use one exact selected-config Quickshell
  controller, with no Rofi, Dunst, Polybar, or archived runtime fallback.
- Bridge heartbeat/generation freshness and independent PID-attested D-Bus
  ownership are healthy after the final normal Awesome restart and selected
  Quickshell restart.
- General native controls default enabled. The per-login `safe-mode` marker is
  absent and the accepted process reports `nativeMutationsEnabled:true`.
- Reliability/accessibility work is complete: result-bearing session execution,
  clipboard timeout cleanup, deterministic screen fallback, checked icon
  fallback, accessible compact controls, and 4.5:1 small-text contrast.
- Rofi, Polybar, Dunst, Pillbar, and retired mixed helpers are absent from active
  profile/catalog/live paths and retained only under explicit `*-archived`
  reference directories.
- The current `awesome`, `quickshell`, and `awesome_wm_scripts` packages report
  `CURRENT`; Quickshell manages 80 deployable paths, with docs/tests intentionally
  excluded by `.stow-local-ignore`.
- No destructive session action or unaccepted hardware-specific device path was
  exercised during completion. OS package removal remains optional.

## Post-completion restart handoff — 2026-07-30

- Notification cutover remains operational: the selected Quickshell process
  currently owns `org.freedesktop.Notifications`, with no active popup or service
  error. Dunst and Awesome Naughty D-Bus ownership remain retired.
- A broken Flameshot 14 portal capture generated three real error notifications per
  Print Screen attempt. Ten traced attempts produced thirty history entries; the
  entries expired in five-second clusters without sender close requests.
- This exposed two bounded Quickshell follow-ups: automatic toast expiry must not
  mark a history row seen, and the shared toast window must map only after layout
  settles and remain geometrically stable through a burst. The detailed pending
  scope is Batch 13A in `consolidation-plan.md`.
- Print Screen itself requires the upstream X11 fallback
  `useX11LegacyScreenshot=true` in host-local `~/.config/flameshot/flameshot.ini`
  because the installed desktop-portal user service is dependency-failed. No
  Flameshot, QML, service, or fixture source was changed during assessment.
- The Picom Quickshell animation override and three-pill power-profile UI are live
  and visually accepted. They are not part of the pending notification repair.

## Recommendation

Finish the migration in controlled waves rather than deleting the old stack first:

1. Make Quickshell recovery config-aware and remove every active Rofi fallback.
2. Fix the Medium reliability findings and the stale regression before enabling writes permanently.
3. Exercise existing fixture coverage, then perform separately approved, reversible live acceptance for the general controls.
4. Make Quickshell controls enabled by default, while retaining a Quickshell-only emergency read-only mode.
5. Prune the three old Stow packages from the live host while their catalog entries still exist.
6. Rename each retired source package to `<package>-archived`, remove its catalog registration, and restow only the new stack.

This order avoids broken live symlinks, preserves a recovery path during acceptance, and prevents the Rofi-named display script from being removed while Quickshell still uses its noninteractive backend.

## Final decisions encoded by this plan

- No runtime or keybinding fallback may launch Rofi, Dunst, or Polybar.
- Quickshell is required, not optional. If its IPC fails, Awesome starts the exact configured shell and retries; it does not open a legacy UI.
- The five system-control icons—audio, network, Bluetooth, brightness, and power profile—are writable by default after acceptance.
- Tailscale is writable through its existing bounded service, but live disconnect/exit-node tests remain opt-in because they can disrupt connectivity.
- Media, tags, tray items, notifications, weather, calendar, and modal launchers remain functional through their current native/IPC paths.
- Display changes keep their separate fixed-profile, two-confirmation capability.
- Session actions keep fixed argv mappings and confirmation, but execution must report whether systemd/Awesome accepted the request.
- `naughty.core` remains for Awesome internal errors. `naughty.dbus` remains unloaded; this does not reintroduce Dunst.
- Old source is archived as reference, not kept in an active Stow package.
- OS package uninstall is not part of the required migration. Installed but unused binaries may be removed later under separate package-manager approval.
- The audit report remains unchanged as historical evidence.

## Target architecture

### AwesomeWM responsibilities

- X11 client management, rules, layouts, tags, focus, and key registration.
- Publishing bounded desktop state to Quickshell.
- A single Quickshell controller that:
  - selects `~/.config/quickshell` explicitly;
  - detects only instances of that selected configuration;
  - starts that exact configuration when absent;
  - retries one failed IPC request after bounded startup;
  - reports failure through Awesome internal notification/logging;
  - never invokes Rofi.
- No bar, notification server, tray, launcher, switcher, settings panel, or session menu implemented by Awesome.

### Quickshell responsibilities

- Primary bar and exclusive workarea.
- Launcher, switcher, keybind help, calendar, display manager, session menu, controls popup, OSD, notifications, and tray.
- Native PipeWire, NetworkManager, BlueZ, MPRIS, weather, and StatusNotifier integrations.
- Bounded command-backed brightness, Tuned profile, Tailscale, display, clipboard, D-Bus ownership, and session boundaries.

### Archived responsibilities

The following become documentation/reference only:

- `rofi-archived/`, `polybar-archived/`, and `dunst-archived/` preserve the retired Stow package trees.
- `awesome_wm_scripts-archived/` preserves the retired `rofi-*.sh` and `polybar-bluetooth-status.sh` helpers while the active `awesome_wm_scripts/` package keeps only current helpers.
- `awesome-pillbar-archived/` preserves the dormant Awesome native pillbar entry/theme/services/bar/popups/helpers.

Archive naming is strict: an archived configuration/package directory is renamed to `<package>-archived` at the repository root. Do not place archived configuration under a generic `archive/` or `docs/archive/` parent, and do not leave an unsuffixed duplicate.

Do not archive active monitor setup, session wrapper, screenshot, diagnostics, bridge, rules, tag, focus, or compositor code.

## Audit-finding crosswalk

| Finding | Planned resolution | Blocks cutover? |
|---|---|---:|
| F1 broad Quickshell detection/recovery | Central config-aware controller using `quickshell --path … list --json`, exact start, bounded IPC retry | Yes |
| F2 no bridge freshness | Producer timestamp plus heartbeat; Quickshell stale threshold and IPC health | Yes |
| F3 optimistic session actions | Fixed commands through a result-bearing transport; explicit failure and accepted-state UI | Yes |
| F4 weak D-Bus ownership health | Fixed `busctl --user status` probes compared with `Quickshell.processId` | Yes |
| F5 stale window rule regression | Assert canonical WM_CLASS/instance contract and remove old Quattro assumptions | Yes |
| F6 low muted/urgent contrast | Adjust palette to at least 4.5:1 at actual small text sizes | Yes |
| F7 deployed legacy stack/diagnostics | Prune, archive, unregister, and rewrite health scripts | Yes |
| F8 fixed scale/compact targets | Keep 26px desktop bar; add accessible roles/minimum mouse targets. Park broad scaling until hardware requires it | No |
| F9 inconsistent output fallback | Use focused → primary → first valid output consistently; never blind `screens[0]` | Yes |
| F10 launcher icon warning | Validate theme icon before binding and use generic executable fallback | No |
| F11 unbounded clipboard process | Add timeout, TERM/KILL cleanup, and visible error | No |

## Wave 0 — freeze the acceptance contract

Read-only/source checks only:

1. Record current Quickshell selected-config instance, live IPC status, D-Bus owners, workarea, display topology, and mutation-gate state.
2. Run the currently passing checks:
   - `awesome -k` from `awesome/.config/awesome`;
   - `bash -n` for active and legacy shell helpers;
   - `bridge-lua-test.lua`;
   - `workspace-sync-lua-test.lua`;
   - Python AST parse of `quickshell/tests/run-awesome-xvfb.py`.
3. Record `awesome-quickshell-window-test.lua` as the expected baseline failure at its old bare-name assertion.
4. Do not run Xvfb, open shell surfaces, inject keys, or mutate hardware in this wave.

Exit: baseline evidence is captured and no live state changed.

## Wave 1 — sever the Rofi display backend dependency

The display service currently executes `rofi-display-manager.sh --apply`. Preserve the safe backend before archiving the UI wrapper.

Files:

- Add `awesome_wm_scripts/.config/scripts/x11-display-profile.sh`.
- Update `quickshell/.config/quickshell/services/DisplayService.qml`.
- Add/update a focused shell test under `quickshell/tests/` only if needed to exercise profile token rejection and representative `xrandr` output.

Tasks:

1. Extract only the four allowlisted `--apply` profiles, output preflight, RandR verification, and wallpaper restoration from the Rofi script.
2. The new backend must accept exactly `dual`, `external`, `laptop`, or `mirror`; no interactive mode and no Rofi dependency.
3. Keep argv-safe execution and current post-apply geometry checks.
4. Deploy the new helper before changing `DisplayService.backendPath`, unless current Stow folding proves it is already visible.
5. Point `DisplayService` at the generic helper and rerun fixture/static checks.
6. Do not apply a real display profile without separate hardware-mutation approval.

Exit: no production Quickshell path references a Rofi-named script.

## Wave 2 — make Awesome Quickshell-only

Files:

- Add `awesome/.config/awesome/lib/quickshell_control.lua`.
- Update `awesome/.config/awesome/rc.lua`.
- Update `awesome/.config/awesome/keys.lua`.
- Update focused Lua/deployment tests.

Controller contract:

1. Build one canonical command for `/usr/sbin/quickshell --path $HOME/.config/quickshell`.
2. Detect the selected configuration with `quickshell --path … list --json`; never use broad `pgrep` as proof.
3. For an action: call IPC, inspect the selected-config instance on failure, start only if absent, then retry once after a bounded delay.
4. If an instance exists but IPC remains unhealthy, report the failure and do not spawn a duplicate or kill anything.
5. Default production startup sets native mutations enabled.
6. A canonical per-login `safe-mode` marker may disable general writes for the next exact-config start. It is an emergency Quickshell-only rollback, not a legacy fallback.
7. Use only the canonical `quickshell-shell` X11 identity and `QUICKSHELL_ENABLE_MUTATIONS` environment. Remove `quattro-quickshell`, `QUATTRO_ENABLE_MUTATIONS`, and `quattro-awesome` marker aliases once the canonical controller tests pass.

Key routing:

- Mod+Space → Quickshell application launcher.
- Mod+Tab → Quickshell window switcher.
- Mod+S → Quickshell keybind help.
- Mod+Escape → Quickshell session menu.
- Mod+P → Quickshell display manager.
- Mod+Shift+A/W/B → matching Quickshell audio/network/Bluetooth control.
- Alt+Space → Quickshell bar visibility.

Remove from active `keys.lua` defaults and `rc.lua` callbacks every spawn of `rofi`, `rofi-*.sh`, Polybar, or Dunst. Unavailable Quickshell must produce a bounded error, not an old UI.

Exit: first-party active Awesome code invokes Quickshell only for desktop-shell functions.

## Wave 3 — reliability fixes before permanent activation

### 3A. Bridge liveness (F2)

Files: `awesome/.config/awesome/lib/quickshell_bridge.lua`, `services/AwesomeBridge.qml`, `shell.qml`, bridge tests.

- Publish a canonical producer timestamp and monotonic revision.
- Add one low-frequency heartbeat using the bridge's existing atomic writer.
- Expose `stale`, `ageMs`, and last-good revision in Quickshell.
- Retain last-good display data while stale, but disable tag/window actions and show unhealthy IPC status.
- Stop the heartbeat in bridge teardown.
- Remove the legacy bridge path only after a live canonical path has passed acceptance.

### 3B. D-Bus ownership truth (F4)

Add `services/DbusOwnershipService.qml` or equivalent narrow service.

- Run fixed, read-only `busctl --user --no-pager status` requests for Notifications and StatusNotifierWatcher.
- Parse only `PID=<integer>`.
- Compare with `Quickshell.processId`.
- IPC status must distinguish component loaded, bus owned by this process, owned elsewhere, and no owner.
- Test matching PID, foreign PID, malformed output, and no-owner responses with fixtures.
- Once real ownership is observable, remove the obsolete notification activation-marker/`ownershipLatched` compatibility path; Quickshell is permanently authoritative and `keepOnReload` remains the reload mechanism.

### 3C. Session results (F3)

Files: `services/SessionActionService.qml`, `modules/power/SessionMenu.qml`, `shell.qml`, a new focused fixture test.

- Replace `execDetached` optimism with a dedicated serialized transport.
- Keep only fixed actions and exact confirmation.
- Use result-bearing commands; for systemd actions prefer `systemctl --no-block` so success means the request was accepted without hanging through suspend.
- Keep the menu open on immediate failure and display the error.
- Never live-test logout, suspend, reboot, or poweroff as part of migration validation.

### 3D. Output selection (F9)

Files: launcher, switcher, session menu, and any other modal using `Quickshell.screens[0]`.

Use one policy everywhere: valid focused bridge output → valid primary output → first valid Quickshell output → unavailable. Clamp each modal to the selected screen's available geometry.

### 3E. Clipboard timeout (F11)

File: `services/X11ClipboardService.qml` plus focused fixture/static coverage.

- Add a short timeout.
- TERM, then KILL after a grace interval if needed.
- Always clear queued text and busy state.
- Report timeout distinctly from nonzero exit.

Exit: the nonvisual reliability findings have source fixes and focused tests; contrast is completed in Wave 4 and the repaired rule test runs in Wave 5.

## Wave 4 — UI/accessibility cleanup

Files: `style/Palette.qml`, `style/Metrics.qml`, launcher icon delegate, and custom interactive controls.

1. Recalculate muted and urgent text contrast against actual panel/background colors; require at least 4.5:1 for 10–12px text.
2. Preserve the existing visual character while changing only the minimum necessary palette tokens.
3. Use checked icon resolution (`hasThemeIcon` or `iconPath(..., true)`) before binding a desktop-entry icon; fall back to `application-x-executable` without a warning.
4. Add accessible names/roles and a practical minimum desktop mouse target to custom buttons.
5. Keep the current 26px bar. Do not introduce broad responsive-layout infrastructure in this migration.
6. Treat configurable UI scale as parked follow-up unless a second DPI target is provided.

Exit: contrast math passes and retained fixture screenshots show no clipping/regression.

## Wave 5 — test and fixture gate

Run before live activation:

1. Pure Lua tests, including repaired `awesome-quickshell-window-test.lua`.
2. Control service fixtures with mutations enabled and disabled.
3. Control UI fixture keyboard/pointer routing.
4. Bridge stale/fresh tests.
5. D-Bus owner parser tests.
6. Session command success/failure fixture tests.
7. Tailscale convergence tests.
8. `awesome -k` and `bash -n`.
9. Deployment/profile tests, rewritten to assert:
   - servalws includes Awesome and Quickshell;
   - servalws excludes Rofi, Dunst, and Polybar;
   - Awesome has no legacy fallback callback;
   - production Quickshell mutations default enabled;
   - dormant pillbar assertions are removed.
10. The private-D-Bus Xvfb harness only after separate process-test approval. It must not inherit the live session bus and must pass topology guards before mutable fixture setup.

No physical network, Bluetooth, display, power, Tailscale, or session state may change in this wave.

## Wave 6 — bounded live acceptance

Requires explicit approval for the listed operations. Enable the gate for one exact Quickshell process while Rofi source is still recoverable but not invoked.

Low-risk acceptance batch:

- Open every bar surface and confirm focus, keyboard traversal, dismissal, clipping, errors, and long labels.
- Audio: change by one 5% step, observe convergence, restore the exact starting level; test mute only if approved.
- Brightness: change by one 5% step and restore the exact starting value.
- Wi-Fi: toggle only if the live transport is not carrying the session and restoration is safe.
- Bluetooth: power/discovery start-stop and restore; pairing, forgetting, or disconnecting a real device requires a named device and separate approval.
- Power profile: switch once and restore the exact starting profile.
- Notifications: send one ordinary test notification; verify Quickshell ownership, toast, history, close, and DND.
- Launcher/switcher/tags/tray/media: exercise normal non-destructive actions.

Excluded unless separately approved:

- Tailscale down/up or exit-node changes.
- Any real display profile application.
- Network forget or a new credentialed connection.
- Bluetooth forget/pair against real hardware.
- Suspend, logout, reboot, or poweroff.

Exit: every generally enabled control either has a reversible live acceptance result or an explicit fixture-only residual-risk note.

## Wave 7 — permanent Quickshell-only cutover

Separate live activation approval is required.

1. Apply the final Awesome source with Quickshell-only callbacks.
2. Run `awesome -k` before reload.
3. Perform one normal Awesome reload; do not use `awesome --replace` on live `:0`.
4. Restart the selected Quickshell configuration once so its permanent mutation environment is applied.
5. Verify exact selected-config IPC, bridge freshness, D-Bus ownership, workarea, modals, and control `actionsEnabled` state.
6. Confirm no Rofi, Dunst, or Polybar process starts during recovery tests.
7. Exercise an IPC failure by targeting a nonexistent handler in a fixture or isolated environment; do not kill the accepted live shell merely to test recovery.

Exit: Awesome and Quickshell operate normally with no legacy runtime path.

## Wave 8 — detach, prune, archive, and redeploy

This sequence matters.

### 8A. Stop selecting old packages

Update:

- `scripts/profiles/servalws.conf` — remove `dunst`, `rofi`, `polybar`.
- Deployment tests — assert all three are excluded.

Keep the old package directories and catalog registrations temporarily so controlled prune can still address them.

### 8B. Review and prune live Stow links

Read-only preview first:

`bash scripts/configure-host.sh plan --scope stow`

Then, only with deployment approval, explicitly prune while packages are still registered:

`bash scripts/configure-host.sh prune --stow-package dunst --stow-package rofi --stow-package polybar`

Do not use `--adopt` or `--force`. Confirm `~/.config/dunst`, `~/.config/rofi`, and `~/.config/polybar` have neither real entries nor broken symlinks afterward.

### 8C. Rename source packages with the `-archived` suffix

Rename the complete retired package trees in place:

- `dunst/` → `dunst-archived/`;
- `rofi/` → `rofi-archived/`;
- `polybar/` → `polybar-archived/`.

Create package-shaped archives for retired source extracted from mixed active packages:

- `awesome_wm_scripts-archived/.config/scripts/` receives retired `rofi-*.sh` and `polybar-bluetooth-status.sh` helpers;
- `awesome-pillbar-archived/.config/awesome/` receives dormant pillbar entry/theme/services/bar/popups/helpers after a final dependency search proves active code does not require them.

Each `*-archived/` directory gets a README recording original paths, retirement date, dependencies, and restoration caveat. Archive source is reference-only and must not be registered, selected by a profile, sourced, executable through keybindings, or linked into `$HOME`. Update `scripts/lib/doctor.sh` so top-level `*-archived` directories are reported as archives rather than unregistered Stow packages, while still rejecting any catalog/profile reference to an archived name.

### 8D. Remove registrations and update diagnostics

Update:

- `scripts/lib/stow-catalog.sh` — remove the three retired package registrations.
- `scripts/check-wm-servalws.sh` — expected processes become Awesome, Quickshell, and Picom; add exact-config IPC, bridge freshness, D-Bus ownership, workarea, and selected-profile checks.
- `awesome_wm_scripts/.config/scripts/wm-health.sh`.
- `awesome_wm_scripts/.config/scripts/awesome-dump-state.sh`.
- `quickshell/docs/project-status.md`.
- Replace the canary guide with a Quickshell-only operations/rollback guide.

Historical reports and `*-archived/` READMEs may still contain legacy names. Active code, profile, catalog, and diagnostics may not.

### 8E. Restow only the new stack

Before restow, inspect target paths for real-file conflicts. Review a focused plan for `awesome`, `quickshell`, and `awesome_wm_scripts`; apply only under separate deployment approval. Verify active links resolve and no archived path is linked.

Exit: old config is absent from `$HOME`, present only in explicitly suffixed `*-archived/` directories, and absent from active package selection/catalog.

## Rollback model after retirement

Rollback no longer means launching Rofi/Dunst/Polybar.

- If device controls misbehave: create the documented per-login Quickshell safe-mode marker, restart only the selected Quickshell config, and keep read-only status surfaces.
- If one IPC handler fails: the Awesome controller retries exact-config startup once and reports the error.
- If the bridge is stale: preserve last-good presentation, disable Awesome mutations, and reload Awesome normally after source diagnosis.
- If Quickshell cannot start: use a terminal or Awesome internal command to start the exact config; do not restore archived UI automatically.
- Reinstating an archived package is a new migration requiring source move, catalog/profile registration, plan, Stow apply, and explicit approval.

## Final acceptance criteria

All must be true:

- `awesome -k` passes.
- Pure bridge/workspace/window-rule tests pass.
- Control, Tailscale, ownership, session, and UI fixtures pass.
- Approved Xvfb test passes, or its omission is recorded as residual risk.
- Active Awesome source contains no first-party Rofi, Dunst, Polybar, or pillbar launch path.
- Every shell-oriented key opens Quickshell or reports a bounded Quickshell error.
- The selected Quickshell config is the only bar/notification/tray authority.
- Notifications and StatusNotifierWatcher are owned by `Quickshell.processId`.
- Bridge state is fresh and becomes visibly stale when heartbeat stops.
- General controls are enabled by default; safe mode disables them after a selected-config restart.
- The exact original state is restored after every approved reversible hardware test.
- Dunst, Rofi, and Polybar are absent from servalws profile and Stow catalog.
- Their live config paths are absent, not broken links.
- Their source exists only in `dunst-archived/`, `rofi-archived/`, `polybar-archived/`, the related mixed-package `*-archived/` directories, and historical documentation.
- Health scripts describe the Quickshell-only stack.
- No new relevant Quickshell/Awesome log error appears during visual acceptance.
- No Git or Syncthing operation is part of agent execution.

## Suggested approval boundaries

Request approval separately for:

1. Source batch A: generic display backend plus non-live tests.
2. Deployment A: expose the new backend through Stow.
3. Source batch B: Awesome Quickshell-only controller and reliability/UX fixes; disclose unavoidable Quickshell auto-reload for live-linked QML.
4. Process tests: private-D-Bus Xvfb harness.
5. Live acceptance: enumerate each reversible mutation and restoration value.
6. Live cutover: normal Awesome reload and selected-config Quickshell restart.
7. Deployment B: explicit prune of old packages.
8. Source batch C: `*-archived` renames/extraction, catalog/profile/diagnostic/documentation cleanup.
9. Deployment C: focused restow of the new stack.
10. Optional OS package removal, only if the user wants binaries removed as well as configuration retired.
