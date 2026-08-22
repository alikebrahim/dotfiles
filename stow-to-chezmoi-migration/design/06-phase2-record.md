# Phase 2 Build Record — the `home/` source tree

**Completed: 2026-08-19. Exit gate PASSED** (six-host container matrix +
fresh-container smoke test). This is the authoritative record of what was
built, every deliberate deviation from design/02, and every bug the
validation caught and killed. Read this before touching the tree.

## What was built

`~/.dotfiles/home/` — the chezmoi source tree (299 files), consumed via
`.chezmoiroot` at the repo root:

- **Bulk copy, 287 files** from the 20 packages all hosts or some hosts
  actually receive, with mode-derived attribute prefixes (`dot_`,
  `executable_` ×30, `private_` ×3). Two `private_` misses caught and
  fixed during fidelity verification (rust.lua, tldraw.desktop — both
  0600 live).
- **`.chezmoidata.toml`** — shared data (git identity, theme library
  lists) + the `[hostFacts]` table: one entry per machine with tmuxTheme,
  uiTheme, toolset, and the selection booleans (desktop/apps/onepassword/
  wezterm/systemModules), faithful to `scripts/profiles/*.conf` including
  zotac-box's `"tima-only"` apps value. Plus the `[tools]` registry
  porting `scripts/lib/tools.sh` toolset→list resolution.
- **`.chezmoiignore`** — target-relative selection template keyed on
  hostname/user gating, replacing per-host package lists. honor's
  known_hosts excluded (that host manages it outside the repo).
- **`.chezmoi.toml.tmpl`** — the whole-config render (sourceDir + umask +
  diff scripts-exclude). Deliberately data-free (see deviation 1).
- **`.chezmoiversion`** — minimum chezmoi version floor. Ships
  `2.72.0` (raised from an initial 2.62.0 draft; Ali, 2026-08-19:
  "raise version to latest, I'll ensure all machines run the latest").
  2.72.0 is also the reference build every container validation ran on.
- **`.chezmoitemplates/ssh/`** — per-host ssh config + authorized_keys
  fragments (public-key material, plaintext visibility unchanged).
- **`dot_ssh/`** — `config.tmpl` dispatcher (hostname + username branch
  for zotac-box), `private_authorized_keys.tmpl` dispatcher,
  `private_allowed_signers`, `create_private_known_hosts` seed
  (non-empty: comment lines, per spike S2).
- **`dot_tmux/theme.conf.tmpl`** — the theme selector replacing six
  tmux-remote-HOST overlay packages: renders the active
  `source-file ~/.tmux/themes/<theme>.conf` line from hostFacts, plus a
  comment pointing at the data file for edits.
- **Four `run_*` scripts, inert by design**: install-packages
  (`run_onchange_`, toolset→package list, dnf/apt, MANUAL hints for
  yazi), system-modules-servalws (`run_after_`, sudo install -D + cmp
  self-verification), gnome-keyring user units (`run_after_`), and
  ensure-tmux-plugins (`run_after_`, clone-missing-only, never pulls).
  Off-switch: whole-script `{{- if activateScripts -}}` wrap — inert
  renders are 0 bytes, which chezmoi skips entirely.
- **`lazy-lock.json` excluded** — LazyVim app-rewrites it (gitignored
  today); chezmoi must never fight it.

## Deliberate deviations from design/02 (reviewed with Ali)

