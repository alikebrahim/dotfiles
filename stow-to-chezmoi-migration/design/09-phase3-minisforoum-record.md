# Phase 3 Record — minisforoum conversion (2026-08-21)

## Result

**COMPLETE.** All 43 stow symlinks converted to chezmoi-managed real files
in 3 batches (9 + 2 + 17 = 28 UNLINKs; the rest of the 43 were dirs whose
links vanished with their package). `chezmoi status` clean except the two
benign `R` entries for the still-inert `run_*` scripts (activateScripts
false — Phase-4 activation on this host is a separate later step).
Full apply idempotent. Snapshot:
`~/stow-to-chezmoi-snapshots/minisforoum-20260821-200903/`.

## User decisions executed this conversion

1. **Same key on both machines**: servalws's `primary_key` scp'd to
   minisforoum (`scp -3` attempt failed — servalws is the local host;
   direct copy). Fingerprints verified identical
   (`SHA256:CJVWG3OA17beS9T/qJTlgBIX+vhGry4tJuNv6AQO+Ro`), mode 0600.
2. **Key-on-disk SSH**: `.chezmoitemplates/ssh/minisforoum.tmpl` rewritten
   from IdentityAgent-routed to `IdentityFile ~/.ssh/primary_key`
   (+ `IdentitiesOnly yes`), mirroring servalws's fragment; minisforoum's
   own host list preserved (netmaster SetEnv LC_TMUX_DEVICE=minisforoum).
   agent.toml stays archived out of the tree; live link unstowed, not
   recreated.
3. **Apps materialized**: 9 desktop files + 25 icons deployed (hostFacts
   `apps = true` kept).

## New lessons (folded into skill ref phase3-conversion.md)

- **Bootstrap config BEFORE any unstow**: batch 1's apply failed
  (`stat ~/.local/share/chezmoi: no such file`) because no
  `~/.config/chezmoi/chezmoi.toml` existed — preflight had masked it with
  explicit `--source`. Unstow had already run; files were absent for
  ~1 minute until `execute-template` bootstrap + retry. On the next host:
  config bootstrap is step 1, before batch 1.
- **Unmanaged-path targets abort the apply atomically**: passing
  `~/.config/1Password` (archived, unmanaged) as a scoped-apply target
  fails the whole invocation — nothing written. Drop unmanaged paths from
  target lists; the archive means the live link simply disappears on
  unstow (intended).
- **known_hosts.old**: hand-placed alias to the overlay's known_hosts
  (package file stays in repo) — keeps working, left alone, like
  servalws's `~/vimium`.
- Host-local `~/.local/bin` real files (hermes, uv, pi, monolith,
  screenrecord, tectonic) coexist untouched — my-bin conversion only
  replaces its own 12 links.

## Verification (all green)

- `ssh -G localhost`: identityfile ~/.ssh/primary_key + IdentitiesOnly yes
- Signing chain: user.signingkey = ~/.ssh/primary_key;
  gpg.ssh.allowedSignersFile = ~/.ssh/allowed_signers (half-deploy
  completed, same as servalws)
- known_hosts untouched (Jun 30 mtime preserved)
- zshrc (aliases live) + note (290-line canonical) syntax OK
- 9 desktops / 25 icons; nvim + wezterm real dirs
- Dangling links: only pre-existing Chrome/Obsidian Singleton* artifacts

## State after conversion

- stow packages all still in repo (retirement = Phase 5, after fleet soak)
- `run_*` scripts present but inert (`activateScripts = false`);
  status shows 2 benign `R` entries until activation
- Next host per D10-A: netmaster (Ubuntu — first apt-side conversion;
  install-packages script's apt branch still untested live)
