# Quickshell + AwesomeWM implementation audit

**Audit date:** 2026-07-29  
**Scope:** `quickshell/`, its active AwesomeWM/X11 integration, retained Rofi/Polybar/Dunst boundaries, deployment registration, tests, current read-only runtime evidence, and retained visual proofs  
**Host observed:** servalws, X11, AwesomeWM 4.3, Quickshell 0.3.0 revision `4df562dfb2475a9057f0f33a8db75808efad8670`  
**Audit mode:** source review plus read-only/static validation; no source repair, reload, process restart, display mutation, device mutation, Stow apply, Git operation, or Syncthing operation

## Executive assessment

The implementation is a strong, coherent desktop-shell replacement rather than a thin collection of unrelated widgets. It has a clear composition root, explicit service ownership, a bounded and mutation-aware command transport, carefully designed X11 focus handling, authoritative AwesomeWM state publication, native notification and tray ownership, and a consistent visual system. The current live session is healthy: one Quickshell instance is resident, the primary bar has the correct 26px workarea reservation, Quickshell owns both notification and StatusNotifier watcher D-Bus names, Dunst and Polybar are not running, and the broad native device/system mutation gate is disabled.

The main weaknesses are not basic functionality. They are failure detection and operational assurance:

1. recovery identifies any `/usr/sbin/quickshell` process rather than this configuration;
2. bridge state has no producer freshness/liveness contract, so accepted state can remain “ready” indefinitely after publication stops;
3. destructive session actions report success when detached process launch succeeds, not when the requested action succeeds;
4. IPC health fields infer notification/tray ownership from object construction rather than independently proving D-Bus ownership;
5. one important Awesome/Quickshell geometry regression test currently fails because its expected pre-map identity has drifted from the rules;
6. muted and urgent text colors are below a 4.5:1 normal-text contrast target at the small font sizes used.

No Critical or High-severity defect was confirmed. The current session is functionally healthy, but the medium findings should be addressed before calling recovery and diagnostics fully robust.

### Severity summary

| Severity | Count | Meaning in this report |
|---|---:|---|
| Critical | 0 | Immediate data/session safety or control-boundary failure |
| High | 0 | Likely severe failure in normal use |
| Medium | 6 | Real robustness, diagnostics, test, or accessibility gap with a bounded trigger |
| Low | 5 | Cleanup, portability, observability, or limited edge-case improvement |

## Scope and evidence boundary

### Reviewed implementation

The production Quickshell tree contains:

- 60 QML files / 13,330 lines;
- 4 JavaScript files / 660 lines;
- 18 service QML types, all registered in `services/qmldir`;
- 2 style singletons, both registered in `style/qmldir`;
- 21 QML/Lua/Python test sources / 3,947 lines.

The audit traced:

- `shell.qml` composition and IPC;
- all service-layer QML and parser JavaScript;
- bar, system controls, launcher, switcher, calendar, session, display, keybind, notification, tray, media, weather, Tailscale, and OSD surfaces;
- `awesome-integration/bridge.lua`;
- active AwesomeWM startup, keys, rules, and signals;
- retained Rofi action scripts and Polybar/Dunst deployment boundaries;
- the current live process, IPC, D-Bus ownership, client geometry, workareas, and Quickshell log;
- the isolated Xvfb harness source and retained PNG visual proofs.

### What was not exercised

The audit deliberately did not:

- open or manipulate live shell surfaces;
- send keyboard or pointer events;
- invoke display, audio, network, Bluetooth, power, brightness, Tailscale, session, or workspace mutations;
- restart/reload AwesomeWM or Quickshell;
- run the Xvfb/Awesome/Quickshell process harness, because starting and stopping that process set was outside this read-only pass;
- repeat visual acceptance on the live desktop.

Consequently, current runtime claims are read-only proofs. Interaction and animation conclusions are source-backed or based on retained isolated screenshots, not a new live acceptance run.

## Current live-state evidence

Read-only inspection at approximately 16:30 +03 found:

- AwesomeWM PID `2150`;
- one Quickshell process, PID `647770`, launched as `/usr/sbin/quickshell --path /home/alikebrahim/.config/quickshell`;
- no running Dunst process;
- no running Polybar process;
- Quickshell instance `mtvdmtnxit` on `x11/:0`, resident for about 2.5 hours;
- `org.freedesktop.Notifications` owned by Quickshell PID `647770`;
- `org.kde.StatusNotifierWatcher` owned by the same Quickshell PID;
- Quickshell IPC `shell status` reporting ready bridge/composition, 66 launcher entries, 49 keybinds, synchronized workspace 1, healthy weather/Tailscale/native backends, and `nativeMutationsEnabled:false`;
- display and Awesome workspace capabilities enabled through their separate narrow transports;
- a single Quickshell dock on Awesome screen 1 / HDMI-0 at `1920,0 1920x26`, borderless, sticky, skipped from task lists, and not focused;
- the primary screen workarea beginning at y=26; the secondary screen retains its full workarea;
- the live config and Awesome files resolve to this repository's source files.

The current Quickshell log contains only six retained lines. Two are warnings:

