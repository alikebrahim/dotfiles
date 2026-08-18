# Benefit Mapping — Pain Points of the Current System vs chezmoi Features

Synthesis of `analysis/01-current-system.md`, `analysis/02-repo-inventory.md`,
`research/01-chezmoi-features.md`, and `research/02-articles-videos.md`.

The current system is a well-built desired-state orchestrator (~4,800 lines of
Bash across 13 libraries + ~1,590 lines of deploy tests) — but a large
fraction of that machinery exists to keep GNU Stow from hurting us. This
document maps each pain point to the chezmoi mechanism that removes or
simplifies it, and lists honestly what we would lose.

---

## 1. Pain points → chezmoi features

### A. Stow's structural hazards (the biggest simplification)

| # | Pain point today | Current machinery | chezmoi mechanism | Effect |
|---|---|---|---|---|
| A1 | **Tree folding of `~/.local`**: stow can replace a whole target dir with one symlink into the repo, trapping host runtime data (npm, nvim plugins, uv envs) inside the synced repo | `STOW_SAFETY_DIRS` real-dir checks, apply refuses on symlink, `check-fold.sh` SSH audits + `--fix`, safety `mkdir -p` | chezmoi manages directories natively; **folding is impossible** (a dir in source state maps to a real dir in target state) | Entire fold-prevention machinery retires |
| A2 | **`stow -R` delete-then-create**: a mid-apply conflict silently unlinks previously managed files | simulate-then-restow, failure recovery text, conflict report | chezmoi computes a diff and only touches what changed; atomic per-file writes (temp+rename) | No delete-then-create path exists |
| A3 | **BLOCKED real-file conflicts** (e.g. a live file shadows a package file); `--adopt`/`--force` refused | conflict scan, refusal everywhere | `chezmoi diff` shows exactly what would change; apply prompts before overwriting locally-modified files | Conflicts become visible, reviewable diffs instead of hard blocks |
| A4 | **Orphan symlink cleanup** after source deletions | re-verified orphan scan | Declarative removals (`remove_`, `.chezmoiremove`, `exact_`); no dangling links left behind | Orphan machinery retires |
| A5 | **Prune ceremony**: unstow needs double confirmation, explicit IDs, separate command | `prune --stow-package` | `chezmoi forget`/`remove`/`unmanage`; git history is the undo | Simpler, still reviewable |
| A6 | **`.stow-local-ignore`** + in-house mirror parser to keep host state out of stow | per-package ignore files + `_stow_load_ignore_patterns` | `.chezmoiignore` (always a template) — the standard, more powerful mechanism | One mechanism, documented |
| A7 | **Stow version skew** (repo pins 2.3.1, host runs 2.4.1, `.stowrc --no-folding` invalid on 2.3.1) | latent landmine for older hosts | Retired with stow | Gone |

**Result:** mechanisms 1–7, 12, 13 of the safety table in
`analysis/01-current-system.md §10` — the majority of the orchestrator — have
no reason to exist.

### B. Per-host variance expressed as package proliferation

| Pain point | Today | chezmoi |
|---|---|---|
| 6 near-duplicate tmux theme overlays (`tmux-remote-<HOST>`), each a separate package with one file | base package + per-host overlay packages | one `dot_tmux/theme.conf.tmpl` rendering `{{ .tmuxTheme }}` from per-machine data |
| 7 SSH overlay dirs (`ssh/<host>/`), applied via a constrained second stow invocation | `ssh-overlay.sh` pseudo-package | one `dot_ssh/config.tmpl` dispatcher including per-host fragments (`.chezmoitemplates/ssh/<host>.tmpl`), selected on `.chezmoi.hostname` |
| zotac-box per-user subpackages (`alikebrahim_zotac-box`, `tima_zotac-box`) — the only per-user path in the system | `PROFILE_SSH_OVERLAY="zotac-box/${PROFILE_USER}_zotac-box"` | `.chezmoi.username` conditionals + per-user config + per-user age identity |
| Package selection per host (`scripts/profiles/<host>.conf` + catalog) | 7 profile files + 31-entry catalog + validation | `.chezmoiignore` template (install-everything-by-default, ignore per host); `chezmoi ignored` lists the effective selection |
| Tools per host (`PROFILE_TOOL_SET`) | `tools.sh` registry + sets | data key (e.g. `.toolset`) driving one `run_onchange_` install script |

One theme change today touches the base + every overlay. With chezmoi it is
one data value per machine and one template.

### C. Two-and-a-half desired-state subsystems

Today three separate engines manage three things:
1. stow packages (home dir),
2. tmux plugin clones (`install-tmux-plugins.sh` + doctor check),
3. system/user modules + tools (`module-runner.sh`, `tools.sh`).

chezmoi unifies 1 and 2 (externals or scripts for plugins, §6 of the features
doc) and absorbs 3 via `run_*` scripts. One engine, one `apply`, one `diff`.

### D. Drift visibility

