# Phase 4 Record — scripts activation on servalws (2026-08-19)

## Result

**COMPLETE.** All four `run_*` scripts activated and executed live on
servalws. Final live apply rc=0 with every module reporting CURRENT.
`activateScripts = true` in `.chezmoidata.toml` (revert = flip to false).
Scripts now run as part of every `chezmoi apply`.

## Pre-activation fixes (both found by the gates, fixed in tree)

1. **Asset path bug**: `run_after_system-modules-servalws.sh.tmpl` resolved
   assets from `{{ .chezmoi.sourceDir }}/scripts/system` — but sourceDir is
   `.dotfiles/home/` and assets live at `.dotfiles/scripts/system/` (one
   level up, per design/02 §9). Fixed: `MODULE_ROOT="{{ .chezmoi.sourceDir }}/.."`.
   Found by reading before the container run; render + container confirmed.
2. **Polkit cmp permissions**: live run #1 failed verify on
   `/etc/polkit-1/rules.d/49-1password-unlock.rules` — the rules.d dir is
   `0750 root:polkitd` on Fedora, so the script's plain `cmp` got EPERM
   even though content matched. Fixed: `sudo cmp` in `install_file()`
   (compare as root, same as install). Container passed this because the
   container ran as root. Live apply #2: all CURRENT, rc=0.

## Container rehearsal (gate before live)

fedora-minimal, hostname=servalws, sudo shim (dnf shielded), systemctl
shim, stub toolset binaries, pre-seeded plugin dirs. Result: apply rc=0
twice (idempotent), all six /etc targets MATCH, correct sudo set, verify
rc=0. First iteration caught harness artifacts: rehearsal copy carried the
repo's `.git` (chezmoi init planted a stub) — removing stubs + installing
git + `--source` flag for read-only checks restored verify to rc=0.

## Live activation

- Prediction pass (read-only) before flipping: all six /etc targets
  CURRENT, ly enabled+active, mate-polkit + ly installed, keyring enabled,
  thresholds 50/60 — servalws was fully converged, so activation was a
  pure verification pass with zero unintended drift.
- Flag flipped in `.chezmoidata.toml` with comment documenting the gate.
- Live apply #1: everything CURRENT except polkit (bug #2 above).
- Live apply #2 (post-fix): **rc=0, all CURRENT** —
  toolset-current, 5 tmux plugins CURRENT, gnome-keyring CURRENT,
  all six /etc files CURRENT, thresholds CURRENT, ly CURRENT,
  mate-polkit CURRENT.

## Post-activation state (verified)

- ly@tty2 + battery-charge-thresholds: enabled + active
- gnome-keyring service+socket: enabled + active (running since Jul 30)
- 5 plugin checkouts intact
- `chezmoi status` clean (only script `R` entries — remove-scheduled
  empty scripts, gone after next state refresh)
- `run_onchange` hash recorded — install-packages re-runs only when the
  toolset list actually changes

## Incidental: `note` script cross-session collision (disclosed)

Live apply #1 also materialized `.local/bin/note` from the tree — which a
**parallel agent session had rewritten at 21:20** (after my Phase-3 batch
2 at 20:49; tree mtime 2026-08-19 21:20). The audit-passing 2108-line
version (with `project | agenda` commands) was replaced by a 290-line
fuzzy-finder rewrite for the axmi vault. Both versions preserved (old in
`my-bin/.local/bin/note`, new live + in tree). bash -n passes, fzf exists,
target vault exists. **Decision belongs to Ali** — flagged in the handoff
below; I did not revert it.

## Age encryption (D4-A): nothing to do now

Tree contains zero secrets (no private key material, no `.age` files).
D4-A applies when the first real secret lands; zotac-box conversion adds
per-user age keys. Revisit at Phase 5 (docs: secrets recovery) and
zotac-box (Phase 3 repeat). Age 1.3.1 installed fleet-relevant since
Phase-1 spike.

## Exit criteria (design/03 Phase 4)

"configure-host's modules/tools/bootstrap fully replaced on servalws" —
met: packages, modules, keyring, plugins all chezmoi-managed now.

## Handoff / remaining

- **`note` version decision** (Ali): keep the sibling's 290-line rewrite
  (live + tree, consistent) or restore the 2112-line version (survives at
  `my-bin/.local/bin/note`) — then `chx ~/.local/bin/note`.
- 5 hosts remain on stow (D10-A order: minisforoum next... [see D10]).
  Phase-3 runbook applies per host (snapshot → preflight → batches);
  Phase-4 activation per host after its conversion.
- Soak period (≥1–2 weeks incl. reboot) before Phase 5 retirement.
- PARKED: delta-theme mismatch (design/06 deviation 4).
- Lesson on repo management (plan Phase 5 step 2) at process end.
