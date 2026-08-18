# Current System Analysis — GNU Stow + `configure-host.sh`

Baseline documentation of the dotfiles system as it exists today, for the
stow → chezmoi migration. Read-only analysis; every claim cites a repo path.
Current host this repo was analyzed from: **servalws** (`hostnamectl hostname`).

---

## 1. Architecture overview

The repo is a **desired-state orchestrator built on GNU Stow**, wrapped in a
single Bash engine (`scripts/configure-host.sh` v3.1.0). One engine manages
four component kinds:

1. **tools** — OS-native packages (dnf/apt) from a declarative registry
2. **dotfiles** — GNU Stow packages symlinked into `$HOME`
3. **ssh-overlay** — a constrained Stow component for per-host `~/.ssh`
4. **modules** — `system:` (root-owned `/etc`) and `user:` (service state)
   imperative scripts with status/plan/apply/verify lifecycles

```
scripts/profiles/*.conf        scripts/lib/*.sh (13 libs)
  common.conf + <host>.conf ──► profile_resolve(host,user,os)
        │                             │
        ▼                             ▼
  PROFILE_* vars ──────────► selection_init_from_profile()
        │                    (catalog + tool sets + modules)
        ▼
  CONFIG_SELECTED_{TOOLS,STOW,MODULES}   (CLI --tool/--stow-package/--module
        │                                 filters and --scope refine it)
        ▼
  workflow_* (scripts/lib/workflow.sh)   ← shared by CLI and gum session UI
        │  status | plan | apply | verify
        ├──► stow.sh / ssh-overlay.sh   (simulate-then-restow, conflict scan)
        ├──► tools.sh                   (dnf/apt install, manual hints)
        └──► module-runner.sh           (scripts/modules/{system,user}/*.sh)
        │
        ▼
  runner.sh (flock + durable run dir + sudo gate + logs)
        │
        ▼
  $HOME  +  /etc (system modules)  +  ~/.local/state/configure-host (state)
```

Host → profile resolution (`scripts/lib/profile.sh:profile_resolve`):
`hostnamectl hostname` (or `--host` override) → `scripts/profiles/<host>.conf`
sourced after `common.conf`; hostname regex-guarded. OS comes from
`/etc/os-release`; profile applies only if OS ∈ `PROFILE_ALLOWED_OS`
(`profile_can_apply`). Unknown hosts can `check`/`plan` common setup but need
`--allow-unknown-host` to mutate (`scripts/lib/workflow.sh`).

Exit codes (`scripts/lib/common.sh`): 0 OK, 1 drift/absent, 2 blocked/invalid,
3 internal. Status words: `CURRENT ABSENT DRIFT BLOCKED CHANGED SKIP INSTALL`.

---

## 2. Profile system (`scripts/profiles/`)

`common.conf` defines the shared core; each `<host>.conf` overlays extras.
Effective package list = COMMON + TMUX_OVERLAY + EXTRA
(`profile_resolve`, lines 79–81).

| Profile | TMUX overlay | SSH overlay | Tool set | UI theme | Extras / modules |
|---|---|---|---|---|---|
| **common.conf** | — | — | — | — | `zsh bash git vim nvim delta my-bin tmux-remote` |
| **netmaster.conf** | `tmux-remote-netmaster` | `netmaster` | `developer` | `orange-gas-plasma` | none |
| **servalws.conf** | `tmux-remote-servalws` | `servalws` | `desktop-full` | `orange-gas-plasma` | stow: `apps 1Password wezterm flameshot awesome quickshell awesome_wm_scripts picom awesomewm-bin`; modules: `system:xorg-libinput, system:1password-unlock-polkit, system:ly-display-manager, system:ly-screen, system:mate-polkit-package, system:battery-charge-thresholds, user:gnome-keyring-units, user:awesome-auth-startup`; `PROFILE_ALLOWED_OS=(fedora)` |
| **minisforoum.conf** | `tmux-remote-minisforoum` | `minisforoum` | `developer` | `orange-gas-plasma` | stow: `apps 1Password wezterm` |
| **zotac-box.conf** | `tmux-remote-zotac-box` | `zotac-box/${PROFILE_USER}_zotac-box` | `minimal` | `orange-gas-plasma` | **user branching**: if user == `tima` → `PROFILE_EXTRA_STOW_PACKAGES=(apps)`; alikebrahim gets no extras |
| **macbook.conf** | `tmux-remote-macbook` | `macbook` | `""` (no native pkg flow) | `orange-gas-plasma` | none |
| **honor.conf** | `tmux-remote-honor` | `honor` | `""` (no Termux flow) | `amber-crt` | none |