- an unresolved launcher icon request for `display?fallback=application-x-executable`;
- failure to register with `org.freedesktop.portal.Desktop` because that portal had no owner.

There were no retained QML composition errors, `WARN scene` messages, bridge rejections, or command timeouts.

## Architecture and ownership

### Composition

`shell.qml` is the single composition root. It creates one instance of shared shell state, bridge, command transports, ownership controllers, services, primary bar, global modals, notification toasts, and OSD (`quickshell/.config/quickshell/shell.qml:15-134`). This is a clean dependency-injection pattern: components receive the service or controller they need rather than constructing competing authorities.

The implementation intentionally separates command capabilities:

- general native reads and optionally enabled device/system writes use `commandTransport` (`shell.qml:29-32`);
- fixed display profiles use an always-enabled, narrow display transport (`shell.qml:33-39`);
- published Awesome tag/window actions use an always-enabled, narrow workspace transport (`shell.qml:40-52`).

That split is appropriate because “mutation” is not one risk class. A fixed-token display profile and an Awesome focus action need different controls from arbitrary device changes.

### Awesome state bridge

AwesomeWM owns authoritative workspace, output, client, focus, and keybinding state. `bridge.lua`:

- sorts outputs by geometry and gives them stable L/C/R side labels (`bridge.lua:188-216`);
- excludes shell docks, desktops, and the scratchpad from published application clients (`bridge.lua:218-231`);
- aggregates synchronized tags through the shared workspace coordinator (`bridge.lua:233-284`);
- publishes bounded client and keybind snapshots (`bridge.lua:286-322`);
- atomically writes JSON through a temporary file and rename (`bridge.lua:146-174`);
- debounces a broad but relevant set of client/tag/screen signals at 50ms (`bridge.lua:344-367`, `393-407`).

The QML consumer defensively normalizes and validates the bridge payload:

- primary/focused outputs must exist and output IDs must be unique (`services/AwesomeBridge.qml:83-109`);
- tag names are bounded/actionable and exactly one logical workspace may be selected (`AwesomeBridge.qml:114-137`);
- client IDs must be positive/unique and reference a published output (`AwesomeBridge.qml:139-152`);
- keybind strings and count are bounded (`AwesomeBridge.qml:154-159`).

This is a notably strong trust boundary. Window titles remain display-only, while actions operate on validated numeric window IDs or published tag indexes.

### Command execution

`CommandTransport.qml` is one of the strongest parts of the design:

- argv must be a non-empty string array (`services/CommandTransport.qml:28-37`);
- writes are rejected when the mutation gate is closed (`CommandTransport.qml:39-42`);
- fixture mode records writes without executing them (`CommandTransport.qml:44-65`);
- detached jobs must be mutating and are separately handled (`CommandTransport.qml:68-75`);
- duplicate reads coalesce by stable key (`CommandTransport.qml:78-82`);
- the queue is bounded to 32 by default (`CommandTransport.qml:83-86`);
- mutations are prioritized ahead of polling reads (`CommandTransport.qml:88-96`);
- the gate is checked again when a queued mutation reaches execution (`CommandTransport.qml:102-113`);
- each process has an 8s timeout, SIGTERM, 1s grace, and SIGKILL fallback (`CommandTransport.qml:120-137`);
- timeout and empty-stderr nonzero exits become explicit failures, and the queue continues (`CommandTransport.qml:139-159`).

Most services preserve last-known-good data on malformed/unavailable reads and use request keys or pending-state convergence rather than assuming a command changed the host immediately.

### Native service lifecycle

The native PipeWire, NetworkManager, BlueZ, MPRIS, notification, and tray integrations generally use appropriate lifecycle boundaries:

- audio details refresh only while the audio panel is open, at 400ms, with pending checks at 100ms (`services/AudioService.qml:423-441`);
- network and Bluetooth attach detail snapshots only while open, at 500ms (`NetworkService.qml:467-510`, `BluetoothService.qml:494-515`);
- Bluetooth discovery is owned, time-bounded, and stopped when mutation permission is revoked (`BluetoothService.qml:518-529`, `553-558`);
- Tailscale uses one-minute passive refresh and bounded 750ms convergence polling only while an action is pending (`TailscaleService.qml:222-241`);
- weather refreshes every 15 minutes and independently marks data stale after 45 minutes (`WeatherService.qml:8-13`, `356-367`);
- CLI-backed power and brightness refresh at 30s and 10s respectively (`PowerService.qml:5-8`, `BrightnessService.qml:5-8`).

This avoids permanent high-rate scanning while retaining responsive open panels.

### Modal and focus ownership

The two-level focus model is clean:

- `ModalController` owns global surfaces and closes only after a surface has first reported active and then inactive (`services/ModalController.qml:12-49`);
- `BarPopoutController` owns one exact child under a single global `bar-popout` umbrella (`services/BarPopoutController.qml:13-74`);
- surface handoff publishes the new owner before asking the previous owner to close, preventing stale release from clearing the replacement (`BarPopoutController.qml:17-31`);
- focusable surfaces request QWindow activation and wait for `activeChanged` before forcing the intended item focus, e.g. launcher (`modules/launcher/ApplicationLauncher.qml:161-173`, `218-227`) and system controls (`modules/controls/SystemControls.qml:37-50`, `229-235`);
- outside-click deactivation can bypass the fade through `dismissImmediately`, while normal Escape closure keeps the animation (`ModalController.qml:41-49`, component `Behavior` bindings such as `ApplicationLauncher.qml:24-29`).

