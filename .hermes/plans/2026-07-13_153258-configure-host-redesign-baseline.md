# Configure-Host Redesign Baseline Implementation Plan

> **For Hermes:** Use subagent-driven-development skill to implement this plan task-by-task.

**Goal:** Replace the monolithic deployment flow with an idempotent host-aware orchestrator that retains GNU Stow for home-directory files and manages privileged system configuration through explicit modules.

**Architecture:** `scripts/configure-host.sh` becomes the public entry point. It resolves a known host profile, runs preflight checks, invokes a narrowed `scripts/stow-host.sh` for user-file deployment, and runs selected user/system modules. Profiles define desired state; modules compare source and target state and only mutate when drift exists.

**Tech Stack:** Bash 5+, GNU Stow, `cmp`, `install`, `sudo`, `git`, existing shell tooling. Initial tests use dependency-free Bash command mocks because Bats, ShellCheck, and shfmt are not currently installed.

---

## Current-state facts

- `scripts/stow-host.sh` currently owns host resolution, Stow safety/deployment, system Xorg installation, tmux plugin mutation, SSH overlays, and tmux reload behavior.
- Current known hosts are `netmaster`, `servalws`, `minisforoum`, `zotac-box`, `macbook`, and `honor`; zotac-box additionally varies by user.
- Unknown hosts currently receive common packages automatically. The redesign will allow inspection but refuse normal apply for unknown hosts.
- `scripts/check-fold.sh` has its own hard-coded host list and must consume the shared profile registry instead.
- The current servalws deployment check has 49 passes, 0 failures, and one expected SSH-overlay warning.
- `scripts/xorg/40-libinput-natural-scrolling.conf` is currently installed and byte-identical at `/etc/X11/xorg.conf.d/40-libinput-natural-scrolling.conf`.
- `scripts/polkit/49-1password-unlock.rules` exists in the repository but is not installed at `/etc/polkit-1/rules.d/49-1password-unlock.rules`.
- `scripts/install-tmux-plugins.sh` pulls plugin updates during every deployment. This is convergent but not reproducible/no-op idempotent.
- GNU Stow is currently version 2.4.1; the repository instructions still state 2.3.1.

## Target layout

```text
scripts/
  configure-host.sh                 # public orchestration CLI
  stow-host.sh                      # narrowed Stow-only compatibility command
  lib/
    cli.sh                          # argument parsing, help, exit-code policy
    log.sh                          # PASS/WARN/FAIL and structured reporting
    profile.sh                      # host, user, and OS/profile resolution
    safety.sh                       # Stow/tree-fold/symlink checks
    stow.sh                         # simulate/restow/prune helpers
    module-runner.sh                # module lifecycle dispatch
  profiles/
    common.conf
    netmaster.conf
    servalws.conf
    minisforoum.conf
    zotac-box.conf
    macbook.conf
    honor.conf
  modules/
    tmux-plugins.sh
    system/
      xorg-libinput.sh
      1password-unlock-polkit.sh
  system/
    xorg-libinput/
      40-libinput-natural-scrolling.conf
    polkit/
      49-1password-unlock.rules

tests/
  deploy/
    test-profile-resolution.sh
    test-module-idempotency.sh
    test-cli-plan-mode.sh
    fixtures/
```

## Command interface

```text
configure-host.sh list
configure-host.sh check
configure-host.sh status
configure-host.sh plan
configure-host.sh apply --yes
configure-host.sh update tmux-plugins
```

Global flags:

```text
--host HOST              Resolve a named profile for list/check/plan.
--scope LIST             Limit to stow,tmux,system.
--only MODULE            Limit execution to one named module.
--skip MODULE            Exclude one named module.
--yes                    Required for unattended apply.
--dry-run                Temporary compatibility alias for plan.
--verbose                Print child command output.
--json                   Future machine-readable list/status/plan output.
--adopt PACKAGE          Explicit package-scoped Stow adoption only.
--prune                  Explicitly unstow packages absent from the profile.
--force-system           Permit replacing a differing managed system target.
--allow-unknown-host     Explicit override for common-only deployment.
```

`--no-tmux`, `--no-ssh`, and `--no-xorg-input` should be retained only as temporary compatibility aliases; `--scope`, `--only`, and `--skip` communicate intent more safely.

## Idempotency and safety contract

1. `check`, `status`, and `plan` never call sudo, mutate Stow links, pull plugins, clone repositories, reload tmux, or alter system state.
2. Default Stow apply only restows selected packages after successful simulation. It does not globally unstow all known packages.
3. Stale package cleanup requires `--prune` and must list each planned unstow before acting.
4. `--adopt` remains explicit and package-scoped; never silently adopt host-local files into Syncthing.
5. Each system module reports one of `CURRENT`, `ABSENT`, `DRIFT`, `BLOCKED`, `NOT_APPLICABLE`, or `UNKNOWN` based on direct source/target checks.
6. System files are installed only when missing or different; unreadable/unexpected targets require explicit force.
7. The normal apply path installs missing tmux plugins at declared revisions; network upgrades become `update tmux-plugins`, not an implicit deployment side effect.
8. Profile resolution is the single source of truth for `configure-host.sh`, `stow-host.sh`, and `check-fold.sh`.
9. An unknown host may be inspected but normal apply must fail before any privileged operation.

## Module lifecycle

Every module exposes the same contract:

```text
describe   state ownership and prerequisites
supported  host/OS/session applicability
check      validate source, target, commands, and permissions
status     report current/absent/drift/blocked state
plan       describe exact no-write changes
apply      converge only when necessary
verify     re-check final desired state
```

Initial module policy:

- `system:xorg-libinput`: explicit profile selection; source/target `cmp`; reports that a new Xorg session is needed after a changed install.
- `system:1password-unlock-polkit`: servalws only initially; requires the 1Password policy action and wheel membership; manages only `com.1password.1Password.unlock`.
- `tmux-plugins`: handles missing, pinned plugins during apply; explicit update and repair modes handle network refreshes or unexpected directories.

## Implementation tasks

### Task 1: Characterize present behavior with dependency-free tests

**Files:**
- Create: `tests/deploy/test-profile-resolution.sh`
- Create: `tests/deploy/test-cli-plan-mode.sh`
- Create: `tests/deploy/test-module-idempotency.sh`
- Create: `tests/deploy/fixtures/`

1. Build a small Bash assertion helper and command-mock PATH fixture.
2. Add expected profile output for every known host and zotac-box user variation.
3. Add tests proving list/check/plan never invoke `sudo`, `stow -D`, `git pull`, or `git clone`.
4. Capture the current package sets from `stow-host.sh --host HOST --list` as regression fixtures.

**Verify:** Run each `bash tests/deploy/test-*.sh`; all should pass before refactoring runtime code.

### Task 2: Extract profile resolution and shared safety functions

**Files:**
- Create: `scripts/lib/profile.sh`
- Create: `scripts/lib/safety.sh`
- Create: `scripts/profiles/common.conf`
- Create: `scripts/profiles/{netmaster,servalws,minisforoum,zotac-box,macbook,honor}.conf`
- Modify: `scripts/check-fold.sh`

1. Implement canonical hostname, user, and `/etc/os-release` detection.
2. Encode existing package/SSH/tmux selections declaratively with no behavior change.
3. Move tree-fold and Stow dry-run checks into shared library functions.
4. Make `check-fold.sh` enumerate known profiles through the shared registry.
5. Add unknown-host resolution behavior: inspect allowed, apply refused by default.

**Verify:** Existing profile regression tests remain green and `check-fold.sh` list output includes honor.

### Task 3: Narrow `stow-host.sh` to Stow operations

**Files:**
- Modify: `scripts/stow-host.sh`
- Create: `scripts/lib/stow.sh`

1. Preserve the public Stow-oriented CLI for one migration cycle.
2. Consume the new profile resolver instead of embedded host/package maps.
3. Retain per-package simulate checks and tree-fold refusal.
4. Remove system file installation and tmux plugin mutation from normal Stow execution.
5. Replace unconditional global unstow with selected-package restow.
6. Implement explicit `--prune` planning and apply behavior.

**Verify:** `stow-host.sh --check` and `--dry-run` stay non-mutating; profile fixtures remain identical to baseline output.

### Task 4: Implement independent modules

**Files:**
- Create: `scripts/lib/module-runner.sh`
- Create: `scripts/modules/tmux-plugins.sh`
- Create: `scripts/modules/system/xorg-libinput.sh`
- Create: `scripts/modules/system/1password-unlock-polkit.sh`
- Create: `scripts/system/xorg-libinput/40-libinput-natural-scrolling.conf`
- Create: `scripts/system/polkit/49-1password-unlock.rules`

1. Define and validate the common lifecycle functions.
2. Migrate Xorg source/target management with `cmp`-first behavior.
3. Migrate the existing 1Password rule with narrow action and applicability checks.
4. Separate tmux install, update, and repair paths; do not delete unexpected directories automatically.
5. Keep old source paths as compatibility shims only if needed for a safe Syncthing rollout.

**Verify:** Module idempotency test runs twice and the second run plans no changes for converged fixtures.

### Task 5: Implement the orchestration CLI

**Files:**
- Create: `scripts/configure-host.sh`
- Create: `scripts/lib/cli.sh`
- Create: `scripts/lib/log.sh`

1. Implement `list`, `check`, `status`, `plan`, `apply`, and `update` dispatch.
2. Resolve profile once and pass the resolved data to Stow and modules.
3. Aggregate validation outcomes and fail apply before any write when a selected module is blocked.
4. Require `--yes` for non-interactive apply.
5. Use sudo only for a selected system module with actual drift.
6. Print changed, current, skipped, and manual-follow-up module summaries.

**Verify:** Test every known profile with `configure-host.sh plan --host HOST`; test unknown-host apply refusal.

### Task 6: Document and roll out

**Files:**
- Modify: `AGENTS.md`
- Modify: `scripts/stow-host.sh` help text
- Create: `scripts/README.md` or update the appropriate existing documentation

1. Document the new entry point and compatibility path.
2. Correct the Stow-version statement after reconfirming fleet support.
3. Document profile-to-module mappings and system-module ownership.
4. Document the required Syncthing-before-apply workflow.
5. Dry-run known profiles, then deploy servalws only after an inspected plan.

**Verify:** `bash -n` all shell files; deployment tests pass; `configure-host.sh check`, `plan`, and repeat `plan` show expected no-mutation and no-op behavior.

## Explicitly out of scope for the baseline

- Package-manager provisioning (`dnf`/`apt`) during ordinary configuration apply.
- Automatic installation of operating-system packages without explicit opt-in.
- Replacing Stow with another dotfiles manager.
- Automatic remote Syncthing synchronization or mutation of other hosts.
- Broadening 1Password polkit authorization beyond the desktop unlock action.

## Risks and rollout notes

- Syncthing propagates changes before deployment; do not move/delete existing source paths until every host has received and validated the migration.
- Package pruning and Stow adoption can alter host-local state and must stay explicit.
- System file targets require root and must not be treated as normal Stow symlinks.
- The current plan needs amendment before implementation to account for interactive UX, dependency bootstrap policy, and servalws-specific system changes identified in historical sessions.
