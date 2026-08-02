# Agent instructions for this dotfiles repo

This file applies to all agent work inside `~/.dotfiles`.

## Non-negotiable rules

1. DO NOT make file/config changes unless the user explicitly requests the change.
   - Analysis, recommendations, proposed patches, and explanations are fine.
   - Do not treat implied interest, troubleshooting discussion, or "how would this work?" as permission to edit.
   - If uncertain, present the proposed change and wait for explicit authorization.

2. Repository management is entirely user-owned and outside the agent's scope.
   - Never run Git commands, including read-only commands such as `git status`, `git diff`, `git log`, or `git branch`.
   - Never stage, commit, push, pull, reset, restore, clean, stash, branch, merge, or otherwise manipulate repository history or working-tree state through Git.
   - Never inspect, operate, troubleshoot, or verify Syncthing. Do not wait for synchronization, coordinate synchronization between hosts, or resolve synchronization conflicts.
   - After authorized edits, report the exact files changed. The user handles review, history, backup, synchronization, and propagation.
   - Do not make Git or Syncthing state a prerequisite, validation step, or completion criterion for configuration work.

3. Source edits do not authorize separate live or deployment operations.
   - Approval to edit files does not authorize process restarts, service reloads, live IPC mutations, Stow deployment, hardware mutations, or changes on other hosts.
   - If an approved source edit is expected to trigger an unavoidable automatic live reload, disclose that effect before editing.
   - Obtain separate explicit authorization for any additional live activation or deployment step.

## Repository architecture

This repo contains source-of-truth files for personal system configuration. Some files may already be consumed through live symlinks, so identify the intended source and expected live effect before editing.

- Never create absolute symlinks in the repo; they are not portable across hosts. Use relative symlinks only.
- The user owns all repository history and cross-host propagation. Agent work is limited to authorized content changes and their local, task-relevant validation.

### Stow package model

- **GNU Stow 2.3.1** is installed fleet-wide. It has **no `--no-folding` flag** (added in 2.4.0).
- **Deployment engine is `scripts/configure-host.sh`** (desired-state: tools, catalogued Stow packages, SSH overlay, system/user modules).
- `scripts/stow-host.sh` is a **narrow compatibility wrapper** around `configure-host.sh --scope stow` only. Prefer `configure-host.sh` for full host setup.
- Stow packages must be registered in `scripts/lib/stow-catalog.sh` and listed in `scripts/profiles/common.conf` and/or host `PROFILE_EXTRA_STOW_PACKAGES`.
- Per-host SSH config overlays use `--dir=ssh` (e.g., `ssh/netmaster/`, `ssh/servalws/`).
- Per-host tmux themes use base `tmux-remote/` + overlay `tmux-remote-HOST/` packages.
- Run `bash ~/.dotfiles/scripts/configure-host.sh plan` before an explicitly authorized `apply`.
- Safe apply uses simulate-then-restow; `--adopt` / `--force` are refused. Explicit unstow is `configure-host prune --stow-package NAME` (double confirm).
- Host-configuration health: `bash ~/.dotfiles/scripts/configure-host.sh doctor`

### Tree folding — critical hazard

GNU Stow "tree-folds" when the target directory contains only content from one package. Instead of creating individual file symlinks, Stow replaces the entire target directory with a single symlink pointing into the repo.

If `~/.local` gets tree-folded to `.dotfiles/my-bin/.local`, then per-host runtime data (`~/.local/state/`, `~/.local/share/`) physically enters the dotfiles source tree. This contaminates configuration packages with host-local state such as npm data, Neovim plugins, and uv Python environments.

**Prevention (already in place):**
- `my-bin/.stow-local-ignore` excludes `.local/share` and `.local/state` from Stow.
- `configure-host` / Stow helpers create `~/.local/state/` (and related safety dirs) as real directories before stowing, preventing tree folding.
- Stow apply refuses to continue if `~/.local` (or other safety paths) is already a symlink (tree-folded).
- `scripts/check-fold.sh` diagnoses folding on the current host and can fix it with `--fix`; the user coordinates its use elsewhere.
- `configure-host doctor` and `check` also report fold and host-readiness notes.

