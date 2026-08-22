# Phase 3 Record — macbook conversion (2026-08-22)

## Result

**COMPLETE.** All 40 stow symlinks converted to chezmoi-managed real
files in 3 batches (25 + 21 + 3 = 49 UNLINKs across shells/nvim/bin/
ssh). `chezmoi status` clean except the two benign inert-script `R`
entries. Full apply idempotent. Snapshot:
`~/stow-to-chezmoi-snapshots/macbook-20260822-111848/`.

## Host specifics

- **Not actually a Mac**: Fedora 44 LXDE on ARM-class hardware named
  "macbook" — Linux recipe applied unchanged.
- **Own SSH identity kept**: fragment already file-key based with
  dedicated `~/.ssh/alikebrahim@macbook_key`; no rewrite needed
  (`ssh -G servalws` resolves correctly; note github.com has no block
  in this fragment — ssh defaults apply there, pre-existing behavior).
- **Both known traps present and both handled cleanly**:
  - `known_hosts` was a LINK → capture-before-unstow + restore-before-
    apply (netmaster lesson) → 15 entries byte-identical, 600.
  - `lazy-lock.json` was a stow LINK (servalws trap) → captured before,
    restored in the unstow→apply gap → macbook's own 47-line version,
    byte-identical; chezmoi never manages it.
- **Host-local bins preserved**: hermes, node/npm/npx, python3.11, uv,
  uvx, website-builder — untouched; tree scripts materialized alongside
  with zero collisions.

## Applied lessons (no new ones needed)

Config bootstrap before any unstow; capture-and-restore for seeded
targets; per-host bin list from actual probe output. First host where
the runbook covered everything that came up.

## Verification (all green)

- residual dotfiles links: NONE
- zshrc OK (aliases live); note = 290-line canonical
- amber-crt theme rendered from hostFacts
- allowed_signers materialized (half-deploy completion)
- `A .config/git` on first status = empty parent dir created by apply
  (signing gitconfig correctly ignored for this host); benign

## State

Remaining hosts: zotac-box (dual-user), honor. Scripts stay inert until
per-host Phase-4 activation.
