# DRAFT — future AGENTS.md / .hermes.md chezmoi section

**NOT APPLIED.** This is the Phase-2 step-5 draft for Ali's review.
Applying it to the live `AGENTS.md` / `.hermes.md` requires explicit
approval, and it should only go live when Phase 3 conversion begins (the
Stow model is still the operating truth until then).

It is written to REPLACE the "Stow package model", "Tree folding —
critical hazard", "my-bin package boundaries", "stow -R failure mode",
and "Package deletion and migration" sections once migration completes.

---

## Repository architecture (post-migration — chezmoi)

This repo contains source-of-truth files for personal system
configuration, managed by chezmoi and distributed by Syncthing (no git
for distribution; never run `chezmoi update` — it does `git pull`).

- Source tree: `home/` (selected via `.chezmoiroot` at the repo root).
  Attribute prefixes (`dot_`, `private_`, `executable_`, `create_`,
  `run_*`) are chezmoi conventions — never rename them casually.
- Per-host facts live in `home/.chezmoidata.toml` under `[hostFacts]`,
  keyed by hostname (zotac-box additionally branches on username in
  templates). To change what a host receives, edit its hostFacts entry
  and/or `home/.chezmoiignore` — there are no per-host package lists.
- `.chezmoi.toml.tmpl` renders the ENTIRE per-host config; it must stay
  data-free (`.chezmoidata` is not parsed at init time). Any `[age]`
  encryption settings must be added there, never by hand-editing the
  generated config.
- Scripts (`home/run_*`) are gated on `activateScripts` in
  `.chezmoidata.toml` (default false = scripts render empty and are
  skipped entirely).
- `scripts/system/` holds module assets (files destined for /etc)
  consumed by `run_after_system-modules-servalws.sh.tmpl`; they are NOT
  stow packages.

## Rules

1. DO NOT make file/config changes unless the user explicitly requests
   them. Analysis and proposed patches are fine.
2. Repository management is entirely user-owned: no git commands, no
   Syncthing operations, no cross-host coordination.
3. Source edits do not authorize live activation. `chezmoi apply`,
   service reloads, unstowing, and script activation are separate
   scopes, each requiring explicit approval.
4. Validate proportionally: `chezmoi execute-template` for template
   syntax; `chezmoi diff` (never blind apply) for change review;
   cross-host checks via containers with real `--hostname`
   (`CHEZMOI_HOSTNAME` is ignored with `--source`).
5. First apply on any host uses `--exclude=scripts`.
6. `--force` is forbidden on live hosts (drift → `chezmoi merge`).
7. `~/.local/share/` and `~/.local/state/` stay out of the source tree;
   `lazy-lock.json` is app-owned and never managed.
8. Old Stow machinery (`configure-host.sh`, stow-catalog, profiles)
   remains in the repo as reference until the retirement phase removes
   it with explicit approval.