Key facts:
- Only **servalws** declares modules and an OS allow-list — all root-owned
  system machinery is desktop-Fedora specific.
- **zotac-box dual-user**: `PROFILE_SSH_OVERLAY="zotac-box/${PROFILE_USER}_zotac-box"`
  (`scripts/profiles/zotac-box.conf`) — a path **containing the username**;
  `ssh_overlay_init` (`scripts/lib/ssh-overlay.sh:20-26`) splits it into
  `--dir=ssh/zotac-box` + package `alikebrahim_zotac-box` / `tima_zotac-box`.
  This is the only profile where the resolved overlay depends on `id -un`,
  not just hostname.
- macbook/honor have empty tool sets: configure-host v3 has no macOS/Termux
  package workflow; only stow + overlay apply there.

---

## 3. Selection pipeline

`scripts/lib/selection.sh`:
- Catalog packages (`stow_catalog_list`) + `ssh-overlay` (if profile overlay
  exists) → `CONFIG_AVAILABLE_STOW`; tool sets → `CONFIG_SELECTED_TOOLS`;
  profile packages → `CONFIG_SELECTED_STOW`; `PROFILE_MODULES` → selected
  modules.
- CLI `--scope all|stow|system|user`, repeatable `--tool/--stow-package/
  --module`, `--no-ssh-overlay` filter the selection
  (`scripts/configure-host.sh:selection_filter_scope`).
- `validate_selection` rejects unknown tools, unregistered stow packages
  (catalog is authoritative — top-level dirs are **never** inferred as
  packages), and modules the profile doesn't declare.

---

## 4. Stow layer (`scripts/lib/stow.sh`)

- Invocation: `stow --dir "$STOW_ROOT" --target "$STOW_HOME" ...` — repo root
  as package dir, `$HOME` as target (line 36-38).
- **Simulate-then-restow**: every apply runs `stow --simulate -v -R PACKAGE`
  first; apply only proceeds per-package if simulation passes
  (`stow_apply_packages`, lines 328-363). `-R` = delete-then-recreate links.
- **Conflict reporting** (`stow_package_conflict_report`): walks every managed
  file, flags non-`-ef` targets: symlink-points-elsewhere, **real file blocks
  Stow (refuse --adopt)**, unexpected type. DRIFT on any conflict.
- **Orphan link cleanup** (`stow_remove_orphaned_links`): before restow, finds
  target symlinks still resolving into the package whose source vanished and
  removes them — but re-verifies each target (still a symlink, still resolves
  into package, source still absent) right before `rm` to avoid races.
- **Tree-fold safety**:
  - `STOW_SAFETY_DIRS` = `~/.local`, `~/.local/state`, `~/.local/share`,
    `~/.tmux` must be real dirs; any of them being a symlink ⇒ BLOCKED
    (`stow_safety_check`). Apply `mkdir -p`s missing ones
    (`stow_ensure_safety_dirs`).
  - `.stow-local-ignore` is parsed (literal segment matching + `^/`/`/`-anchored
    regex forms) and honored by the in-house managed-file enumeration
    (`_stow_load_ignore_patterns` / `_stow_path_is_ignored`) — so status,
    conflict, orphan and fold logic all agree with what Stow will do.
- **Status** (`stow_package_status`): per managed file — linked (`-ef`),
  missing, conflict; plus orphan count ⇒ CURRENT / ABSENT / DRIFT / BLOCKED
  (empty package = BLOCKED).
- **Prune** (`stow_prune_packages`): simulate `-D` then real `-D`; only via
  explicit `prune --stow-package ID` (CLI) with double confirmation; refuses
  profile defaults and ssh-overlay (configure-host.sh `run_prune`).

`scripts/stow-host.sh` is a **compatibility wrapper only** — maps legacy
`--list/--check/--dry-run/--no-ssh/--yes` onto `configure-host.sh --scope
stow`; rejects `--adopt`/`--force`; `--no-tmux`/`--no-xorg-input` are no-ops.

## 5. SSH overlay layer (`scripts/lib/ssh-overlay.sh`)

- A constrained second Stow invocation: `stow -R --dir=ssh/<host> --target=$HOME
  <package>` (e.g. `--dir=ssh/servalws`, package content `.ssh/...`).
- Own status/plan/apply mirroring stow.sh but with `find`-based enumeration
  (no ignore file support). Applies as the `ssh-overlay` pseudo-package in
  selection; `--no-ssh-overlay` and `prune` refuse to touch it.
