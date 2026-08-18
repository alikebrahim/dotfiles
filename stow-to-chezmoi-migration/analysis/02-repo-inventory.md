# Repository Inventory — `~/.dotfiles`

Full inventory of the current repo, package by package. Every entry cites its
repo path. This is the baseline for mapping each package to a chezmoi
equivalent. Secrets (key material in `ssh/` overlays) are intentionally not
quoted — only file names and structure.

Scale (measured): **573 tracked-on-disk files** (excluding `omarchy/.git` and
nested git dirs); `scripts/` = 33 `.sh`/`.conf` files ≈ 4,841 lines;
`tests/` = 30 files ≈ 1,593 lines.

---

## 1. Repo top level

| Entry | Kind | Role |
|---|---|---|
| `AGENTS.md` / `.hermes.md` | metadata | Repo-level agent rules; describe Stow model, fold hazard, safety rules (see 01-current-system.md) |
| `docs/` | metadata | `docs/configure-host.md` — the human-facing operator manual (251 lines) |
| `scripts/` | engine | All orchestrator code, profiles, modules, assets (section 4) |
| `tests/` | tests | `tests/deploy/` — 27 test scripts + `run-all.sh` + libs (section 5) |
| `ssh/` | overlay store | Per-host/per-user SSH overlay packages (section 3) |
| `stow-to-chezmoi-migration/` | docs | This migration project (README + analysis/) |
| `<package>/` × 30 | stow packages | Section 2 (30 catalogued; 23 have content) |
| `*-archived/` × 5 | retired packages | `awesome-pillbar-archived`, `awesome_wm_scripts-archived`, `dunst-archived`, `polybar-archived`, `rofi-archived` — each `.config/...` + README; **excluded from catalog** (`doctor.sh` flags any `-archived` in catalog/profile as DRIFT) |
| `omarchy/` | vendored source | Embedded git checkout (`.git/` present) of the upstream omarchy Quickshell shell; not a stow package, skipped by doctor |
| `.hermes/` | metadata | `.hermes/plans/2026-07-13_153258-configure-host-redesign-baseline.md` (238 lines) |
| `.stfolder` / `.stignore` | sync | Syncthing markers; `.stignore` excludes `.git`, `my-bin/.local/state`, `my-bin/.local/share`, `my-bin/.local/bin/hermes`, `/themes`, `.hermes-tmp*`, `*.bak-pre-revamp-*` |
| `.stowrc` | stow config | Contains `--no-folding` (only valid on Stow ≥ 2.4; see version note in 01) |
| `.gitignore` | metadata | `CLAUDE.md`, `nvim/.../lazy-lock.json`, `.stfolder`, `/.ssh/`, `ssh/**/.ssh/known_hosts`, `*.sync-conflict-*`, **`1Password/` (whole package gitignored)**, `__pycache__/` |
| `.ssh/` | repo-root dir | Relative symlinks into `ssh/servalws/.ssh/` (`authorized_keys`, `config`, `known_hosts`); gitignored |
| `.zshrc` | stray | Root-level legacy file (8.4 KB, direnv/p10k content) — **not** part of the `zsh` package (which ships its own `.zshrc`); appears unmanaged |
| `SSH-KEY-MIGRATION-DIAGNOSIS.md` | doc | Aug 2026 diagnostic: SSH key moved off 1Password; SSH auth fixed, git signing pending. Existence noted; contents not quoted |
| `bin/` | empty package | Registered as "Legacy commands" but **empty on disk** |

## 2. Stow packages (catalog = `scripts/lib/stow-catalog.sh`)

Top-level entries listed; host column = which profiles select it (C=common,
S=servalws, M=minisforoum, Z=zotac-box, N=netmaster, B=macbook, H=honor;
"—" = catalogued but selected by no profile).