Today: per-package link accounting (CURRENT/ABSENT/DRIFT/BLOCKED); per-file
diffs are not available, so real drift diagnosis means reading status output
carefully.

chezmoi: `chezmoi status`, `chezmoi diff` (unified per-file diffs), `chezmoi
verify` (exit-code checkable), `chezmoi managed/unmanaged/ignored` inventory.
Strictly stronger diagnostics with zero custom code.

### E. Secrets in plaintext

Today: SSH configs (hosts, users, ports, key paths) sit **unencrypted** in the
synced repo; `known_hosts` files are repo-managed (and gitignored); the
`1Password/` package is gitignored-but-synced.

chezmoi:
- `encrypted_` + age for whole-file encryption at rest (per-user recipients;
  docs-endorsed passphrase-protected `key.txt.age` bootstrap pattern);
- `private_` for 0600 permissions (not encryption — docs warn);
- `create_` for `known_hosts` seeds — create only if absent, then ssh owns the
  file (solves the write-on-use symlink-break problem permanently);
- 1Password functions available (we already run `op` for git signing) but
  deferred — see design doc, decision D4.

### F. New-machine bootstrap

Today: install stow/gum/flock (`bootstrap`), then `check → plan → apply` with
the gum dashboard; macbook (macOS) and honor (Termux) have **no native package
flow at all**.

chezmoi: one command per machine —
`sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply <repo>` — single static
binary, no root, official builds for Linux/macOS/Termux. `run_once_*` scripts
take over provisioning. `--one-shot` even covers ephemeral containers.

### G. Daily update flow

Today: Syncthing propagates the repo; then apply per host; git is history-only.

chezmoi (with Syncthing kept as distribution — see D1): the daily command
becomes `chezmoi apply` (or `chezmoi diff` first). Same discipline, one word,
plus `chezmoi update` available if we ever switch to git distribution.

### H. Legacy surface

Empty `bin/` package, stray root `.zshrc`, a file literally named `\` in
`wezterm/`, duplicated asset trees, 5 `-archived` dirs, gitignored `1Password/`
package. With `.chezmoiroot` scoping source state to `home/`, **all of this
becomes inert** — it stops being deployable surface without deleting anything.
Cleanup can happen leisurely with explicit approval.

---

## 2. What we lose (and mitigations)

| Capability today | Loss | Mitigation |
|---|---|---|
| **System-file rollback manifests** (runner + `rollback RUN_ID`, backups of `/etc` files) | chezmoi has **no rollback/backup** (verified: no backup command, no apply flag) | git history + `chezmoi diff -n -v` review before apply + prompts before overwriting; optional small pre-apply snapshot script if we want belt-and-braces for `/etc` modules |
| **Declarative root-owned file install** (`install -D` modules for `/etc/ly`, polkit, X11, systemd units) | chezmoi manages `$HOME`; root files are "strongly discouraged", scripts+sudo only | Port modules to idempotent `run_after_`/`run_once_` scripts with sudo (they already are idempotent); keep `cmp`-based self-verification discipline |
| **Named package catalog + profile validation** | no package concept in chezmoi | `.chezmoiignore` + `chezmoi ignored`; data-driven feature flags; the catalog's "top-level dirs never inferred" guard becomes moot |
| **gum session dashboard + UI themes** | chezmoi is CLI-first | Shell aliases/functions; optional thin gum wrapper later (decision D8); theme data can be reused |
| **Immediate write-through** (edit repo file = live on every synced host) | default copies require `chezmoi apply` after edits | Hybrid file model: `symlink_` for the files we actively develop (decision D2); `chezmoi edit --watch`; add-then-edit helper |
| **Structured run ledger + history** | no equivalent | `chezmoi history` (via git) + state DB; document diff-review habit |
| **Doctor's catalog/fold audits** | obsolete (their subjects disappear) | `chezmoi doctor` is a superset of environment checks; keep `check-wm-servalws.sh` as WM-specific diagnostic |

---

## 3. Simplification estimate

Order-of-magnitude, to be validated during the spike:

- Current: ~4,800 lines orchestrator + ~1,590 lines deploy tests + 13 libs +
  31-entry catalog + 7 profiles + 13 overlay packages.
- Target: a `home/` source tree (1:1 files, most needing no code at all) +
  a handful of templates (ssh config, tmux theme, gitconfig, ignore rules) +
  4–8 idempotent scripts + one container smoke test replacing the deploy test
  suite. The per-file logic mostly *disappears*; what remains is declarative
  data.

## 4. What stays regardless

- **Syncthing** as the distribution channel (decision D1) and its `.stignore`
  discipline; git stays history/authoring-only as today.
- **`hermes`** per-host real file: stays unmanaged (`.chezmoiignore`).
- **System modules' content** (unit files, ly config, polkit rules, Xorg conf):
  the *assets* stay in the repo; only the delivery mechanism changes.
- **1Password git signing**: untouched, external to chezmoi.
- **The user's rules**: no agent git ops, explicit approval for any live
  deployment — the migration plan (03) builds its approval gates around them.
