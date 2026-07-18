# Host configuration v3

`scripts/configure-host.sh` is the sole host-configuration engine. It combines
native tool packages, GNU Stow dotfiles, the profile SSH overlay, user modules,
and root-owned system modules into one desired-state selection.

The workflow is always:

```text
Detect → Select → Review → Apply → Verify → Report
```

Before deploying on another host, wait for Syncthing to finish. Use `check` and
`plan` after sync; do not substitute a Git pull for repository synchronization.

## Quick start

```bash
# Persistent interactive dashboard.
bash ~/.dotfiles/scripts/configure-host.sh

# Read-only preflight and concise plan.
bash ~/.dotfiles/scripts/configure-host.sh check
bash ~/.dotfiles/scripts/configure-host.sh plan

# Apply only after reviewing the plan.
bash ~/.dotfiles/scripts/configure-host.sh apply
```

A non-TTY invocation without a command prints the plan instead of opening the
UI. Read-only commands never change home files, `/etc`, packages, services, or
plugin checkouts.

## Interactive dashboard

The main window is organized by user goals rather than implementation details:

- **Set up this machine** — reset to the profile recommendation, bootstrap
  missing configurator requirements, review, apply, and verify.
- **Customize setup** — stage tools, dotfile packages, and system/user
  components independently. Nothing changes before **Review and apply**.
- **Inspect and repair** — view complete state, preview recommended repairs,
  repair drift, or verify the current staged selection.
- **Updates** — inspect profile tools or explicitly update tmux plugins.
- **Advanced and logs** — inspect profile resolution, durable history, latest
  log, technical plan, or system-file rollback.

Navigation contract:

```text
Menus:       arrows move, Enter opens, Esc returns
Main menu:   Esc quits
Nested menu: Esc or the visible Back row returns to the parent
Multi-select: Space toggles, Enter saves, Esc cancels
Pager:       j/k or arrows scroll, PgUp/PgDn page, / searches,
             g/G jump to the ends, q returns
```

Gum 0.17 does not bind `q` in `gum choose`, so menus provide Esc and an explicit
Back row. Long output uses `less -R`, where the documented q/j/k/man-style keys
are native. `NO_COLOR=1` disables color without disabling the interactive UI.

## Plan and status output

The default plan shows only proposed changes:

```text
CONFIGURE-HOST PLAN
Profile: servalws  Host: servalws  OS: fedora 44
Selected: 10 tools | 20 dotfiles | 7 system/user components
Current: 34 | Changes: 3 | Blocked: 0
Requires root: yes

PROPOSED CHANGES
...
```

GNU Stow conflict simulations still run for every selected dotfile package and
the SSH overlay, but raw LINK/UNLINK chatter is hidden. Use `--verbose` or
`diff` for technical Stow output, module IDs, file targets, and diffs.

```bash
bash scripts/configure-host.sh status --format tsv
bash scripts/configure-host.sh plan --quiet
bash scripts/configure-host.sh plan --verbose
bash scripts/configure-host.sh diff --scope system
```

## Commands

| Command | Purpose |
|---|---|
| no command | Interactive dashboard in a TTY; plan otherwise |
| `list` | List known profiles |
| `check` | Prerequisites, fold/Syncthing notes, Stow safety, conflict simulation, selected state, tmux plugin status |
| `status` | Structured status for all selected component types |
| `plan` | Concise, non-mutating change plan (includes Stow conflict paths when present) |
| `diff` | Technical Stow and module details |
| `doctor` | Catalog vs disk vs profile audit, fold safety, Syncthing notes, new-package checklist |
| `apply` | Guarded apply followed by verification (extra confirm for high-risk modules) |
| `bootstrap` | Install stow, gum, less, and required util-linux commands |
| `tools list` | Complete tool catalog with active-OS package names |
| `tools check` | Selected/profile tool status |
| `tools install` | Install selected missing tools |
| `update tmux-plugins` | Explicit plugin checkout update (not part of apply) |
| `prune` | Explicit unstow; requires `--stow-package` (double confirm) |
| `history` | Durable run history |
| `rollback RUN_ID` | Restore system files backed up by a run |

## Selection and automation

```bash
# Component scopes.
bash scripts/configure-host.sh plan --scope stow
bash scripts/configure-host.sh plan --scope system
bash scripts/configure-host.sh plan --scope user

# Explicit selections; each option is repeatable.
bash scripts/configure-host.sh plan \
  --tool rg --tool fd \
  --stow-package zsh --stow-package nvim \
  --module system:xorg-libinput

# Exclude only the host SSH overlay.
bash scripts/configure-host.sh plan --scope stow --no-ssh-overlay

# Deterministic automation requires explicit confirmation.
bash scripts/configure-host.sh apply --non-interactive --yes

# Repo health before adding packages.
bash scripts/configure-host.sh doctor

# Explicit unstow (never uses profile defaults alone).
bash scripts/configure-host.sh prune --stow-package old-pkg --yes
```

