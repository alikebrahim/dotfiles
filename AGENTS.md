# Agent instructions for this dotfiles repo

This file applies to all agent work inside `~/.dotfiles`.

## Non-negotiable rules

1. DO NOT make file/config changes unless the user explicitly requests the change.
   - Analysis, recommendations, proposed patches, and explanations are fine.
   - Do not treat implied interest, troubleshooting discussion, or "how would this work?" as permission to edit.
   - If uncertain, present the proposed change and wait for explicit authorization.

2. DO NOT perform git-related operations unless the user explicitly requests them.
   - Do not run `git add`, `git commit`, `git checkout`, `git reset`, `git clean`, `git stash`, `git mv`, `git rm`, `git pull`, `git push`, or similar commands without explicit instruction.
   - Do not create branches, rewrite history, stage files, discard changes, or clean untracked files unless explicitly requested.
   - Read-only git inspection is also best avoided unless needed for the user's request; prefer ordinary file inspection tools when possible.

## Repository architecture

This repo is **synced across machines via Syncthing** and **backed up via git** (remote: `git@github.com:alikebrahim/dotfiles`).

### Sync model

- **Syncthing** propagates changes between hosts automatically (not `git pull`). The `.stignore` file controls what Syncthing syncs.
- **Git** is the backup and change-tracking layer. The local git user is `dotfiles.agent <dotfiles.agent@axminet>`.
- **Git procedure**: Any changes made by the agent must be committed with a clear commit message and a descriptive/detailed commit body. Do not push unless asked.
- Changes made on one host propagate to others via Syncthing. **Always verify Syncthing sync completion on all hosts before deploying** (running `stow-host.sh`).
- Never create absolute symlinks in the repo. Syncthing syncs them across hosts where the target paths do not exist. Use relative symlinks only.

### Stow package model

- **GNU Stow 2.3.1** is installed fleet-wide. It has **no `--no-folding` flag** (added in 2.4.0).
- Deployment is via `static/stow-host.sh` — detects hostname, unstows all packages, stows host-appropriate packages, installs tmux plugins, reloads tmux.
- Per-host SSH config overlays use `--dir=ssh` (e.g., `ssh/netmaster/`, `ssh/servalws/`).
- Per-host tmux themes use base `tmux-remote/` + overlay `tmux-remote-HOST/` packages.
- Run `bash ~/.dotfiles/static/stow-host.sh` AFTER Syncthing sync completes, not before.

### Tree folding — critical hazard

GNU Stow "tree-folds" when the target directory contains only content from one package. Instead of creating individual file symlinks, Stow replaces the entire target directory with a single symlink pointing into the repo.

If `~/.local` gets tree-folded to `.dotfiles/my-bin/.local`, then all per-host runtime data (`~/.local/state/`, `~/.local/share/`) physically lives inside the Syncthing-synced repo. This creates a feedback loop where host-specific data (npm, nvim plugins, uv Python, Syncthing DB, etc.) syncs to every host.

**Prevention (already in place):**
- `my-bin/.stow-local-ignore` excludes `.local/share` and `.local/state` from Stow.
- `stow-host.sh` creates `~/.local/state/` as a real directory before stowing `my-bin`, preventing tree folding.
- `stow-host.sh` refuses to stow `my-bin` if `~/.local` is already a symlink (tree-folded).
- `static/check-fold.sh` diagnoses folding across all hosts and can fix folded hosts with `--fix`.

### my-bin package boundaries

- `my-bin` contains **only `.local/bin/`** with shared scripts (aiw, note, x11_connections_check, fix-nvidia-suspend.sh).
- `hermes` is excluded from the repo via `.stignore`. Each host maintains its own `~/.local/bin/hermes` as a real file pointing to the host-local Hermes venv path. This prevents cross-host path breakage.
- `.local/share/` and `.local/state/` must **never** be in the repo or synced via Syncthing.
- Host-specific binaries installed to `~/.local/bin/` (e.g., `uv`, `ente`, `pip install --user`) are real files alongside the symlinks. They do **not** enter the repo and do **not** sync.
- The `.stignore` file excludes `my-bin/.local/share` and `my-bin/.local/state` from Syncthing.