1. **Hostname-keyed `hostFacts` data instead of interactive init
   prompts.** All per-host facts live declaratively in
   `.chezmoidata.toml` keyed by hostname, not gathered via
   `promptStringOnce`/`promptChoiceOnce` at first init. Simpler v1: no
   TTY dependency, deterministic, testable in containers (a prompt
   wizard can't be driven by a test harness). Documented as a deliberate
   deviation; interactive init remains available later for the age
   passphrase bootstrap.
2. **Never-selected packages skipped**: alacritty, atuin, posting,
   postman, bin — no host selects them, so migrating them would deploy
   files no host gets today (D9 disposition). They survive in repo
   history for deliberate revival.
3. **authorized_keys plaintext `private_` copies** (0600 on disk), one
   per host — public-key material, same visibility as today; age
   encryption deliberately deferred per D4-A pacing (move house first,
   install the safe later).
4. **`.gitconfig` → `~/.config/delta/themes.gitconfig` include
   mismatch: preserved, documented, NOT fixed.**
   `.gitconfig` includes `~/.config/delta/themes.gitconfig`, but the
   delta package ships the file at `~/.config/themes.gitconfig`. This is
   a pre-existing latent break in the CURRENT system: git silently
   loads nothing from that include today. Phase 2 copies it faithfully.
   **PARKED (Ali, 2026-08-19): fix deliberately after the migration is
   confirmed OK** — as its own visible one-line change (either move the
   file or fix the include path), so any delta-colors change is
   attributable. Do not silently reconcile during Phase 3/4/5.

## Validation evidence (all 2026-08-19, chezmoi 2.72.0)

- **Six-host container matrix** (podman fedora-minimal, real
  `--hostname` per host, repo `:ro` + `--security-opt label=disable`,
  host binary mounted): apply rc=0 on all six; second apply idempotent;
  `diff` clean; managed file counts 56/275/86/56/56/55 exactly match
  the old profile matrix; per-host tmux themes correct
  (green-phosphor/orange-gas-plasma/commodore-64/ibm-5153-cga/
  amber-crt/green-phosphor); ssh dispatch per host; zotac-box
  username-gated apps; honor receives no known_hosts (by design).
- **Smoke exit gate** (fresh container, Syncthing model — no git):
  `chezmoi init --source <repo>/home` renders the config template
  cleanly → `apply` rc=0 → `verify` exit 0 → idempotent → modes
  faithful: ssh config 644, authorized_keys 600, known_hosts 600,
  zshrc 644.
- **Script off-switch proven both ways**: inert tree renders all four
  scripts to 0 bytes (no execution at all); a flag-flipped copy
  (`activateScripts = true`) renders valid bash — shebang first line,
  `bash -n` clean — with per-host toolset resolution verified
  (servalws `desktop-full` → full 10-tool list; honor empty toolset →
  skip path; servalws-only scripts render empty on other hosts).
- **Bugs caught and fixed during validation** (the point of the gate):
  - `include` takes ONE arg; resolves from SOURCE ROOT, not
    `.chezmoitemplates/` → dispatchers use
    `include ".chezmoitemplates/ssh/<frag>.tmpl"`.
  - System-modules gate read top-level `.systemModules` (nonexistent)
    → now `(index .hostFacts .chezmoi.hostname).systemModules`.
  - install-packages embedded the toolset NAME ("developer") not the
    resolved list → now resolves via `[tools]` and embeds
    `TOOLSET="zsh tmux delta ... yazi"`.
  - Go-template quoting: `join \" \"` → `join " "` (backslashes are
    literal inside `{{ }}`).
  - `.chezmoi.toml.tmpl` had a `[data]` mirror of hostFacts — but
    `.chezmoidata` is NOT parsed at init time, so the mirror broke
    fresh-host bootstrap. Removed; all templates read hostFacts
    directly (validated by the config-less six-host matrix).
  - known_hosts seed was `create_` (644) → `create_private_` (600,
    matching the live file ssh maintains).
  - Inert scripts initially rendered `exit 0` + trailing newline →
    now 0 bytes via `{{- end -}}` right-trim (empty scripts skip).
  - `.chezmoiignore` type-strictness: `eq $facts.apps "tima-only"`
    errors when apps is a bool on other hosts → hostname-gated check.
  - awesomewm-bin scripts (`theme-apply`/`theme-select`) initially
    leaked to all hosts → now gated under desktop.
  - Test-harness traps (not tree bugs): rootless `--user 1001:1001`
    breaks uid mapping (0600 fragments unreadable — drop the flag);
    `CHEZMOI_HOSTNAME` is IGNORED with `--source` on this build —
    per-host gating tests MUST use containers with real `--hostname`.

## Open items for Ali's review

- Tree layout review (Phase-2 exit criterion: "Ali reviews the tree
  layout").
- ~~`.chezmoiversion` value~~ RESOLVED (Ali, 2026-08-19): raised to
  `2.72.0`. Ali takes responsibility for machine currency — every host
  must run chezmoi ≥ 2.72.0 before its Phase-3 conversion.

## Handoff to Phase 3

- Convert servalws first (D10-A pilot order), mandatory `cp -a` snapshot
  gate before anything else.
- Seq A per-package: author (done — this tree) → unstow that package →
  apply → verify. The unstow→apply gap is seconds; per-package
  granularity bounds it.
- First full apply on each host: `--exclude=scripts` (files only);
  scripts activate in Phase 4 by flipping `activateScripts` per host.
- `.git` planting on init is spike-documented (U1) and benign for a
  Syncthing repo; Phase 3 runbook should note `chezmoi init` may plant
  an empty `.git` in the source dir — expected, ignore or remove.
- Fedoracity note: the fedora-minimal podman image is still cached on
  servalws for Phase 3 rehearsals.
