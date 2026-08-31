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
   - Approval to edit files does not authorize process restarts, service reloads, live IPC mutations, chezmoi apply, hardware mutations, or changes on other hosts.
   - If an approved source edit is expected to trigger an unavoidable automatic live reload, disclose that effect before editing.
   - Obtain separate explicit authorization for any additional live activation or deployment step.

## Repository architecture

This repo contains source-of-truth files for personal system configuration, managed by chezmoi. The chezmoi source state lives in `home/` (scoped via `.chezmoiroot`); chezmoi copies these files into the live home directory (or symlinks them for the `symlink_` families). Identify the intended source and expected live effect before editing.

- Never create absolute symlinks in the repo; they are not portable across hosts. Use relative symlinks only.
- The user owns all repository history and cross-host propagation. Agent work is limited to authorized content changes and their local, task-relevant validation.

### Chezmoi dotfile management

- Source of truth: `~/.dotfiles/home/` (chezmoi source state via `.chezmoiroot`). Live files are **copies, one-way** (source → target): editing a live file (e.g. `~/.zshrc`) does NOT update the repo.
- **Authoring:** edit `~/.dotfiles/home/...` (e.g. `home/dot_zshrc`) — the source IS the file to edit — then `chezmoi apply` propagates to this host; Syncthing carries it to other hosts (`chezmoi apply` there).
- **Editing from `~`:** `chezmoi edit <target>` (opens the source file), `chezmoi edit --apply <target>` (applies on save), `chezmoi edit --watch <target>` (applies on every save).
- **Live-edit reflex (the R1 footgun):** if a live file was edited directly, adopt it back with `chx <target>` (`chezmoi add` + `chezmoi edit`; alias defined in the zshrc) or `chezmoi re-add` for everything at once. Never assume a live edit reached the repo.
- **Deployment:** `chezmoi apply` is a live deployment step on the current host — requires explicit user authorization. Prefer `chezmoi diff` review first; `chezmoi verify` is read-only; `chezmoi status` shows source/target drift.
- **Forbidden:** `chezmoi update` (runs `git pull`; distribution is Syncthing and git is user-owned). Never call chezmoi from inside chezmoi scripts.
- **Per-host variance:** templates (`*.tmpl`) and per-machine `[data]` in `~/.config/chezmoi/chezmoi.toml`; never hardcode host paths in shared plain files.
- **`symlink_` families** (wezterm, awesome, quickshell, awesome_wm_scripts, flameshot, and `dot_local/bin` where applicable) are installed as symlinks: editing the repo file is already live on the host.

### my-bin / dot_local/bin boundaries

- Managed scripts live in `home/dot_local/bin/` as `executable_*` entries (aiw, note, x11_connections_check, fix-nvidia-suspend.sh, ...).
- `hermes` is not managed by this repo. Each host maintains its own `~/.local/bin/hermes` as a real file pointing to the host-local Hermes venv path.
- `.local/share/` and `.local/state/` must **never** be in the repo.
- Host-specific binaries installed to `~/.local/bin/` (e.g., `uv`, `ente`, `pip install --user`) remain real host-local files alongside managed entries.

### Source-state deletion and migration

Do not delete or reorganize chezmoi source entries (rename/remove source files, flip `symlink_`/`create_`/`encrypted_` attributes) without explicit authorization and an approved migration plan. Explain the target-path and live-host impact, but do not inspect or coordinate other hosts; cross-host verification and propagation are the user's responsibility.

### zotac-box dual-user setup

zotac-box has two users:
- `alikebrahim` (uid 1001): primary, dotfiles at `/home/alikebrahim/.dotfiles`
- `tima` (uid 1000): secondary, accesses dotfiles via symlink through `shared` group

Both users run chezmoi against the same source state; chezmoi `apply` only *reads* the source. Each user has their own `~/.config/chezmoi/chezmoi.toml` (own `[data]`), `chezmoistate.boltdb`, and age identity. Per-user selection is handled by `.chezmoi.username` conditionals in templates and `.chezmoiignore`.

## General dotfiles workflow

- Prefer minimal, targeted edits over broad rewrites.
- Preserve existing structure, comments, and conventions unless the user asks for cleanup/refactoring.
- Avoid baking machine-specific choices into shared configs unless the user says that package is machine-specific.
- Prefer shared defaults plus machine-local overrides for per-host state, themes, and selections.
- Be careful with chezmoi source file names: the `dot_`/`private_`/`executable_`/`symlink_`/`create_` prefixes and `.tmpl` suffix encode the target path and behavior — renaming affects the live target.
- Do not rename, delete, or reorganize source-state entries without calling out the target-path and live-host impact first.
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
- `chezmoi apply` requires explicit authorization. Operate only on the current host, review with `chezmoi diff` first, and do not infer readiness of other hosts.
- The user handles all repository recording and propagation before or after deployment.

## User preferences learned for this repo

- The user generally uses WezTerm multiplexing locally, not local tmux. Treat the old `tmux/` directory as reference unless the user explicitly revives it.
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
- Do not delete or reorganize chezmoi source entries or repo directories without an explicitly approved migration scope. Report potential target-path/host impact; the user handles cross-host verification.