- Header comment: operational `authorized_keys` and `known_hosts` remain
  "ignored and never inspected here" — they are still shipped in the overlay
  dirs though (see inventory doc).
- zotac-box: overlay path embeds the user (`zotac-box/${PROFILE_USER}_zotac-box`).

## 6. Modules (`scripts/lib/module-runner.sh` + `scripts/modules/`)

Convention: ID `category:name` → `scripts/modules/<category>/<name>.sh` →
function `module_<name>` (dashes→underscores) + optional
`module_<name>_metadata` (label/description/privilege/risk/impact). All share
`module_manage_file` (status = `cmp`; apply = backup + `install -D -m` via
`run_as_root`; verify after install) and manifest recording.

| Module | File | What it does | Priv / risk |
|---|---|---|---|
| `system:battery-charge-thresholds` | `scripts/modules/system/battery-charge-thresholds.sh` | Installs + enables systemd unit `battery-charge-thresholds.service` (source `scripts/system/battery-charge-thresholds/`), `systemctl enable --now`, verifies BAT0 sysfs thresholds read 50/60 | root / high |
| `system:ly-display-manager` | `.../ly-display-manager.sh` | `dnf install -y ly` (records PACKAGE in manifest) + `systemctl enable --now ly@tty2.service` | root / high |
| `system:ly-screen` | `.../ly-screen.sh` | Copies 3 files to `/etc/ly/`: `config.ini` (0644), `startup.sh` (0755), `animations/cosmic-gravity-monitor-16c-240x67.dur` | root / medium |
| `system:mate-polkit-package` | `.../mate-polkit-package.sh` | `dnf install -y mate-polkit` (rpm query state) | root / low |
| `system:xorg-libinput` | `.../xorg-libinput.sh` | Installs `scripts/system/xorg-libinput/40-libinput-natural-scrolling.conf` → `/etc/X11/xorg.conf.d/` (0644) | root / low |
| `user:gnome-keyring-units` | `.../gnome-keyring-units.sh` | `systemctl --user enable --now gnome-keyring-daemon.service gnome-keyring-daemon.socket`; records SERVICE state | user / medium |
| `user:awesome-auth-startup` | `.../awesome-auth-startup.sh` | **Verification-only**: greps `awesome/.config/awesome/rc.lua` for polkit-mate agent + 1Password `--silent` startup; apply refuses until the awesome package is restowed | user / low |

Modules are the only place with **no Stow analog at all**: they install
packages, copy files into `/etc`, and flip systemd state.

## 7. Tools registry (`scripts/lib/tools.sh`)

- Parallel associative arrays `TOOL_DESC/CATEGORY/FEDORA_PKG/UBUNTU_PKG/
  DETECT/MANUAL_HINT`; `tool_register` API; detection methods `command`,
  `command-any` (fd/fdfind), `path`.
- Registered: zsh, tmux, delta, rg, fd, zoxide, fzf, lazygit, yazi, awesome.
  yazi has no Ubuntu package → `--manual-hint "cargo install ..."`.
- Sets: `minimal` = zsh tmux delta; `developer` = + rg fd zoxide fzf lazygit;
  `desktop` = developer + awesome; `desktop-full` = desktop + yazi.
- `tools install` → `run_as_root dnf install -y` / `apt-get update && apt-get
  install -y`; manual-hint tools are reported BLOCKED with a hint, never
  auto-installed. Fedora/Ubuntu only.

## 8. Bootstrap (`scripts/lib/bootstrap.sh`)

Prerequisites: `stow` ≥ 2.3.1, `gum` ≥ 0.17.0, `less`, `column` (util-linux),
`flock` (util-linux). `bootstrap` command installs missing ones via dnf/apt
through the runner (root). This is the "install the installer" step.

## 9. Runner / rollback / doctor / session UI

**Runner** (`scripts/lib/runner.sh`):
- State root `~/.local/state/configure-host` (override via
  `CONFIGURE_HOST_STATE_ROOT`/`XDG_STATE_HOME`); run dir
  `runs/<UTC-run-id>-<label>-<pid>-<rand>/` with `metadata`, `output.log`,
  `backup/`, `rollback.tsv` (all 0600/0700, umask 077).
- Per-user **flock** on `${XDG_RUNTIME_DIR:-/tmp/configure-host-$uid}/
  configure-host.lock` (`scripts/lib/common.sh:acquire_lock`), with ownership
  and symlink checks; second instance ⇒ BLOCKED.