Unknown hosts may inspect common packages but cannot mutate anything unless
`--allow-unknown-host` is supplied after plan review. Profile modules can only
be selected when the profile declares them. Stow choices come from
`scripts/lib/stow-catalog.sh`; arbitrary repository directories are never
inferred as packages.

### Adding a new Stow package

1. Create the package tree (relative symlinks only).
2. Register it in `scripts/lib/stow-catalog.sh`.
3. Add it to `scripts/profiles/common.conf` and/or host `PROFILE_EXTRA_STOW_PACKAGES`.
4. Add `.stow-local-ignore` for host-local paths when needed.
5. Run `doctor`, then `check`/`plan`, then `apply`.
6. Wait for Syncthing to finish before applying on other hosts.

## Components

### Tools

The tool registry includes description, category, Fedora/Ubuntu package names,
detection rules, and manual-install guidance. Ubuntu `fd-find` is detected
through either `fd` or `fdfind`. Tables display the package for the active OS,
not a hard-coded Fedora column.

Named sets:

- `minimal`: zsh, tmux, delta
- `developer`: minimal plus rg, fd, zoxide, fzf, lazygit
- `desktop`: developer plus AwesomeWM
- `desktop-full`: desktop plus Yazi

### Dotfiles and SSH

Regular dotfiles use an explicit catalog and explicit Stow root/target. Status
enumerates every managed file (honoring `.stow-local-ignore`) and reports linked,
missing, and conflicting counts. Plans list concrete conflict paths when real
files block restow. The profile SSH overlay is a separate constrained Stow
component with its own `--dir` and `--target`; operational `authorized_keys` and
`known_hosts` remain ignored.

### Modules

Each module declares a plain-English label, description, privilege level, risk,
and runtime impact. Current modules are skipped during apply. Only ABSENT or
DRIFT components mutate state; BLOCKED components prevent apply. Modules with
`risk=high` require a second confirmation before apply.

## Mutation safety

Every mutating path—CLI and UI—uses the same guarded workflow and runner:

1. Validate host/profile and selection.
2. Run Stow conflict simulations.
3. Show the plan and request confirmation (second confirm for high-risk modules).
4. Acquire a per-user `flock`.
5. Acquire sudo authorization before background execution when required.
6. Capture stdout/stderr in a durable private log.
7. Release the lock on success, failure, or cancellation.
8. Verify the complete selected state.
9. Report the exit code and log path.

UI review uses the same Stow/module plan validation as CLI `plan`. Stow apply is
simulate-then-restow; failures print recovery guidance (no `--adopt`).

Current components invoke no mutation. Package installs, plugin updates, and
service changes are never hidden inside read-only commands.

## Logs and rollback

Runs are stored under:

```text
${XDG_STATE_HOME:-$HOME/.local/state}/configure-host/runs/
```

Each run has private metadata, `output.log`, `rollback.tsv`, and a backup tree.
Use:

```bash
bash scripts/configure-host.sh history
bash scripts/configure-host.sh rollback RUN_ID
```

Rollback restores only system files recorded before replacement. It does not
automatically uninstall packages, reverse Stow links, or change service state.
The rollback plan states this limitation before confirmation. To remove Stow
links intentionally, use `prune` with explicit package IDs.

## Legacy `stow-host.sh`

`scripts/stow-host.sh` is now a narrow compatibility wrapper around
`configure-host.sh --scope stow`. It no longer contains a second deployment
engine or globally unstows packages. Read-only legacy flags map to v3;
`--adopt` and `--force` are rejected.

## Exit codes

| Code | Meaning |
|---:|---|
| 0 | Success/current |
| 1 | Drift/absent after status or verification |
| 2 | Blocked, invalid selection, failed prerequisite, or refused mutation |
| 3 | Internal error |

## Testing

```bash
bash tests/deploy/run-all.sh
```

The deployment suite covers CLI plan safety, profile resolution, selection,
Stow status and conflict behavior, SSH overlays, fresh package installation,
module metadata/idempotency, failure-safe synchronous/asynchronous runners,
rollback, dashboard cancellation, responsive/monochrome UI primitives, tool
portability, tmux updates, and the legacy compatibility wrapper.
