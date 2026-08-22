# Phase 3 Record — servalws live conversion (2026-08-19)

Authoritative record of the live stow→chezmoi conversion on servalws.

## Result

**COMPLETE.** All 130 stow symlinks converted to chezmoi-managed real files.
`chezmoi status` clean, full apply idempotent, zero dotfiles-pointing symlinks
remain (except `~/vimium`, a hand-placed link to the non-stow `scripts/vimium`,
untouched by design).

## Snapshot (rollback anchor)

`~/stow-to-chezmoi-snapshots/servalws-20260819-202212/`
- `symlink-manifest.txt` — all 130 links + targets (pre-conversion)
- `home-copy/` — `cp -a` of every managed target (links preserved as links)
- `ssh-real/` — the 7 real files in `~/.ssh` (config.bak*, known_hosts*,
  primary_key, primary_key.pub)
- `chezmoi-state/` — `~/.config/chezmoi` incl. chezmoistate.boltdb
- `env-facts.txt`, `doctor-output.txt`

Rollback shape (if ever needed): restore `home-copy/` links + `ssh-real/`
files, restow via `configure-host.sh`. Not executed; kept as anchor.

## Pre-flight

- Doctor: green after config render (errors pre-init were expected).
- Config: rendered from template via `execute-template` (NOT `init` — init
  plants `.git`), written to `~/.config/chezmoi/chezmoi.toml`. Byte-identical
  re-render proves the "config file template has changed" warning is cosmetic
  (configState bucket only set by `init`).
- Content audit (rendered tree vs live through-symlink): **271/275 identical**.
  The 3 diffs are the designed template changes (tmux theme selector, ssh
  dispatcher, known_hosts seed). 1 not-live: `allowed_signers` (repo-ahead,
  see below).
- Purged stale entryState bucket before conversion (U8 lesson).

## Conversion sequence (all Seq A: simulate → unstow → scoped apply → verify)

| Batch | Packages | Links | Notes |
|---|---|---|---|
| 1 | delta, picom, flameshot | 3 | leaf proof. flameshot 600 via `private_` |
| 2 | zsh, bash, git, vim, nvim, my-bin, tmux-remote(+overlay) | 51 | **lazy-lock.json seeded as real file** (was live symlink, unmanaged by chezmoi; unstow alone would float plugin pins) |
| 3 | ssh overlay | 2 | dispatcher + authorized_keys materialized by `chezmoi apply` directly (first unstow attempt was wrong package level — no-op; apply replaced symlinks per chezmoi default). known_hosts untouched (create_ never overwrites). **allowed_signers completed** (repo staged Aug 15, never stowed; completes key-on-disk signing chain) |
| 4 | wezterm, awesome, quickshell, awesome_wm_scripts, apps, 1Password | 220 | desktop trees as files (all-copies model per validated Phase-2 tree; 0 `symlink_` entries exist) |

Total: 276 UNLINKs performed; 275 chezmoi targets + 4 virtual run_* = 355
managed... correction: `chezmoi managed` = 355 (355 files incl. dirs).

## User direction incorporated mid-phase

- **1Password → key-on-disk** (user note 2026-08-19): `agent.toml` is ARCHIVED
  — removed `dot_config/1Password/` from the chezmoi tree; `.chezmoiignore`
  updated (comment documents the archive decision). The live
  `~/.config/1Password/ssh/agent.toml` link was unstowed with its package and
  NOT re-created (dead config, `~/.1password/agent.sock` no longer exists).
  `1password-signing.gitconfig` KEPT despite the name — it IS the live
  key-on-disk config (`primary_key` + `/usr/bin/ssh-keygen` + `allowed_signers`).
  Stale `1password.desktop.bkp` link removed (dead `apps`-package pointer).
- Desktop model: files, not symlinks (validated Phase-2 tree is all-copies;
  symlink_ trees were a design option never built).

## Deviations / judgment calls (all disclosed)

1. lazy-lock.json seeded as real file post-unstow (app-owned going forward).
2. ssh batch: apply replaced symlinks before the (mis-aimed, then no-op)
   unstow — same end state, snapshot-backed.
3. allowed_signers materialized (repo-ahead file; completes half-deployed
   signing change; git config already referenced it).
4. Dir-mode drift fixed via apply: `.config/flameshot` 0700→0755,
   `.local/share` 0700→0755 (flameshot daemon had recreated its dir 0700;
   chezmoi source carries stow-era 755).
5. `~/vimium` link untouched (points at non-stow `scripts/`; user-owned).

## Day-one R1 mitigation

zshrc (tree + live, byte-identical, syntax-checked): `dot`, `dot-apply`
(with `--exclude=scripts`), `dot-edit`, `dot-status`, and `chx()` =
`chezmoi add "$@" && chezmoi edit "$@"` per design/02 (anti-footgun).

## Verification evidence (final pass)

- `chezmoi status` — empty, rc=0
- Full `apply --exclude=scripts` — rc=0, second status still empty (idempotent)
- `chezmoi managed` — 355 entries
- Dotfiles-pointing symlinks — none (snapshot's internal copies excluded)
- Dangling links — only pre-existing app artifacts (pulse runtime,
  tmux-resurrect internal), none in dotfiles
- `ssh -G localhost` parses; `identityfile ~/.ssh/primary_key`
- `gpg.format=ssh`; signing chain file-based
- `zsh -n` on live zshrc — OK
- Scripts remain inert: `--exclude=scripts` on every apply; `run_*` never
  executed (Phase 4 scope)

## Handoff to Phase 4

- Scripts activation (`activateScripts=true` or include removal) — per-host
  pacing per design/03.
- age encryption per D4-A pacing.
- PARKED: delta themes.gitconfig path mismatch (`.config/delta/` vs
  `.config/`) — fix deliberately post-migration (deviation 4 in design/06).
- future-AGENTS-draft.md still awaiting approval (repo AGENTS.md rewrite).
- Other hosts: repeat this runbook (snapshot → preflight → batches).
- Visual acceptance: user observes awesome/wezterm/quickshell on next reload
  (running sessions keep loaded config; files replaced underneath).