- Root runs pre-auth via `sudo true` before backgrounding the worker; worker
  runs with `set +e`-safe `wait`, metadata written on finish.
- CLI `history` lists runs; interactive UI can page latest log.

**Rollback** (`scripts/lib/rollback.sh`): `rollback RUN_ID` restores **only
FILE entries** recorded in `rollback.tsv` (PRESENT→restore backup with mode/
uid/gid; ABSENT→remove). Paths validated (absolute, no `..`, must stay under
`$SYSTEM_ROOT`). PACKAGE/STOW/SERVICE rows are shown as "REVIEW, retained" —
**package installs, Stow links and service state are never auto-reversed**;
the plan text says so before confirmation. Stow undo is `prune` (double
confirm, explicit IDs only).

**Doctor** (`scripts/lib/doctor.sh`): Syncthing notes (.stfolder marker),
tree-fold safety status, **catalog audit** (catalog vs disk vs profile vs
`-archived` dirs; skips `scripts docs tests ssh revamp omarchy
quickshell_screenshots`), tmux-plugins checkout status, and a new-package
checklist. `doctor` exit code reflects drift.

**Session UI** (`scripts/lib/session-ui.sh` + `ui-gum.sh`): full gum dashboard
(Detect → Select → Review → Apply → Verify). Same workflow functions as CLI —
UI stages selections, writes plan/status to `$SESSION_TMPDIR`, pages with
`less -R`. `ui_auto_theme` reads `~/.tmux/theme.conf` to pick the gum color
theme; profiles can pin `PROFILE_UI_THEME`. Fallback: non-TTY or no gum ⇒
plain-text plan. Themes live in `scripts/ui-themes/*.sh` (orange-gas-plasma,
amber-crt, green-phosphor).

---

## 10. The safety machinery and its cost

Every mechanism below exists to cope with GNU Stow 2.3.1-era limitations
(AGENTS.md "Tree folding — critical hazard"; this host actually runs
**Stow 2.4.1** — see note):

| # | Mechanism | Where | What it guards against |
|---|---|---|---|
| 1 | Tree-fold prevention: `STOW_SAFETY_DIRS` must be real dirs; apply refuses if any is a symlink | `stow.sh:40-77` | Stow folding `~/.local` → single symlink into repo, trapping host runtime data (npm/nvim/uv) in the synced repo |
| 2 | `.stow-local-ignore` per package (my-bin: `.local/share`, `.local/state`; tmux-remote: `.tmux/plugins`, `.tmux/theme.conf`; quickshell: `^/docs`, `^/tests`) + in-house mirror parser | `stow.sh:96-133` | Keeping host-local mutable state out of stow |
| 3 | `stow -R` delete-then-create hazard: simulate-then-restow, failure recovery text, post-failure status+conflict report | `stow.sh:288-363`, AGENTS.md | `-R` aborting mid-way leaves previously-linked files deleted |
| 4 | BLOCKED real-file conflicts; `--adopt`/`--force` refused everywhere (stow.sh, stow-host.sh, docs) | `stow.sh:257-286` | Real files in `$HOME` shadowing package files would otherwise be overwritten/absorbed |
| 5 | Conflict simulation for every selected package at plan/check/apply time | `workflow.sh:131-159` | Catching conflicts before mutation |
| 6 | Orphan-link scan+remove with re-verification | `stow.sh:174-255` | Stow leaving dangling symlinks after source deletion |
| 7 | `prune` = explicit `-D`, double-confirm, never profile defaults | `configure-host.sh:run_prune` | Accidental unstow of whole host |
| 8 | Per-package overlays as *separate packages* (tmux-remote-<HOST>, ssh/<HOST>, zotac per-user) | profiles + catalog | Expressing per-host differences, since one package = one tree |
| 9 | Drift statuses CURRENT/ABSENT/DRIFT/BLOCKED per package, tools, modules | `stow.sh:408-453`, workflow | Knowing what's actually linked vs expected |
| 10 | Rollback for system files only, with manifest + review-only for packages/services/stow | `rollback.sh` | Undoing `/etc` writes without pretending to undo dnf/systemctl/stow |
| 11 | flock + durable run dirs + sudo pre-auth | `runner.sh`, `common.sh:43-91` | Concurrent/incomplete mutations |
| 12 | Fold diagnosis script `scripts/check-fold.sh` (SSHes to the 5 other hosts, FOLDED/PARTIAL/SAFE/MISSING/UNREACHABLE, `--fix` unstows my-bin and restores real dirs from a backup) | `check-fold.sh` | Recovering hosts that *already* folded before the safety dirs existed |
| 13 | `doctor` catalog audit + new-package checklist | `doctor.sh:38-155` | Packages existing on disk but not registered/selected (or vice versa) |