Awesome leaves activation requests to its built-in EWMH handler and avoids the recursive `awful.screen.focus()` signal loop (`awesome/.config/awesome/signals.lua:406-408`).

### Notifications and tray

Quickshell is the configured permanent notification authority (`services/NotificationService.qml:26-29`, `128-149`). The service:

- keeps the native NotificationServer alive across reloads;
- explicitly disables body markup/hyperlinks while retaining plain text and images (`NotificationService.qml:132-143`);
- caps history at 100 and visible toasts at 4 (`NotificationService.qml:21-25`, `375-390`, `423-428`);
- atomically saves primary and last-known-good state (`NotificationService.qml:71-119`, `251-263`);
- recovers from a valid backup and honestly reports fallback-to-default state (`NotificationService.qml:198-239`);
- disconnects live notification listeners on release (`NotificationService.qml:295-317`);
- supports DND and safely releases transient notifications (`NotificationService.qml:572-593`).

Static notification text uses `Text.PlainText`, which avoids treating sender-controlled body text as rich QML/HTML (`modules/notifications/NotificationCard.qml:107-163`).

The current live D-Bus check confirms one process owns both Notifications and StatusNotifierWatcher, avoiding split authority.

## Strengths

### Robustness

- One composition root and one authority per domain.
- Atomic Awesome state publication and bounded payload validation.
- Queue bounds, deduplication, mutation priority, gate re-check, timeout, and kill grace in the shared process transport.
- Explicit unavailable/stale/error state in weather, Tailscale, power, brightness, network, Bluetooth, and audio services.
- Open-only expensive detail models and scanning.
- Two-stage confirmation for display profiles and destructive session actions.
- One-active-modal and one-active-bar-popout invariants.
- Correct X11 focus activation handshake and immediate outside-click unmap behavior.
- Explicit Awesome rules and late property repair for Quickshell docks/modals.
- Bounded notification history/toasts and backup persistence.

### Security and control safety

- General native mutations default to disabled in production (`shell.qml:29-32`).
- Service mutations validate known objects, IDs, profiles, addresses, or bounded tokens before acting.
- Display execution accepts only four fixed profile IDs and an argv-safe backend call (`services/DisplayService.qml:63-113`).
- Awesome actions accept only a published tag index or positive published window ID (`services/AwesomeActionService.qml:19-69`).
- Session actions map four fixed IDs to fixed argv arrays; arbitrary commands are not accepted (`services/SessionActionService.qml:17-37`).
- Launcher terminal entries preserve parsed argv and do not reconstruct shell command text (`modules/launcher/ApplicationLauncher.qml:124-153`).
- Notification text is plain and action invocation is limited to the live native notification reference.

### Performance

- The bar is a single 26px surface, not one window per widget.
- One StatusNotifier host is resident; tray growth is slot-bounded by style metrics.
- The centered clock is anchored independently of unequal left/right content (`modules/bar/PrimaryBar.qml:83-119`).
- Bridge updates are signal-driven and debounced rather than continuously polled.
- Device detail and discovery models are dormant while their popouts are closed.
- Periodic CLI reads are low frequency and duplicate reads coalesce.
- Notification models are explicitly capped.
- Image loading is asynchronous in launcher, notifications, and tray delegates.

### UI/UX

- The retained screenshots show a cohesive, sparse, high-contrast shell with clear hierarchy, consistent panel borders/radii, well-spaced controls, visible slider affordances, and no obvious clipping at 1920x1080.
- The clock persistently includes date and time (`modules/bar/Clock.qml:10-32`).
- Launcher and switcher have immediate search, ranked/filterable lists, keyboard movement, Ctrl+P/N alternatives, Enter, and Escape.
- Session and display actions require a second confirmation rather than executing on first selection.
- Control popouts retain one consistent bar-local location and one-active ownership.
- OSDs are passive, focusless, input-transparent, and fall back from focused to primary output (`modules/osd/Osd.qml:22-27`, `131-146`).
- Error text and unavailable/locked states are represented in the relevant service/UI rather than silently omitting every failed control.

## Prioritized findings

| ID | Severity | Finding | Primary impact |
|---|---|---|---|
| F1 | Medium | Quickshell startup recovery is config-blind | A different/stale Quickshell process can suppress recovery of this shell |
| F2 | Medium | Awesome bridge state has no freshness/liveness contract | Stale outputs/tags/windows may remain accepted after publication stops |
| F3 | Medium | Session actions equate detached launch with action success | Suspend/logout/reboot/poweroff failures can close the UI without feedback |
| F4 | Medium | Notification/tray IPC health does not independently prove D-Bus ownership | Health can look ready during an ownership conflict |
| F5 | Medium | Awesome dock regression test is stale and currently fails | A key geometry/focus regression gate is not trustworthy |
| F6 | Medium | Muted/urgent text contrast is low for the configured small text sizes | Reduced readability/accessibility for captions and errors |
| F7 | Low | Legacy Polybar/Dunst deployment and diagnostics remain selected | Cleanliness and future drift risk despite correct current inactivity |
| F8 | Low | Fixed-pixel layout and compact targets have no scale policy | High-DPI/smaller-output portability and target-size limitations |
| F9 | Low | Launcher/session output fallback is inconsistent with stricter surfaces | A stale bridge name can open some modals on arbitrary screen 0 |
| F10 | Low | X11 clipboard helper has no timeout and uses a shell pipeline | A hung clipboard process can leave copy busy indefinitely |
| F11 | Low | One launcher icon fails to resolve in the live log | One application row may have a missing/blank icon and adds warning noise |

