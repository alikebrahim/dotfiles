# Quickshell X11 window-rendering and animation plan

Prepared: 2026-07-30  
Status: Phase 1 active, healthy, and visually accepted; later animation phases parked  
Target: Quickshell 0.3.0 on AwesomeWM 4.3/X11 with Picom v13

## Goal

Make Quickshell popouts and modals appear, hand off, and disappear smoothly without
changing the accepted AwesomeWM ownership, modal behavior, output placement, or
input model.

## Architecture decision

Use one animation owner per shell surface:

- AwesomeWM owns X11 placement, focus, raising, and client rules.
- Picom composites Quickshell windows but does not animate their map/unmap lifecycle.
- Quickshell animates stable inner content inside transparent top-level windows.
- Top-level window geometry remains fixed while a transition is running.
- Focus requests follow real window lifecycle state rather than fixed timing guesses.

This follows Quickshell maintainer guidance to use a transparent window sized for
the largest expected content and animate content within it. Picom's rule system is
used to override its global animation scripts only for Quickshell windows; normal
application-window animations remain unchanged.

## Source evidence

- Quickshell resize-animation discussion:
  <https://github.com/quickshell-mirror/quickshell/issues/18>
- Quickshell `QsWindow` visibility, transparency, and click-through mask:
  <https://quickshell.org/docs/v0.3.0/types/Quickshell/QsWindow/>
- Picom animation and per-window rule semantics:
  <https://picom.app/>
- Picom popup-animation exclusion discussion and zero-duration override:
  <https://github.com/yshui/picom/issues/1380>
- AwesomeWM client activation semantics:
  <https://awesomewm.org/doc/api/classes/client.html>
- Qt Quick render-thread animator semantics:
  <https://doc.qt.io/qt-6/qml-qtquick-animator.html>

## Current local causes

1. `picom/.config/picom/picom.conf` applies global `appear` and `disappear`
   scripts to every matching X11 client, including Quickshell docks.
2. The same Quickshell surfaces animate their inner card opacity through
   `ui/PopupCard.qml` and modal-local `cardOpacity` behaviors.
3. On close, Quickshell finishes its fade and unmaps the surface, after which
   Picom starts a second close animation using the unmapped window image.
4. `modules/controls/SystemControls.qml` binds the actual popup height to changing
   content height, so switching control pages resizes the top-level X11 window.
5. Several focusable surfaces use an 80ms timer before `requestActivate()`, which
   can raise or focus a client while a visual transition is still running.
6. Bar-popout handoff activates a new X11 popout before requesting closure of the
   old one, allowing brief overlap between two independently animated windows.

## Scope and approval boundaries

- Creating and maintaining this plan is approved.
- Phase 1 Picom source editing is approved by the request to proceed.
- The Picom config target is a live symlink to the repository source. Editing the
  source changes the file Picom would read, but the running compositor is not
  expected to reread it automatically.
- Restarting/reloading Picom, Quickshell, or AwesomeWM requires separate approval.
- Phases 2–4 are conditional follow-up source edits and require a new explicit
  approval after Phase 1 live evidence is reviewed.
- No Git, Syncthing, Stow, package-manager, display-profile, device, or session
  operation is part of this plan.

## Phase 0 — evidence and design

Status: complete

1. Inspect Picom, Quickshell popup, modal-controller, focus, and Awesome client rules.
2. Verify the live Quickshell X11 identity:
   - class: `quickshell`
   - instance: `quickshell-shell`
   - type: `dock`
3. Review official Quickshell, Picom, AwesomeWM, and Qt documentation.
4. Review relevant Picom and Quickshell issue discussions.
5. Record a 60fps baseline before live activation if a clean comparison is wanted.

Exit: animation ownership and geometry risks are understood without source or live
mutation.

## Phase 1 — give Quickshell sole animation ownership

Status: source change complete; Picom v13 diagnostics passed; live accepted

### File

- Modify: `picom/.config/picom/picom.conf`

### Change

Append a final, narrow Picom v13 rule that matches the Quickshell class/instance and:

- disables legacy fading with `fade = false`;
- supplies zero-duration scripts for `open` and `show`;
- supplies zero-duration scripts for `close` and `hide`.

The rule must appear after the general dock and application rules. Picom merges
animation scripts from matching rules, and the last script for an identical trigger
wins. Explicit zero-duration scripts are used rather than relying on an empty list.

Do not change:

- global Picom animation behavior for normal applications;
- backend, vsync, damage, blur, NVIDIA, or unredirect settings;
- QML durations, easing, geometry, focus, or controller sequencing.

### Static validation

1. Run Picom diagnostics against the edited repository config.
2. Confirm the parsed Quickshell rule contains `fade = false` and both trigger pairs.
3. Confirm the existing normal-window global animations remain present.
4. Do not restart Picom as part of static validation.

Exit: the source parses and only Quickshell's Picom animation ownership is overridden.

Validation result on 2026-07-30:

- `picom --config .../picom.conf --diagnostics` exited 0;
- Picom reported v13, the intended repository config, and the GLX backend;
- diagnostics reported the existing compositor and did not take over the session;
- no Picom, Quickshell, or AwesomeWM process was restarted or reloaded.

## Gate 1 — separately approved live comparison

Status: accepted — user reports the motion is much better

Live activation result on 2026-07-30:

