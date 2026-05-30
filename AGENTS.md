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

## General dotfiles workflow

- Prefer minimal, targeted edits over broad rewrites.
- Preserve existing structure, comments, and conventions unless the user asks for cleanup/refactoring.
- This repo is synced across multiple machines. Avoid baking machine-specific choices into shared configs unless the user says that package is machine-specific.
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