## Finding details

### F1 — Config-blind Quickshell recovery

**Evidence**

- `run_once_process` treats a successful `pgrep` as sufficient (`awesome/.config/awesome/rc.lua:45-51`).
- Both startup and Alt+Space recovery use `^/usr/sbin/quickshell( |$)` without the config path (`rc.lua:162`, `184-189`).
- The default key fallback repeats the same process-wide test (`awesome/.config/awesome/keys.lua:8-23`).

**Trigger**

Another Quickshell configuration, a stale process, or a process whose IPC/config registration is unhealthy is still running under `/usr/sbin/quickshell`.

**Impact**

The intended `/home/alikebrahim/.config/quickshell` instance is not started because the unrelated process satisfies `pgrep`. Alt+Space reports that a recovery start was requested even though `run_once_process` may do nothing.

**Recommendation**

Make recovery configuration-aware. Prefer an IPC readiness check for this exact `--path`; if unavailable, identify a process whose arguments include the exact config path. After spawning, perform a short bounded readiness check and retry the original operation or report that startup did not become ready. Do not kill or replace an existing process automatically.

### F2 — No bridge freshness or producer liveness

**Evidence**

- The bridge payload contains current state but no publish timestamp, producer ID, generation, or heartbeat (`quickshell/.config/quickshell/awesome-integration/bridge.lua:308-322`).
- QML sets `ready=true` after any valid document and never clears it merely because no newer document arrives (`services/AwesomeBridge.qml:179-197`).
- Its timer retries failed file loads; it is not a staleness watchdog (`AwesomeBridge.qml:205-233`).
- `bridge.stop()` removes state files, but `rc.lua` does not register this cleanup on an Awesome exit path (`bridge.lua:417-439`, `awesome/.config/awesome/rc.lua:109-172`, `260-269`). An abrupt failure cannot run cleanup anyway.

**Trigger**

Awesome exits/crashes, the bridge signal connections stop publishing, the runtime file survives an unclean shutdown, or publication repeatedly fails after one valid snapshot.

**Impact**

The shell can continue to report `bridgeReady:true` and show stale workspace, focus, title, and output state. Numeric window actions still revalidate against Awesome and therefore fail more safely than display-only state, but bar placement and user feedback can be wrong after topology change.

**Recommendation**

Add a monotonically increasing generation and producer timestamp/instance token to the bridge payload. In QML, expose fresh/degraded/stale states and clear actionable readiness after a bounded quiet period. Keep last-known display text if desired, but visibly mark it stale and avoid mapping output-specific surfaces against stale topology. Register normal cleanup where Awesome provides a safe exit hook, while treating heartbeat expiry as the crash-safe mechanism.

### F3 — Detached session launch is treated as completed action

**Evidence**

- `executeConfirmed()` calls `Quickshell.execDetached(command)`, emits `actionStarted`, clears `busy`, and returns true immediately (`services/SessionActionService.qml:54-78`).
- The menu closes immediately when that function returns true (`modules/power/SessionMenu.qml:90-100`).

**Trigger**

`systemctl suspend/reboot/poweroff` or `awesome-client awesome.quit()` starts but fails due to policy, an inhibitor, a missing executable, D-Bus/systemd error, or an Awesome-client evaluation error.

**Impact**

The confirmation UI closes as if the action succeeded, and failure output is lost. This is particularly confusing for suspend and logout, where the user remains in the session with no explanation.

**Recommendation**

Use a bounded result-bearing process path for session commands. Keep the menu open/busy until a meaningful exit or success sentinel is observed, surface stderr/stdout on failure, and close only after acceptance. Awesome-client should return and verify an explicit success sentinel because Lua evaluation errors are not reliably represented by process exit alone.

### F4 — IPC readiness is not ownership attestation

**Evidence**

- `serverReady` means the NotificationServer loader produced an item (`services/NotificationService.qml:55-56`).
- `ownershipLatched` is set when the loader loads (`NotificationService.qml:128-149`).
- Shell IPC publishes those values as `notificationsEnabled` and `notificationOwnershipLatched` (`shell.qml:172-174`).
- `trayReady` similarly checks that the bar's tray object is non-null (`shell.qml:161-165`).

**Trigger**

A D-Bus ownership race, a different notification daemon/watcher owning the name first, or a future native service failure that leaves the QML object constructed.

**Impact**

IPC health may say notifications/tray are enabled even when the process does not own the service name. The current live session is correct, but the status model is weaker than the ownership model.

**Recommendation**