### my-bin package boundaries

- `my-bin` contains **only `.local/bin/`** with shared scripts (aiw, note, x11_connections_check, fix-nvidia-suspend.sh).
- `hermes` is not managed by this repo. Each host maintains its own `~/.local/bin/hermes` as a real file pointing to the host-local Hermes venv path.
- `.local/share/` and `.local/state/` must **never** be in the repo.
- Host-specific binaries installed to `~/.local/bin/` (e.g., `uv`, `ente`, `pip install --user`) remain real host-local files alongside managed symlinks.

### stow -R failure mode

`stow -R` (restow) does **delete-then-create**. If the create phase hits a real file conflict (a non-symlink file in the target that matches a repo file), it aborts — leaving the deleted symlinks uncreated. This silently removes access to scripts.

**Before recommending `stow -R my-bin`**, inspect the current host for real files in `~/.local/bin/` matching package paths. Stop and report any conflict; never work around it with `--adopt` or `--force`.

### Package deletion and migration

Do not delete or reorganize package paths without explicit authorization and an approved migration plan. Explain possible symlink and host impact, but do not inspect or coordinate other hosts; cross-host verification and propagation are the user's responsibility.

### zotac-box dual-user setup

zotac-box has two users:
- `alikebrahim` (uid 1001): primary, dotfiles at `/home/alikebrahim/.dotfiles`
- `tima` (uid 1000): secondary, accesses dotfiles via symlink through `shared` group

The `stow-host.sh` / `configure-host.sh` path detects hostname for package lists; zotac-box profile also branches on the running user for SSH overlay and extras. Both users get the same core package list. tima's `~/.local/state/` must be a real dir (the safety check in the Stow helpers handles this).

## General dotfiles workflow

- Prefer minimal, targeted edits over broad rewrites.
- Preserve existing structure, comments, and conventions unless the user asks for cleanup/refactoring.
- Avoid baking machine-specific choices into shared configs unless the user says that package is machine-specific.
- Prefer shared defaults plus machine-local overrides for per-host state, themes, and selections.
- Be careful with Stow packages: package directory names matter because existing symlinks may point into them.
- Do not rename, delete, or reorganize Stow packages without calling out the migration impact first.
- Do not assume live files under `$HOME` and repo files are identical; inspect the intended source of truth.
- When adding new files, use conventional casing and names. For agent guidance, use `AGENTS.md` at the repo root.

### Quickshell project records

- Canonical Quickshell project plans, status, audits, operations notes, and visual-proof records live under `quickshell/docs/`.
- Start with `quickshell/docs/project-status.md` for current operational truth and `quickshell/docs/quickshell-only-awesomewm-migration.md` for the completed migration record and residual acceptance boundaries.
- Treat `quickshell/docs/consolidation-plan.md` and dated audits as historical/chronological evidence where their headers say so; do not overwrite historical findings to make them look current.
- Do not create or maintain Quickshell project records under `.hermes/`; `.hermes/plans/` is not the source of truth for this project.

## Configuration enhancements and improvement projects

Treat desktop, shell, terminal, editor, launcher, bar, theme, and window-manager work primarily as personal system configuration and ricing, not as production application development. Optimize for a visible, usable improvement on the user's actual machine.

### Default enhancement loop

1. Inspect only the affected configuration, its immediate dependencies, and the live boundary needed to understand it.
2. Explain the root cause or intended improvement in plain English.
3. Propose one bounded edit batch with the intended result, exact files, expected live effect, and lightweight validation.
4. Wait for explicit approval, then apply the approved batch without expanding its scope.
5. Run the cheapest appropriate native check.
6. Let the user inspect the real result when visual or interactive judgment matters.
7. Make a small follow-up adjustment if needed, then stop when the requested result works.