**The cost**: ~13 libraries and 33 scripts (~4,800 lines) exist substantially
to keep Stow from hurting the user. Per-host variance is expressed as N
near-duplicate tiny overlay packages (6 tmux theme overlays, 6 SSH overlay
dirs + 2 per-user). Mutable third-party state (tmux plugins) is excluded from
stow and handled by a separate git-clone script (`scripts/
install-tmux-plugins.sh`, `--ensure`/`--update`), plus a doctor check — a
second desired-state engine for one directory. Sync coordination is a manual
discipline (Syncthing, not git, propagates; `plan` output reminds you).

> **Version note (finding)**: AGENTS.md/.hermes.md and `scripts/lib/
> bootstrap.sh` pin the fleet floor at Stow 2.3.1 (no `--no-folding`). The
> repo-root `.stowrc` contains `--no-folding`, and this host runs **Stow
> 2.4.1** (which supports it). The safety-dir machinery is thus belt-and-
> braces on this host, but a 2.3.1 host that runs stow from the repo root
> would reject the unknown `.stowrc` option. Worth resolving during the
> migration.

---

## 11. Daily workflow and friction

1. `bash ~/.dotfiles/scripts/configure-host.sh` (gum dashboard) or CLI:
   `check` → `plan` (review) → `apply` (confirm; second confirm for high-risk
   modules) → built-in `verify`.
2. First run on a host: `bootstrap`, then apply. New packages: doctor →
   check/plan/apply → wait for Syncthing → apply elsewhere.
3. `tools install` for missing tools; `update tmux-plugins` to fast-forward
   plugin checkouts (never part of apply).
4. Repairs: `doctor`, `status`, `prune`, `rollback RUN_ID`.

Friction that remains:
- **Stow status/plan is per-package-link accounting**; per-file diffing isn't
  available (only conflict paths). Real drift diagnosis requires reading
  `status` output carefully.
- **Two desired-state subsystems** (stow packages vs tmux plugin clones).
- **Manual Syncthing discipline** — no automation; the repo is not git-shipped
  to hosts (`.stignore` keeps state out; git only for history).
- **Per-host overlay proliferation** (6 tmux + 6 ssh + 2 per-user zotac) —
  one theme change touches the base plus each overlay.
- **Legacy surface**: empty `bin/` package still catalogued; `tmux/` package
  removed (AGENTS.md: "reference only"); root `.zshrc` stray file; `wezterm/
  .config/wezterm/` contains a stray file literally named `\`; duplicated
  asset trees (`scripts/polkit/` vs `scripts/system/polkit/`,
  `scripts/xorg/` vs `scripts/system/xorg-libinput/`).

---

## 12. Parts with no obvious Stow analog (chezmoi design input)

- **Root-owned system modules** (`/etc/ly/*`, polkit rules, Xorg conf,
  systemd units, dnf package installs) — Stow never touched these; chezmoi
  would need `run_` scripts / `sudo` handling / age-adjacent policy.
- **Tools registry + bootstrap** — package-manager installs are outside
  dotfile managers; chezmoi `run_` scripts could subsume, but detection
  logic (`command-any`, manual hints) is custom.
- **Rollback/run ledger** — configure-host has durable runs, manifests,
  system-file backups; chezmoi's `chezmoi apply` has no rollback of
  overwritten files (it uses a script/state model).
- **Tree-fold hazard** — Stow-specific (folded dirs, `.stowrc --no-folding`,
  `check-fold.sh`). chezmoi symlinks are per-file and never fold, so this
  whole machinery class disappears.
- **Per-host/per-user overlays** — chezmoi's data-driven templates +
  `onhost`/`onuser` conditions replace the package-per-overlay pattern.
- **ssh-overlay as pseudo-package** — chezmoi has native SSH config handling
  and per-host data files.
- **Drift statuses + doctor audit** — chezmoi has `chezmoi status`/`diff`
  with real per-file diffs (stronger), but catalog-vs-disk and
  profile-vs-catalog audits are repo-specific and would be lost or need
  re-implementation.
- **gum session UI** — the interactive dashboard is custom; chezmoi is
  CLI-first (no dashboard), so the UX layer needs a separate decision.