Expose an ownership-confirmed or ownership-unknown state separately from component construction. Use a supported native registration/ownership signal if the installed Quickshell API provides one; otherwise make operations tooling perform an explicit session-bus owner check and report the owning PID. Avoid naming a loader latch as proof of D-Bus ownership.

### F5 — Stale Awesome/Quickshell regression assertion

**Evidence**

- `quickshell/tests/awesome-quickshell-window-test.lua:54-61` requires bare `quickshell` in `default_rule.except_any.name`.
- Current rules exempt `quickshell-shell` and `quattro-quickshell` in class/instance/name fields (`awesome/.config/awesome/rules.lua:8-16`).
- The live dock identity is `class=quickshell`, `instance=quickshell-shell`, `name=quickshell-shell`, and its geometry/properties are correct.
- The test fails at line 58 before reaching its late-type repair assertions.

**Impact**

The regression suite reports a failure against a currently correct live identity and never tests the rest of the dock path. This can hide a future real geometry/focus regression behind permanent known noise.

**Recommendation**

Update the test to assert the actual pre-map identity contract across the correct field(s), not a retired bare-name assumption. Then run the pure test and, with separate process-test authorization, the hardened private-D-Bus Xvfb harness.

### F6 — Small muted and urgent text miss 4.5:1 contrast

**Evidence**

- Palette values are background `#101315`, foreground `#cacccc`, muted `#707880`, accent `#d7c9bd`, and urgent `#a55555` (`quickshell/.config/quickshell/style/Palette.qml:7-18`).
- Captions/body text are 10/11/12px and error/status text frequently uses muted or urgent (`style/Metrics.qml:47-57`).
- Computed sRGB contrast against `#101315`:
  - foreground: 11.56:1;
  - accent: 11.53:1;
  - muted: 4.16:1;
  - urgent: 3.58:1.

**Impact**

Primary text is excellent, matching the retained screenshots' generally clear appearance. Muted captions and urgent/error labels, however, can be hard to read at the configured 10–14px sizes and do not meet a 4.5:1 normal-text target.

**Recommendation**

Lighten `muted` and the text use of `urgent`, or provide separate urgent-border and urgent-text tokens. Recheck contrast after selecting colors. Keep the current darker urgent color for large fills/borders if desired.

### F7 — Legacy deployment/diagnostic drift

**Evidence**

- The servalws profile still selects `dunst`, `rofi`, and `polybar` beside Quickshell (`scripts/profiles/servalws.conf:6-9`).
- All three remain registered Stow packages (`scripts/lib/stow-catalog.sh:53-60`).
- The live Dunst and Polybar config paths still resolve into this repository.
- `scripts/check-wm-servalws.sh` still describes the stack as “AwesomeWM + Polybar + picom + Dunst,” checks Dunst/Polybar as expected processes, and devotes health sections to them (`scripts/check-wm-servalws.sh:4-6`, `15-30`, `73-109`, `191-196`).
- Current live state is safe: Dunst is inactive and its user service is masked; Polybar is not running; Quickshell owns notifications.
- Rofi is not retired: it remains the deliberate fallback for launcher, switcher, power, keybind help, display, and unaccepted device-write paths (`awesome/.config/awesome/rc.lua:193-253`, `keys.lua:25-39`, `318-330`).

**Impact**

There is no current ownership conflict, but a future profile apply continues deploying obsolete bar/notification configuration, and the health script can misclassify the intended shell state. “Rofi retired” would be an inaccurate claim; it is intentionally retained as recovery/deferred-control infrastructure.

**Recommendation**

Treat this as a separate cleanup decision. First update health diagnostics to describe Quickshell as primary, Dunst/Polybar as expected inactive, and Rofi as on-demand fallback. Only remove Dunst/Polybar from the host profile after confirming the user wants source/deployment retirement; do not delete packages or configs as part of a robustness fix.

### F8 — Fixed pixel scale and compact pointer targets

**Evidence**

- The style system is centralized but entirely fixed-pixel (`style/Metrics.qml:5-57`).
- The bar is 26px high, tags are 20px wide, status slots are 27px wide, tray slots are 24px, sliders are 22px high, and notification close is 24×24 (`Metrics.qml:6-21`, `modules/bar/Tags.qml:23-27`, `modules/controls/StatusText.qml:16-18`, `ui/PanelSlider.qml:20-21`, `modules/notifications/NotificationCard.qml:166-191`).
- Large panels use fixed dimensions such as 640×520 keybind help, 660×430 switcher, 570×490 display manager, and 560×430 launcher.
- No scale, pixel-density, or `Accessible.*` policy was found.

**Impact**

The current two 1920×1080 outputs render cleanly, and a dense mouse-driven bar can reasonably be compact. On high-DPI or smaller outputs, text/targets may become physically small and fixed dialogs may clip. Screen-reader semantics are absent.

**Recommendation**

Park this unless the hardware profile changes or accessibility is a goal. If addressed, add one bounded scale token derived from an explicit user setting, clamp large surfaces to available screen geometry, and add accessible names/roles to custom interactive controls. Avoid broad responsive-layout infrastructure for the current fixed workstation unless a real need appears.

### F9 — Inconsistent unknown-output fallback

