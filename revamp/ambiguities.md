# Quickshell Revamp — Open Ambiguities

Running log of places where the filled-in `decisions.md` still left room for
interpretation, plus the interpretation taken so implementation could
proceed without blocking on a round-trip. Anything marked **[NEEDS YOUR
CONFIRMATION]** was decided provisionally — flag if the guess is wrong and
it gets changed, nothing is locked in by writing code.

---

## 1. `Mod+Shift+Space` freed up "next layout" — where does it go?

**RESOLVED (2026-07-06):** `Mod+Shift+Space` → Quick Apps menu.
`Mod+C` → Full Control Panel (new binding). Layout-cycle (`awful.layout.inc`)
dropped entirely — user only uses tiling layout.

*(Original interpretation was `Mod+Shift+C` for layout cycle — superseded by
user decision to drop layout-cycle entirely.)*

---

## 2. `Mod+P` — "same as quick-control-panel for available modes"

**RESOLVED (2026-07-06):** `Mod+P` stays as the display manager
(`rofi-display-manager.sh` or equivalent) — presenting Extend / Laptop Only /
Duplicate / Mirror options, exactly like the existing Rofi script. NOT
redirected to QuickPanel or FullPanel.

---

## 3. `Mod+Shift+W` / `Mod+Shift+B` / `Mod+Escape` — "no longer needed"

**RESOLVED (2026-07-06):** All three dropped — removed from keys.lua
(commented out, not deleted). Replaced by QuickPanel tiles.

---

## 4. AwesomeWM bridge transport: socket vs. file-watch

You chose **Option B** in decisions.md §2 — "a persistent bridge process
... pushes tag/focus-change events to Quickshell over a Unix socket
(`Quickshell.Io.Socket`)."

**Implementation taken:** built the bridge as an **atomic JSON state file**
(`$XDG_RUNTIME_DIR/awesome-bridge-state.json`) written by a new
`bridge.lua` AwesomeWM module on every tag/focus-relevant signal, watched by
Quickshell via `FileView { watchChanges: true }` — the exact same mechanism
already proven live in this codebase for `theme_tokens.json` (confirmed
working via `inotify`-backed file watching in earlier live testing).

This is a deliberate deviation from literal "Unix socket" wording, for
three concrete reasons:
1. **Perceived latency is equivalent.** `inotify`-driven file watching
   fires in low single-digit milliseconds — indistinguishable from a
   socket push for a UI update, and nowhere near the multi-frame lag that
   would actually matter.
2. **Already proven in this exact codebase** — no new protocol, no new
   daemon, no new failure mode to debug. `Quickshell.Io.Socket`'s exact
   semantics (client-only vs. listen-capable) weren't fully confirmed in
   research, so this avoids building on an unverified assumption.
3. **Simpler failure recovery** — if AwesomeWM restarts (`Mod+Shift+R`,
   which you use regularly), a file just gets rewritten; a socket
   connection would need explicit reconnect-on-restart logic on both ends.

Actions *from* Quickshell *to* AwesomeWM (e.g. clicking a workspace pill in
the bar) still go through a lightweight `awesome-client` shell-out — that
direction is inherently request/response, not a continuous stream, so it
doesn't touch the "should this be event-push" question at all.

**[NEEDS YOUR CONFIRMATION]** — if you specifically want true bidirectional
socket IPC (e.g. because you have plans that need push semantics beyond
what a watched file gives you), this can be swapped out later without
touching anything else, since `BridgeState.qml` is the single chokepoint
every other module reads from.

---

## 5. Keybind cheat-sheet — "are there good references?"

You asked directly whether there are good reference implementations for a
Quickshell keybind cheat-sheet. Honest answer from the research pass: **no
dedicated cheat-sheet module was found** in Caelestia, Noctalia, or
bjarneo's configs specifically — none of the three ship a searchable
keybind browser as a first-class surface (Caelestia and Noctalia both
assume you memorize Hyprland's own bind list or check its config file
directly; bjarneo's omni-menu doesn't have a keybinds category either).

**What was built instead:** a plain, from-scratch searchable list (the
`KeybindsCard` in the Full Control Panel) that reads a small JSON file
(`awesome-integration/keybinds.json`) — the same underlying data your
current `rofi-keybinds.sh` hardcodes as a heredoc — and renders it through
the same fuzzy-filter/list-navigation pattern used by the Launcher's app
search, since that pattern is already being built for a different surface
and reusing it here doesn't cost anything extra. This is a "no drop in
quality vs. the old static Rofi cheat-sheet," not a "found a proven
pattern to copy," and is flagged as such.

**[NEEDS YOUR CONFIRMATION]** — none needed, just flagging that this
answer is "we built something reasonable" rather than "we found the right
answer already out there."

---

## 6. Bottom-sprout launcher gets no separate keybind

Section 7 of decisions.md settled that launcher style (center-modal vs.
bottom-sprout) is a Control Panel *setting*, not a separate keybind — so
`Mod+Space` always opens "the launcher," and which visual presentation it
uses depends on the current setting. This is a straightforward reading of
your answer, called out here only because it's the reason
`Mod+Shift+Space` was fully free to give to the Quick Apps menu instead
(no launcher-related use was competing for it).

No confirmation needed — recorded for completeness since it affects the
keybind map.

---

## 7. Lock screen switch mechanism

**RESOLVED (2026-07-06):** User confirmed they want both i3lock AND
Quickshell-native lock screen as selectable backends.

**Implementation:** Option A — a single always-running `xss-lock` that
invokes `lock-dispatcher.sh`, a thin wrapper reading `lock-settings.json`
and dispatching either `i3lock -c 1e1e2e` or `quickshell -p lock.qml`.
The FullPanel's AwesomeWM/Workspace card toggle writes to
`lock-settings.json` (persistence wired 2026-07-06). Switching backends
does NOT require killing/respawning `xss-lock` — the next lock event
picks up the changed setting.

## 8. `lgi.Json` binding is broken on this build — do not use it for the AwesomeWM bridge

The prior session's last live experiment tried `lgi.Json` (Json-glib via
LGI) to serialize AwesomeWM state for the bridge in `decisions.md` §2. It
confirmed the module loads (`lgi.Json` resolves, unlike `cjson`/`dkjson`,
neither of which are installed on this host), but a real serialize
round-trip failed:

```
Error during execution: /usr/share/lua/5.4/lgi/record.lua:206:
bad argument #-1 to 'ctor' (number expected, got nil)
```

This is a genuine binding incompatibility in the installed `lgi`/Json-glib
GIR version, not a usage mistake worth debugging further — AwesomeWM's tag/
focus state is a small, flat structure (tag index per screen, focused
client class/name/screen), well within what plain Lua string concatenation
can serialize correctly and far simpler than getting a GObject-introspected
JSON builder working reliably. **Decision: `bridge.lua` hand-builds its
JSON output as a plain string** (with a small escaping helper for
client titles/names, which are the only free-text fields), no JSON library
dependency at all. Quickshell's side already has a battle-tested
`FileView { watchChanges: true }` + `JsonAdapter` pair (proven on
`theme_tokens.json`) to parse it back, so only the writing side needed a
decision.