- the prior Picom process exited cleanly;
- AwesomeWM spawned a new Picom process with the same explicit config command;
- Picom v13 diagnostics found the active compositor, intended config, and GLX backend;
- Quickshell `shell ping` returned `ok`;
- AwesomeWM 4.3 remained responsive with no startup errors;
- Quickshell and AwesomeWM were not restarted.
- The user visually assessed the affected windows and reported the motion is much better.

Retained visual acceptance checklist:

1. Record or retain the baseline clip.
2. Exercise the same sequence at 60fps:
   - open/close one bar control three times;
   - hand off directly between two bar popouts;
   - open/close launcher;
   - open/close window switcher;
   - open/close session menu;
   - dismiss once with Escape and once through focus loss/outside click.
3. Compare for double fade, delayed close, scale snap, ghost/reappearance, focus jump,
   and content-height jump.

Decision:

- If motion is accepted, stop. Do not implement later phases.
- If only the controls popup jumps when changing pages, approve Phase 2.
- If fixed-size modals still jump when focused, consider Phase 3.
- If direct sibling popout handoff alone remains rough, consider Phase 4.

## Phase 2 — stabilize shared controls geometry

Status: conditional; not approved

### Likely files

- Modify: `quickshell/.config/quickshell/modules/controls/SystemControls.qml`
- Modify only if needed: `quickshell/.config/quickshell/ui/PopupCard.qml`

### Approach

1. Determine the maximum accepted content height from existing control pages and the
   existing 560px content cap.
2. Keep the outer popup at one stable height while open and while switching pages.
3. Keep visible content top-aligned within that transparent host.
4. Limit input to the visible card/content region with a Quickshell `Region` mask if
   unused transparent space would otherwise intercept clicks.
5. Animate inner content only; do not animate `implicitHeight`, window height, or
   Awesome client geometry.
6. Preserve Escape, keyboard navigation, focus-loss dismissal, output placement,
   and bar-popout mutual exclusion.

### Validation

- Run the normal QML/static checks.
- Open each control through IPC without device mutation.
- Cycle all five pages and confirm the Awesome client geometry stays constant.
- Perform separately approved live visual acceptance.

Exit: page changes no longer resize the top-level X11 popup.

## Phase 3 — replace timer-based focus guesses

Status: conditional; not approved

### Likely files

- `quickshell/.config/quickshell/modules/controls/SystemControls.qml`
- Other modal/popout files containing the same 80ms `focusRetry` pattern, but only
  those still shown by recording to jump or lose focus.

### Approach

1. Separate logical open state, backing-window visibility, and keyboard-focus state.
2. Request activation once after the backing window is actually visible/managed.
3. Focus the keyboard navigator after the window reports active.
4. Keep a bounded fallback only if the event-driven path demonstrably misses an X11
   lifecycle edge; do not retain an unconditional delay by default.
5. Preserve the existing immediate focus release on logical close.

### Validation

- Open/close through IPC repeatedly.
- Confirm no focus recursion, notification flood, stale focused Quickshell client,
  or failure to restore application focus.
- Perform separately approved live keyboard and visual acceptance.

Exit: focus and raising no longer occur at a guessed point during the transition.

## Phase 4 — one stable host for bar-popout handoff

Status: parked; implement only if direct sibling handoff remains defective

### Likely files

- `quickshell/.config/quickshell/services/BarPopoutController.qml`
- `quickshell/.config/quickshell/modules/bar/PrimaryBar.qml`
- Individual bar-popout hosts that remain separate X11 windows

### Approach

Reuse one stable bar-popout `PanelWindow` and switch its inner content rather than
opening a new X11 window before closing the previous one. Preserve one-click handoff,
per-icon anchoring/alignment, Escape behavior, global-modal exclusion, and existing
service lifecycle boundaries.

This is a broader architectural change and is deliberately not part of the first
fix.

## Notification-toast lifecycle follow-up

Status: assessed; source change pending separate approval after restart

The accepted Picom override remains correct and should not be broadened or rolled
back. A later three-notification Flameshot failure burst exposed a narrower
Quickshell geometry issue in `NotificationToasts.qml`: its shared passive
`PanelWindow` maps and resizes directly with `popupCount`, so model arrival and
clustered expiry can expose unsettled top-level X11 geometry.

Treat this as a targeted application of the existing architecture decision, not
approval for Phases 2–4:

1. settle toast layout before mapping the backing window;
2. retain the largest required outer height while a burst is active rather than
   shrinking for each clustered removal;
3. keep the input mask limited to real toast content;
4. briefly hold the transparent host after the final removal, then unmap once;
5. keep animation and visual transition logic on inner content only.

The independent notification-history acknowledgement correction belongs to
`NotificationService.qml` and Batch 13A in `consolidation-plan.md`.

## Rollback

Phase 1 source rollback is one bounded removal: delete only the final Quickshell
Picom rule. A live rollback still requires separate authorization to restart/reload
Picom. Later phases must document their own exact rollback before implementation.

## Definition of done

The rendering polish is complete when:

- Quickshell owns its shell-surface transitions without a second Picom animation;
- opening and closing shows no double fade, delayed disappearance, scale snap, or
  ghost image;
- control-page changes do not visibly resize or hitch the outer popup;
- focus and direct popout handoff remain correct;
- the relevant native syntax checks pass;
- the user accepts the real 60fps visual result;
- no unrelated QML, Picom, AwesomeWM, or desktop behavior is changed.