**Evidence**

- Launcher and session menu fall back to `Quickshell.screens[0]` when the bridge output name cannot be resolved (`modules/launcher/ApplicationLauncher.qml:32-39`, `modules/power/SessionMenu.qml:35-42`).
- Window switcher instead returns unavailable on an unresolved target (`modules/switcher/WindowSwitcher.qml:21-40`, `90-102`).
- The bar and OSD use explicit primary/focused resolution rather than arbitrary ordering (`modules/bar/PrimaryBar.qml:27-33`, `modules/osd/Osd.qml:22-27`).

**Impact**

During stale/startup topology, launcher/session may open on an arbitrary first screen while other global surfaces correctly refuse or use the authoritative primary fallback.

**Recommendation**

Use one policy: focused output, then bridge-authoritative primary output, then unavailable. Do not use array order for user-visible placement.

### F10 — Clipboard helper has no timeout

**Evidence**

- Clipboard text is sanitized to one line, capped at 512 characters, and passed safely as `$1` to a fixed Bash pipeline (`services/X11ClipboardService.qml:16-28`).
- The dedicated `Process` has no timeout/termination timer (`X11ClipboardService.qml:31-40`).

**Impact**

Injection risk is low because the value is positional data, not interpolated shell source. If Bash/xclip hangs, however, `busy` remains true and all later copy requests are refused until the process exits or the shell restarts.

**Recommendation**

Add a short bounded timeout and kill grace, or route the fixed copy helper through a reusable bounded process adapter. Preserve the 512-character and one-line limits.

### F11 — Live launcher icon warning

**Evidence**

- The launcher resolves each desktop-entry icon through `Quickshell.iconPath()` with a fallback (`modules/launcher/ApplicationLauncher.qml:380-391`).
- The current log reports failure to load `display?fallback=application-x-executable` at 28×28.

**Impact**

One launcher row may show a missing icon and the warning adds startup noise. Search and launch behavior are otherwise healthy; 66 entries are loaded.

**Recommendation**

Identify the desktop entry whose icon is `display`, then verify whether this Quickshell revision expects the icon property as a raw name or already-resolved URL. Add an `Image.Error` fallback glyph if a missing theme icon is expected. Do not special-case one app ID unless the installed API requires it.

## UI/UX evaluation

### Bar

The bar architecture is clean and appropriate for the profile:

- exactly one primary-output panel;
- positive exclusive zone only while shown;
- left tags/title, independently centered date-time, right status controls;
- one continuous translucent panel rather than separate visual pills;
- bounded tray slots;
- secondary output retains full workarea.

The live 1920px bar is correctly placed and reserves exactly 26px. A remaining edge case is content collision: left and right sections are independently anchored and the clock is centered, but neither side is constrained against the clock. At current content density this is fine. A long title plus many visible status/tray items could overlap the clock. If this occurs in real use, constrain/elide the left title against a center exclusion zone rather than moving the clock.

### Popouts and global modals

The one-owner model makes behavior predictable. Keyboard focus is handled explicitly, Escape is consistently available, and outside click closes without a restack flash. Fixed widths and strong headings create a coherent information hierarchy.

The global launcher/switcher/session/display/keybind surfaces are larger and centered/focused, while bar-local calendar/control/tray/media/history/weather/Tailscale surfaces stay anchored to the primary bar. This separation is sensible.

### Controls

The system-control presentation is a strong adaptation:

- five control-specific entry points rather than one undifferentiated settings page;
- service-specific hero/status content;
- inline read-only/locked/error states;
- keyboard traversal through the shared navigator;
- open-only detailed device/network models;
- two-step display/profile confirmation.

The retained screenshots show no clipping and good spatial rhythm. They do not prove dynamic network lists, long Bluetooth names, audio streams, credentials, loading/error states, or keyboard cursor visibility.

### Launcher and switcher

Strengths:

- search is immediate and result count visible;
- launcher ranking prefers name prefixes/exact matches before metadata (`ApplicationLauncher.qml:48-107`);
- terminal applications preserve the desktop-entry argv contract;
- switcher publishes workspace/output context and revalidates window IDs;
- activation waits for a result before closing the switcher (`WindowSwitcher.qml:118-146`).

Improvements:

- resolve F11's missing icon;
- align launcher/session output fallback with the stricter bridge-authoritative policy;
- consider showing a brief “starting” or “no applications loaded” distinction only if live startup ever makes the existing `Loading applications` state ambiguous.

### Notifications

The notification UI is functionally rich and safer than a basic toast implementation:

- bounded toast stack;
- hover-paused lifetime using elapsed wall time rather than assuming exact timer ticks (`modules/notifications/NotificationToasts.qml:64-126`);
- urgency border/stripe;
- icon/image fallback;
- default action and explicit close;
- DND, history, unseen count, seen/archive behavior, persistence, and backup.

The 100ms timer is per visible toast, but the stack is capped at four, so the maximum active timer load is bounded and negligible. The main UX issue is the low urgent/muted text contrast, not the notification lifecycle.

### Visual proof limitations

The five retained 1920×1080 PNGs are legitimate isolated presentation evidence and have nontrivial pixel diversity (`quickshell/docs/visual-proof/README.md:1-18`). Independent image inspection found:

- coherent dark-theme composition;
- clear headings and section hierarchy;
- consistent spacing and borders;
- visible slider/button affordances;
- no obvious clipping or overflow;
- generally strong foreground contrast.

They were generated from fixture state on one Xvfb screen (`docs/visual-proof/README.md:1-6`; `tests/xvfb/visual-proof.qml:14-33`, `67-110`). They do not prove:

- live Awesome placement or focus;
- animations and outside-click dismissal;
- launcher/switcher/session/display/keybind surfaces;
- notification history/toasts;
- tray item menus/overflow;
- media/weather/Tailscale popouts;
- long/dynamic data;
- two-monitor placement;
- high-DPI scaling;
- keyboard/pointer interaction.

The visual docs correctly label themselves historical presentation evidence rather than current live acceptance (`docs/visual-proof/README.md:39-44`).

## AwesomeWM/X11 integration assessment

### Startup and state flow

The active path is straightforward:

1. Awesome normalizes the X11 session environment and runs monitor setup only during Awesome startup (`awesome/.config/awesome/rc.lua:94-99`).
2. It loads and starts the bridge against canonical and temporary legacy runtime paths (`rc.lua:109-147`).
3. It constructs the Quickshell command with explicit state path, resource name, and mutation environment (`rc.lua:148-162`).
4. It installs Quickshell key callbacks only when bridge startup succeeds (`rc.lua:177-253`).
5. It publishes a second snapshot after root keys are registered so keybind help is complete (`rc.lua:260-266`).
6. Quickshell watches and validates the state file, maps one bar to the authoritative primary output, and routes focused-screen global surfaces through the bridge.

This is a good startup order. It avoids presenting a “ready” integration before bridge initialization, and it keeps Rofi fallbacks available if Quickshell IPC fails.

### Rules, geometry, and focus

Awesome's catch-all application rule excludes shell identity and dock/desktop types, and it does not take screen/placement ownership (`awesome/.config/awesome/rules.lua:8-26`). Dedicated shell/dock rules apply borderless/floating/sticky/task-list policy without assigning geometry (`rules.lua:28-42`). Explicit modal names receive focus/ontop behavior (`rules.lua:43-63`).

The signal layer repairs late X11 identity/type changes, avoids centering shell docks, and focuses only known Quickshell modals (`awesome/.config/awesome/signals.lua:268-405`). Live evidence confirms the final client and workarea are correct.

### Workspace model

The workspace coordinator enforces one selected index across every screen, repairs external one-screen selections, moves clients within their screen's tag stack, and restores focus. The bridge consumes the same coordinator for aggregate tags, so bar state and key behavior share one authority. The pure workspace regression passed.

### Retirement boundaries

- **Polybar:** operationally retired. It is not started by current `rc.lua` and is not running. Source/config remains deployed.
- **Dunst:** operationally retired. It is inactive, the user service is masked, and Quickshell owns Notifications. Source/config remains deployed.
- **Rofi:** not retired. It remains an intentional failure fallback for core modals and the implementation for direct device-control shortcuts while general Quickshell mutations are disabled.
- **Awesome native pill bar:** dormant source remains under `awesome/.config/awesome/ui`, but current `rc.lua` does not require or initialize it. No live pillbar client was observed.
- **Naughty:** `naughty.core` remains intentionally loaded for Awesome internal errors, while `naughty.dbus` is not loaded, avoiding notification-name competition (`rc.lua:16-18`).

This is a robust operational cutover but not a repository/deployment purge. Documentation should use “operationally retired” for Polybar/Dunst and “retained fallback” for Rofi.

## Validation results

### Passed in this audit

| Check | Result |
|---|---|
| `awesome -k -c awesome/.config/awesome/rc.lua` | PASS — configuration syntax OK |
| `bash -n awesome_wm_scripts/.config/scripts/*.sh` | PASS |
| `quickshell/tests/bridge-lua-test.lua` | PASS — JSON, hotkeys, atomic writer, lifecycle |
| `quickshell/tests/workspace-sync-lua-test.lua` | PASS — sync, aggregation, repair, move/follow |
| Python AST parse of `run-awesome-xvfb.py` | PASS |
| Services/style `qmldir` registration audit | PASS — no missing/extra production types |
| Style-token source check | PASS — no confirmed undefined `ShellStyle.Palette`/`Metrics` references |
| Live Quickshell instance discovery and IPC | PASS |
| Live notification D-Bus owner | PASS — Quickshell PID 647770 |
| Live StatusNotifier watcher owner | PASS — Quickshell PID 647770 |
| Live bar geometry/client policy/workarea | PASS |
| Live Dunst/Polybar inactivity | PASS |
| Retained PNG dimensions/diversity | PASS — five 1920×1080 nonblank images |

### Failed in this audit

| Check | Result |
|---|---|
| `quickshell/tests/awesome-quickshell-window-test.lua` | FAIL at line 58 — stale expected bare `quickshell` name; see F5 |

The first two Lua tests passed before this failure; the command stopped at the failing third test.

### Not available or not run