| Package | Category | Top-level contents | Selected by | Notes |
|---|---|---|---|---|
| `zsh` | shell | `.zshrc`, `.zprofile`, `.p10k.zsh`, `.zsh/completions/_note` | C → all hosts | Shared interactive shell config |
| `bash` | shell | `.bashrc`, `.bash_profile` | C → all | Login/interactive bash |
| `git` | development | `.gitconfig` | C → all | Aliases/defaults |
| `vim` | editor | `.vimrc` | C → all | Plugin-free by design (AGENTS.md) |
| `nvim` | editor | `.config/nvim/` (init.lua, lua/config/*, lua/plugins/* incl. copilot/kanagawa/rust, lazyvim.json, stylua.toml, LICENSE, README.md) | C → all | LazyVim-based; `lazy-lock.json` gitignored |
| `delta` | development | `.config/themes.gitconfig` | C → all | Git diff viewer theme |
| `my-bin` | utilities | `.local/bin/` (aiw, note, llm, mmpv, netgit, scratch, svid, frame, hermes-profile, split-marker.lua, fix-nvidia-suspend.sh, x11_connections_check) + `.stow-local-ignore` (excludes `.local/share`, `.local/state`) | C → all | Shared scripts; **boundary rule**: only `.local/bin`; `hermes` binary is NOT repo-managed (per-host real file, also `.stignore`d) |
| `bin` | utilities | *(empty)* | — | Legacy shell of a package; catalogued, no content |
| `tmux-remote` | terminal | `.tmux.conf`, `.tmux/scripts/` (osc52-copy, status), `.tmux/themes/` (13 `.conf` themes), `.tmux/plugins/` (**empty placeholder dirs**: tpm, tmux-sensible, tmux-resurrect, tmux-continuum, tmux-fzf), `.stow-local-ignore` (excludes `.tmux/plugins`, `.tmux/theme.conf`) | C → all | Base remote-tmux; per-host theme comes from overlay; plugins cloned per-host by `scripts/install-tmux-plugins.sh` |
| `tmux-remote-netmaster` | terminal | `.tmux/theme.conf` | N | Theme overlay (orange-gas-plasma family) |
| `tmux-remote-servalws` | terminal | `.tmux/theme.conf` | S | Theme overlay |
| `tmux-remote-minisforoum` | terminal | `.tmux/theme.conf` | M | Theme overlay |
| `tmux-remote-zotac-box` | terminal | `.tmux/theme.conf` | Z | Theme overlay |
| `tmux-remote-macbook` | terminal | `.tmux/theme.conf` | B | Theme overlay |
| `tmux-remote-honor` | terminal | `.tmux/theme.conf` | H | Theme overlay (amber-crt) |
| `apps` | desktop | `.local/share/applications/`, `.local/share/icons/` | S, M, Z(tima only) | Shared desktop entries/icons |
| `1Password` | desktop | `.config/1Password/ssh/`, `.config/git/1password-signing.gitconfig` | S, M | **Whole dir gitignored** (still Syncthing-synced); SSH agent + git signing config; largely superseded by the key migration (see SSH-KEY-MIGRATION-DIAGNOSIS.md) |
| `wezterm` | terminal | `.config/wezterm/wezterm.lua`, `.config/wezterm/modules/` | S, M | **Stray artifact**: a file literally named `\` sits in `.config/wezterm/` (1.8 KB ASCII) |
| `alacritty` | terminal | `.config/alacritty/alacritty.yml` | — | Registered, unselected |
| `atuin` | shell | `.config/atuin/config.toml`, `atuin-receipt.json` | — | Registered, unselected (receipt file looks like install metadata) |
| `awesome` | desktop | `.config/awesome/` (rc.lua, theme.lua, dynamism/keys/rules/signals.lua, lib/, theme/, vendor/) | S | AwesomeWM; referenced by `user:awesome-auth-startup` module |
| `quickshell` | desktop | `.config/quickshell/` (shell.qml, ui/, modules/, services/, scripts/, style/, awesome-integration/) + `docs/` (project-status, migration, audits…), `tests/`, README.md; `.stow-local-ignore` excludes `^/docs`, `^/tests` | S | Omarchy-derived X11 shell; docs/tests live in-repo but are not stowed |
| `awesome_wm_scripts` | desktop | `.config/scripts/` (wm-health, wm-stabilize, x11-display-profile, x11-monitor-setup, x11-session-env, machine-synoptic-lock, screenshot-flameshot/quick, awesome-session-wrapper, awesome-dump-state) | S | Helper scripts for AwesomeWM |
| `awesomewm-bin` | desktop | `.local/bin/theme-apply`, `.local/bin/theme-select` | S | Theme switching commands (consume `scripts/ui-themes/*.sh` + tmux themes) |
| `picom` | desktop | `.config/picom/picom.conf` | S | X11 compositor |
| `flameshot` | desktop | `.config/flameshot/flameshot.ini` | S | Screenshot tool |
| `posting` | development | `.config/posting/config.yaml` | — | Registered, unselected |
| `postman` | development | `.local/share/applications/`, `.local/share/icons/` | — | Registered, unselected |
| `alikebrahim_zotac-box` | host | `.ssh/` **(empty dir)** | — | Per-user zotac package shell; real content lives in `ssh/zotac-box/alikebrahim_zotac-box/` |
| `tima_zotac-box` | host | `.ssh/` **(empty dir)** | — | Same for tima; real content in `ssh/zotac-box/tima_zotac-box/` |

Registered-but-unselected packages: `bin`, `alacritty`, `atuin`, `posting`,
`postman`, `alikebrahim_zotac-box`, `tima_zotac-box` — appear in the
interactive "select dotfile packages" list but no profile selects them.

### 2.1 Profile × package selection matrix

Resolved effective selection (common + tmux overlay + extras; from
`scripts/profiles/*.conf`, resolution logic in `scripts/lib/profile.sh:79-81`):

| Package | netmaster | servalws | minisforoum | zotac-box | macbook | honor |
|---|---|---|---|---|---|---|
| zsh bash git vim nvim delta my-bin | ✔ | ✔ | ✔ | ✔ | ✔ | ✔ |
| tmux-remote | ✔ | ✔ | ✔ | ✔ | ✔ | ✔ |
| tmux-remote-<HOST> overlay | netmaster | servalws | minisforoum | zotac-box | macbook | honor |
| ssh-overlay | netmaster | servalws | minisforoum | zotac-box/<user> | macbook | honor |
| apps | — | ✔ | ✔ | tima only | — | — |
| 1Password | — | ✔ | ✔ | — | — | — |
| wezterm | — | ✔ | ✔ | — | — | — |
| flameshot, awesome, quickshell, awesome_wm_scripts, picom, awesomewm-bin | — | ✔ | — | — | — | — |
| modules (8) | — | ✔ (all 8) | — | — | — | — |

Every host therefore stows: 7 common packages + 1 tmux overlay + ssh-overlay
= 9 components minimum; servalws is the only profile with the full desktop
stack (22 stow + 10 tools + 8 modules).

### 2.2 Per-package scale (file counts, `find -type f`)

| Size band | Packages |
|---|---|
| 100+ | quickshell 142 (incl. non-stowed docs/tests: 12 docs files) |
| 80 | awesome 81 |
| 20–30 | apps 24 |
| 10–20 | nvim 16, tmux-remote 16, my-bin 13, awesome_wm_scripts 10 |
| 2–6 | zsh 4, bash 2, wezterm 6, 1Password 2, atuin 2, postman 2, awesomewm-bin 2 |
| 1 | git, vim, delta, each tmux-remote-<HOST>, alacritty, picom, flameshot, posting |
| 0 | bin, alikebrahim_zotac-box, tima_zotac-box (shells only) |

## 3. SSH overlays (`ssh/` tree — names only, no contents quoted)

| Overlay dir | Files (names) | Used by |
|---|---|---|
| `ssh/netmaster/.ssh/` | `config`, `authorized_keys`, `known_hosts` | netmaster profile |
| `ssh/servalws/.ssh/` | `config`, `authorized_keys`, `known_hosts`, `allowed_signers` | servalws profile (also symlinked from repo-root `.ssh/`) |
| `ssh/minisforoum/.ssh/` | `config`, `authorized_keys`, `known_hosts` | minisforoum |
| `ssh/macbook/.ssh/` | `config`, `authorized_keys`, `known_hosts` | macbook |
| `ssh/honor/.ssh/` | `config`, `authorized_keys` | honor (no known_hosts) |
| `ssh/zotac-box/alikebrahim_zotac-box/.ssh/` | `config`, `authorized_keys`, `known_hosts` | zotac-box + user alikebrahim |
| `ssh/zotac-box/tima_zotac-box/.ssh/` | `config` | zotac-box + user tima (no authorized_keys/known_hosts) |

Applied via `stow -R --dir=ssh/<host> --target=$HOME <package>` as the
`ssh-overlay` pseudo-package (`scripts/lib/ssh-overlay.sh`). Gitignore keeps
`known_hosts` out of git; Syncthing still carries them.

## 4. `scripts/` tree

| Path | Purpose |
|---|---|
| `configure-host.sh` (497 lines) | **Sole deployment engine** v3.1.0; commands: list, check, status, plan, diff, doctor, history, apply, bootstrap, rollback, prune, tools list/check/install, update tmux-plugins; `--scope`, `--host`, `--tool/--stow-package/--module`, `--no-ssh-overlay`, `--theme`, `--yes`, `--no-ui`, `--non-interactive`, `--format tsv`, `--verbose/--quiet` |
| `stow-host.sh` (66) | Legacy compatibility wrapper → `configure-host --scope stow`; rejects `--adopt/--force` |
| `check-fold.sh` (282) | Cross-host (netmaster, servalws, minisforoum, zotac-box, macbook — note: **honor not listed**) `~/.local` tree-fold check via SSH; `--fix` unstows my-bin and restores real dirs |
| `check-wm-servalws.sh` | servalws-only WM diagnostics (awesome/quickshell/picom processes, links, IPC, D-Bus, bridge) |
| `install-tmux-plugins.sh` (68) | Clones/fast-forwards 5 plugins (tpm, tmux-sensible, tmux-resurrect, tmux-continuum, tmux-fzf) into `~/.tmux/plugins/`; `--ensure` (idempotent) / `--update` (git pull --ff-only) |
| `lib/` (13 files) | `common.sh` (exit codes, status words, `run_as_root`, flock), `log.sh`, `profile.sh`, `selection.sh`, `stow-catalog.sh` (the 31-entry registry), `stow.sh` (safe stow helpers), `ssh-overlay.sh`, `tools.sh` (registry + sets), `bootstrap.sh`, `module-runner.sh`, `workflow.sh` (shared desired-state workflow), `runner.sh` (durable runs), `rollback.sh`, `doctor.sh`, `session-ui.sh` (gum dashboard), `ui-gum.sh` (themes, pagers, spinners) — 16 files total incl. log/ui-gum |
| `profiles/` (7 files) | `common.conf` + `netmaster|servalws|minisforoum|zotac-box|macbook|honor.conf` (see 01-current-system.md §2) |
| `modules/system/` (6) | battery-charge-thresholds, ly-display-manager, ly-screen, mate-polkit-package, xorg-libinput, 1password-unlock-polkit |
| `modules/user/` (2) | awesome-auth-startup, gnome-keyring-units |
| `system/` assets | `battery-charge-thresholds/battery-charge-thresholds.service`; `ly/` (config.ini, startup.sh, animations/cosmic-gravity-monitor-16c-240x67.dur); `polkit/49-1password-unlock.rules`; `xorg-libinput/40-libinput-natural-scrolling.conf` |
| `polkit/49-1password-unlock.rules` | **Duplicate** of `system/polkit/` copy (legacy path) |
| `xorg/40-libinput-natural-scrolling.conf` | **Duplicate** of `system/xorg-libinput/` copy (legacy path) |
| `ui-themes/` (3) | `orange-gas-plasma.sh`, `amber-crt.sh`, `green-phosphor.sh` — gum UI color themes, consumed by `ui-gum.sh` + `awesomewm-bin`'s theme-apply |
| `vimium/` (4) | `vomnibar_catppuccin-frappe(-v2).css`, `vomnibar_kanagawa-wave(-v2).css` — browser extension styling assets |

## 5. Tests (`tests/deploy/`)

`run-all.sh` + `testlib.sh` + 25 test scripts covering: CLI plan mode, profile
resolution, dynamic discovery, selection, stow status/safety, ssh overlay,
stow-host wrapper, fresh module apply, module metadata/idempotency, runner
sync/async, rollback, prune/doctor CLI, tmux plugins, tools, bootstrap,
session modules/navigation, ui-gum/ui-primitives, workflow plan/noop,
workflow, battery module. ~1,593 lines.

## 6. Metadata and boundary notes

- **`my-bin` boundary**: contains only `.local/bin`; `.local/share` and
  `.local/state` are excluded by both `.stow-local-ignore` and `.stignore`,
  and `~/.local/state` must exist as a real directory for apply (safety
  check in `stow.sh`).
- **`hermes`**: not repo-managed — per-host real file `~/.local/bin/hermes`
  pointing at the host's Hermes venv (AGENTS.md), and excluded from sync by
  `.stignore`.
- **Folding history**: `awesome-pillbar-archived`/`dunst-archived`/
  `polybar-archived`/`rofi-archived`/`awesome_wm_scripts-archived` are
  retired packages preserved via the `<name>-archived` convention; doctor
  treats them as archives, not packages.
- **Old `tmux/` package**: removed; AGENTS.md treats it as reference-only
  (user multiplexes with WezTerm locally; tmux only on remotes).
- **tmux theme library**: `tmux-remote/.tmux/themes/` holds 12 theme `.conf`
  files — amber-crt, blue-matrix, catppuccine, cga-cyan-magenta,
  commodore-64, green-phosphor, ibm-5153-cga, kanagawa-wave, mac-classic,
  nord, orange-gas-plasma, retro-pi; the base package stows them all and only
  the per-host overlay's `.tmux/theme.conf` selects one per host.
- **Honor omission**: `check-fold.sh` checks 5 hosts and does not include
  `honor`, though a profile exists for it.
- **Git vs sync**: `.gitignore` excludes the whole `1Password/` package and
  `ssh/**/.ssh/known_hosts` from git; Syncthing is the distribution channel
  (`.stfolder`), and agents are forbidden from touching git or Syncthing.

### 6.1 Consolidated legacy / duplicate / stray surface

| Artifact | Path | Status |
|---|---|---|
| Empty legacy package | `bin/` | Catalogued "Legacy commands", zero files |
| Root-level stray zshrc | `.zshrc` (repo root) | Not part of any package; unmanaged |
| Stray backslash-named file | `wezterm/.config/wezterm/\` | 1.8 KB ASCII text in the stowed package tree — would be symlinked to `~/.config/wezterm/\` on apply |
| Duplicate polkit rule | `scripts/polkit/49-1password-unlock.rules` vs `scripts/system/polkit/…` | Module uses the `system/` copy |
| Duplicate Xorg conf | `scripts/xorg/40-libinput-natural-scrolling.conf` vs `scripts/system/xorg-libinput/…` | Module uses the `system/` copy |
| Empty per-user package shells | `alikebrahim_zotac-box/.ssh/`, `tima_zotac-box/.ssh/` | Real overlay content lives under `ssh/zotac-box/` |
| Gitignored live package | `1Password/` | Untracked in git, still Syncthing-synced |
| Archived packages | `awesome-pillbar-archived`, `awesome_wm_scripts-archived`, `dunst-archived`, `polybar-archived`, `rofi-archived` | Doctor enforces the `-archived` convention (never catalogued/selected) |
| Version skew | `.stowrc --no-folding` | Requires Stow ≥ 2.4.0; docs/bootstrap still say 2.3.1 floor; this host runs 2.4.1 |
| Vendor checkout | `omarchy/` | Nested `.git/`; doctor skip-list member |