One approval may cover a clearly described batch of related edits. It does not authorize unrelated cleanup, new infrastructure, or additional live/deployment actions.

### Scope and effort control

- Work on one coherent enhancement or defect at a time. Use a short `now / next / parked` punch list rather than a software-project phase plan.
- Prefer adapting existing patterns and components over introducing abstractions or infrastructure.
- Do not start broad architecture audits, refactors, test-suite construction, or unrelated cleanup unless explicitly requested.
- Do not create test files, fixtures, harnesses, scripts, or documentation unless they are approved deliverables or clearly necessary for nonvisual logic that is likely to regress.
- External research should answer a specific uncertainty. Stop once the installed API or appropriate pattern is established; do not repeatedly re-verify the same fact.
- Generic software-development, TDD, code-review, and integration-testing workflows do not override this repository's proportional configuration workflow. Skills may provide technical facts without escalating the task's process.

## Live activation and deployment

- Source editing, live activation, and deployment are separate scopes.
- Before editing, determine whether the source is live-linked and whether saving it will automatically reload the application. Disclose any expected automatic effect in the proposed batch.
- By default, do not reload/restart AwesomeWM, Quickshell, services, or sessions; mutate live state through IPC; kill/respawn processes; or change hardware state.
- Read-only live inspection is allowed when it directly answers the current question and cannot alter the session.
- Stow or `configure-host` deployment requires explicit authorization. Operate only on the current host, run the relevant `plan`/`check` first, and do not infer readiness of other hosts.
- The user handles all repository recording and propagation before or after deployment.

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

- Validation must be proportional to the change and should favor the application's native workflow.
- For visual changes such as colors, spacing, typography, icon size, popup shape, and alignment, use normal live rendering and visual inspection. Do not create automated tests by default.
- For shell files, run syntax checks after edits when available:
  - `zsh -n <file>` for zsh files.
  - `bash -n <file>` for bash files.
- For AwesomeWM Lua config, prefer `awesome -k` from the config directory. Let the user trigger a normal reload, then inspect the affected behavior; do not build a virtual WM environment for routine rules or styling.
- For Neovim Lua, use a headless Neovim check when practical.
- For parsers and command-output handling, exercise representative real or fixture output. Add a regression only when the logic is reusable, failure-prone, or has already regressed.
- For tmux config, be mindful that theme/plugin paths may be machine-local; if a direct tmux source check fails because of missing local theme/plugin files, report that clearly rather than overfitting the config.
- Reserve isolated integration tests for genuinely risky startup/process boundaries, recurring defects, or an explicit user request.
- A validation method must remain simpler and safer than the behavior it validates. After two failed attempts with the same diagnostic approach, stop and reassess the assumptions.
- Contradictory environment evidence invalidates a test immediately. Do not expand or debug synthetic test infrastructure merely to make the harness pass when the requested behavior can be checked directly and safely.
- Do not pursue exhaustive certainty. Report residual uncertainty and let the user decide whether deeper testing is worthwhile.
- After edits, summarize exactly what changed and mention any verification performed.

### Definition of done for enhancements

A configuration enhancement is complete when the approved source changes are present, the relevant native check passes, the requested behavior works on the intended system, and no new relevant error is observed. Visual acceptance belongs to the user.

Completion does not require a comprehensive test suite, headless integration environment, automated visual tests, validation of unrelated features, Git/Syncthing operations, or deployment to other hosts.

## Safety notes

- Do not detach, kill, respawn, or otherwise alter live tmux sessions unless explicitly requested.
- Do not remove apparently stale clients/sessions/windows without explicit approval.
- Do not delete stray-looking files without asking first.
- Do not overwrite local machine-specific files unless the user identifies them as the intended target.
- Do not delete or reorganize package paths without an explicitly approved migration scope. Report potential symlink/host impact; the user handles cross-host verification.