- `qmllint`, `qmlformat`, and `qmlimportscanner` are not installed on this host.
- The current resident shell provides a stronger real-composition check than parser-only validation: it is resident, IPC is populated, and its retained log has no QML composition/scene errors.
- The private-D-Bus Xvfb harness was source-reviewed but not executed. Its outer runner now encloses the test in `dbus-run-session` and `xvfb-run`, generates and verifies a nonce, checks a test-RC marker, compares Awesome output topology to RandR, rejects live output names, and refuses a fixture mutation unless exactly one dock matches (`quickshell/tests/run-awesome-xvfb.py:88-117`, `176-223`, `297-309`). That confirms the historical “source-hardened” claim, not a current runtime PASS.
- No live input/mutation route was exercised.

## Documentation accuracy

### Claims confirmed now

- Quickshell is the active resident shell.
- One primary-output 26px bar owns the workarea.
- Native general mutations are disabled; display/workspace capabilities are separate.
- Quickshell owns notifications and StatusNotifier watcher.
- Dunst/Polybar are inactive.
- Rofi fallbacks remain.
- Awesome syntax is valid.
- Bridge and workspace pure regressions pass.
- Xvfb runner source contains the documented private-D-Bus/nonce/topology guards.

### Historical or source-only claims

- Live keyboard round trips and visual/modal acceptance recorded in project docs were not repeated.
- The Xvfb geometry/focus/remap harness was not run.
- Retained screenshots prove only the fixture state described in their README.
- Device mutation convergence was not retested live.
- Tray behavior with real items/menus/overflow was not retested; the current tray is healthy but empty.

### Drift requiring correction

- The failing Awesome window regression should not be described as currently green.
- `scripts/check-wm-servalws.sh` still presents Polybar/Dunst as primary stack components.
- “Rofi replaced” is too broad; it is an explicit active fallback and still owns several direct control shortcuts.

## Recommended work

### Now — highest value, bounded robustness batch

1. Fix F5's stale pure regression assertion first so the integration gate is trustworthy.
2. Make startup/recovery config-aware and add a bounded readiness result (F1).
3. Add bridge generation/timestamp and QML stale/degraded state (F2).
4. Change session actions from optimistic detached launch to result-bearing execution (F3).
5. Expose ownership-confirmed/unknown health separately from object readiness (F4).

These changes are closely related to failure behavior and operational truth. They should be one reviewed source batch, followed by `awesome -k`, pure Lua regressions, and—only with separate authorization—the private Xvfb geometry harness and a normal live interaction check.

### Next — usability and cleanup

1. Adjust muted/urgent text colors and recheck objective contrast (F6).
2. Update `check-wm-servalws.sh` to the Quickshell-primary architecture (F7).
3. Align launcher/session target-screen fallback with focused→primary→unavailable (F9).
4. Add a clipboard timeout (F10).
5. Diagnose the one unresolved desktop-entry icon (F11).

### Parked — only if a real need appears

- scale/DPI policy and larger targets;
- responsive clamping for outputs below 1080p;
- screen-reader semantics for custom controls;
- source/package deletion of Polybar or Dunst;
- removing Rofi fallbacks;
- broad UI refactoring or new infrastructure.

## Suggested acceptance matrix for a future approved repair

### Static/pure

- `awesome -k` passes.
- all retained Bash helpers pass `bash -n`.
- bridge, workspace, and Awesome window Lua regressions all pass.
- bridge stale-state unit/fixture proves fresh → degraded → stale and recovery.
- session-action fixture proves nonzero/empty-stderr and Awesome-client error paths remain visible.
- ownership status distinguishes object-ready from owner-confirmed/unknown.

### Isolated process test, only when separately authorized

- run the existing private-D-Bus Xvfb harness;
- verify one bar, exact strut, popup focus, three hide/show remaps;
- fail on any scene warning or unexpected client;
- keep all processes and files inside the owned temporary boundary.

### Read-only live proof

- one intended Quickshell config instance;
- bridge fresh and synchronized;
- notification and tray names owned by that PID;
- exactly one primary bar and 26px primary workarea;
- no Dunst/Polybar process;
- no new QML scene/bridge/icon warnings after normal use.

### User interaction, only when authorized

- Alt+Space visible → hidden → visible;
- launcher, switcher, session menu, display manager, and keybind help open on the intended screen and dismiss cleanly;
- one bar popout hands off to another without flash;
- outside click and Escape both close correctly;
- a failed fixture/session action visibly reports failure;
- real notification arrival/action/dismissal/history;
- one unmistakable real tray item, menu, and removal;
- visual acceptance of revised muted/urgent colors.

## Final verdict

The Quickshell implementation is architecturally clean and substantially more robust than a typical personal shell configuration. Its core patterns—single ownership, explicit dependency injection, bounded command execution, validated bridge state, open-only native detail models, focus-aware modal coordination, and atomic notification persistence—are appropriate and well executed.

The current live system is healthy and the Polybar/Dunst cutover is operationally successful. The remaining work is primarily to make failure recovery and health reporting as truthful as the happy path, restore trust in the geometry regression gate, and improve small-text contrast. No broad rewrite is warranted. A focused reliability batch followed by proportional isolated and live acceptance is the cleanest next step.
