# Phase 3 Record — netmaster conversion (2026-08-21)

## Result

**COMPLETE.** All 38 stow symlinks converted to chezmoi-managed real
files in 3 batches (24 + 3 + 9 = 36 UNLINKs; remainder were dirs).
`chezmoi status` clean after full apply except the two benign `R`
entries for still-inert `run_*` scripts. Snapshot:
`/home/hostmaster/stow-to-chezmoi-snapshots/netmaster-20260821-210137/`.

## Netmaster specifics (first non-servalws-shaped host)

- **First ARM host**: chezmoi v2.72.0 installed via get.chezmoi.io to
  `~/.local/bin` (no sudo), arm64 build, tag-pinned.
- **Different user**: `hostmaster` — config template is data-free so
  renders correctly; `.chezmoiignore` already excluded the signing
  gitconfig (hardcoded `/home/alikebrahim` paths) from this host.
- **Own SSH identity kept**: fragment already file-key based with
  dedicated `~/.ssh/hostmaster_key` (outgoing as hostmaster + `axmi-*`
  aliases as alikebrahim + github). NOT converted to primary_key — Ali's
  same-key decision was minisforoum-specific. Verified functional:
  `ssh -G github.com` → identityfile ~/.ssh/hostmaster_key.
- **known_hosts was a LINK here** (first host where this happened) —

## Incident: known_hosts seed clobbered accumulated entries

The unstow removed the link → `create_private_known_hosts` seeded its
4-line comment stub → the live 32-entry host-key history was gone from
the target (content safe in repo package + pre-captured copy). Restored
from the pre-unstow capture within ~1 minute: byte-identical, 600,
32 entries. **Root cause: the seed design assumed a pre-existing real
file (true on every prior host). On a host whose known_hosts is still a
stow link, the correct sequence is: capture content → unstow → cp
content back BEFORE apply** (or accept the seed then restore).

## Lessons added to runbook

1. Config bootstrap before any unstow (from minisforoum) — applied here,
   zero gap this time.
2. NEW: create_-seeded files vs linked live files — capture-and-restore
   sequence above.
3. Host-local bin lists differ per machine — verify against actual
   pre-check output, not another host's list (my checklist printed four
   false "LOST" lines for binaries netmaster never had).

## Verification (all green)

- status clean; full apply idempotent (absorbed .config/.config/nvim
  dir-mode drift, same class as servalws)
- residual dotfiles links: NONE
- zshrc OK (aliases live); note = 290-line canonical; netgit parses
- known_hosts: real file, 600, 32 entries intact
- protected host-local bins (hermes, hermes-acp, uv, uvx) untouched
- tmux theme green-phosphor rendered from hostFacts

## State

- stow packages remain in repo until Phase 5 retirement
- scripts inert (activateScripts false); Phase-4 activation later per host
- Remaining hosts: zotac-box (dual-user, highest complexity), macbook,
  honor