### stow -R failure mode

`stow -R` (restow) does **delete-then-create**. If the create phase hits a real file conflict (a non-symlink file in the target that matches a repo file), it aborts — leaving the deleted symlinks uncreated. This silently removes access to scripts.

**Before recommending `stow -R my-bin`**, check each host for real files in `~/.local/bin/` matching repo scripts. Either remove them or use `stow -R --adopt` to convert them to symlinks.

### Pre-deletion verification across hosts

Before deleting any file or directory from the repo, check all hosts for symlinks that point into the deleted path. Use SSH to run `find ~/.local -type l` and filter for `.dotfiles` targets. A deletion propagated by Syncthing will break those symlinks on every host.

### zotac-box dual-user setup

zotac-box has two users:
- `alikebrahim` (uid 1001): primary, Syncthing runs here, dotfiles at `/home/alikebrahim/.dotfiles`
- `tima` (uid 1000): secondary, accesses dotfiles via symlink through `shared` group

The `stow-host.sh` script detects hostname only, not the running user. Both users get the same package list. tima's `~/.local/state/` must be a real dir (the safety check in `stow-host.sh` handles this).

## General dotfiles workflow

- Prefer minimal, targeted edits over broad rewrites.
- Preserve existing structure, comments, and conventions unless the user asks for cleanup/refactoring.
- Avoid baking machine-specific choices into shared configs unless the user says that package is machine-specific.
- Prefer synced defaults plus machine-local overrides for per-host state, themes, and selections.
- Be careful with Stow packages: package directory names matter because existing symlinks may point into them.
- Do not rename, delete, or reorganize Stow packages without calling out the migration impact first.
- Do not assume live files under `$HOME` and repo files are identical; inspect the intended source of truth.
- When adding new files, use conventional casing and names. For agent guidance, use `AGENTS.md` at the repo root.

## User preferences learned for this repo

- The user generally uses WezTerm multiplexing locally, not local tmux. Treat the old `tmux/` package as reference unless the user explicitly revives it.
- Remote machines use `tmux-remote` and SSH auto-attach to `ssh_tmux:system`.
- Remote tmux should stay generic across machines; avoid hardcoded paths such as `/home/pi/...`.
- Remote tmux/editor clipboard should use OSC52 through WezTerm, not `tmux-yank`, `xclip`, `wl-copy`, or remote GUI clipboard tools.
- Remotes can be assumed modern: Ubuntu 22.04+ or Fedora 44, with Vim 9.1+.
- Vim is used for lightweight text editing and should remain plugin-free.
- Neovim is used for programming.
- WezTerm top/tab bar styling should use classic text labels, not Nerd Font icons. Keep tab labels in `1:title` form and left status labels like `[home] |`.
- User's WezTerm config is intended for the main machine, so machine-specific visual choices there are acceptable.
- Shared tmux/theme choices should avoid forcing one machine's active theme onto all machines.

## Validation expectations

- For shell files, run syntax checks after edits when available:
  - `zsh -n <file>` for zsh files.
  - `bash -n <file>` for bash files.
- For AwesomeWM Lua config, prefer `awesome -k` from the config directory over generic Lua parsing.
- For Neovim Lua, use a headless Neovim check when practical.
- For tmux config, be mindful that theme/plugin paths may be machine-local; if a direct tmux source check fails because of missing local theme/plugin files, report that clearly rather than overfitting the config.
- After edits, summarize exactly what changed and mention any verification performed.

## Safety notes

- Do not detach, kill, respawn, or otherwise alter live tmux sessions unless explicitly requested.
- Do not remove apparently stale clients/sessions/windows without explicit approval.
- Do not delete stray-looking files without asking first.
- Do not overwrite local machine-specific files unless the user identifies them as the intended target.
- Do not delete repo files without first verifying no host has symlinks pointing into the deleted path.
