# Migration Plan — stow → chezmoi, phased

Phases with concrete steps, exit criteria, and approval gates. Every phase
that touches the live system or the repo requires Ali's explicit approval
before execution; agents prepare content and run read-only checks, but never
git operations and never deployments without authorization.

---

## Phase 0 — Decisions and baseline (Ali + agent)

1. Review and lock the open decisions in `04-decisions-and-risks.md`
   (D1–D12). Only D1–D4 are blocking for Phase 1–2; the rest can be decided
   per phase.
2. Baseline snapshot: `configure-host.sh status` + package list + current
   profile matrix (already captured in `analysis/02`). Store as
   `analysis/03-baseline-2026-08.md` for comparison after migration.
3. Decide legacy-surface dispositions (D9) — can wait until Phase 2.

**Exit:** decisions recorded; baseline captured.

---

## Phase 1 — Sandbox spike (no production changes)

Goal: answer the unknowns flagged in the design doc with real chezmoi runs in
a throwaway environment. No file outside a scratch area is touched; no live
deployment.

Unknowns to resolve:
- U1 `.chezmoiroot` mechanics: sourceDir = `~/.dotfiles` (a Syncthing synced
  dir, not a git checkout managed by chezmoi) + `.chezmoiroot` = `home/` —
  confirm init/config flags, `chezmoi add` behavior, and that `home/` syncs
  via Syncthing without interference.
- U2 Encryption shape for ssh config: `encrypted_dot_ssh/config.tmpl`
  (attribute + template compose?) vs per-host encrypted fragments — pick the
  working shape. Also `create_` + `known_hosts` behavior after ssh rewrites.
- U3 `symlink_` mechanics: `chezmoi add` → `chattr symlink` for a tree;
  whether symlink targets can point back into the source dir; exec-bit
  behavior for scripts (my-bin); behavior when the app rewrites the target
  file (flameshot.ini).
- U4 Data flow: `.chezmoi.toml.tmpl` prompts (`promptStringOnce`) generating
  per-machine `[data]`; `.chezmoidata.toml` merging.
- U5 Scripts: `run_onchange_` content-hash reruns; `run_once_` state reset
  (`chezmoi state delete-bucket --bucket=scriptState`); a `run_after_` sudo
  script against a fake root (`install -D` to a scratch dir).
- U6 Termux/macOS: no local test env — confirm install/build availability and
  template guards only (no execution).
- U7 **Unstow-vs-apply ordering (GLM review F1):** rehearse both sequences
  against a real symlink farm in the container — Seq A (unstow while links
  are links → apply materializes files) and Seq B (apply replaces links
  directly → best-effort `stow -D` + dangling-link sweep). Confirm whether
  chezmoi's symlink→file replacement prompts or loops, and pick the Phase 3
  default. **Includes the ssh overlay (readiness E1):** `prune` refuses
  `ssh-overlay` (configure-host.sh:439–442) yet every host has one —
  rehearse the raw `stow -D --dir=ssh/<overlay> --target=$HOME` unstow for
  `~/.ssh` and record the exact invocation.
- U8 `create_` + `known_hosts` status noise (GLM review F11): confirm
  `chezmoi status`/`diff` stay quiet when a `create_`-managed file's
  contents change after creation (expected: quiet — verify, don't assume).

Setup (needs one approval): install chezmoi binary to a scratch dir or
`~/.local/bin` (dnf or get.chezmoi.io), work against `HOME=/tmp/chezmoi-spike`
and a copy of the repo, never the live home. Container for the U7 rehearsal
and the Phase-2 smoke test: podman 5.8.4 and docker 29.7.1 are both present
on servalws (readiness E6, verified 2026-08-17) — use podman rootless.

**Exit:** spike report written to `design/05-spike-report.md`; unknown list
closed or re-scoped; final file-model split (D2) confirmed.

---

## Phase 2 — Build the new source tree (repo content, no deployment)

1. Create `home/` + special files (`.chezmoiignore`, `.chezmoidata.toml`,
   `.chezmoi.toml.tmpl`, `.chezmoiversion`, `.chezmoitemplates/`).
2. Migrate content package by package (mechanical, from `analysis/02`
   inventory): zsh, bash, git, vim, nvim, delta, my-bin, tmux-remote base +
   themes, wezterm, awesome, quickshell, picom, flameshot, apps,
   awesome_wm_scripts, awesomewm-bin, 1Password (if kept), posting/atuin/
   alacritty (if kept), ssh fragments, known_hosts seeds.
   - Rename per chezmoi conventions (`dot_`, `private_`, `executable_`,
     `create_`, `symlink_`, `.tmpl`).
   - Templates only where the design says so.
   - Write the `.chezmoiignore` selection template from the profile matrix.
   - Move module *assets* only as needed for Phase 4 scripts.
3. Write the scripts (install-packages, system modules, keyring, tmux
   plugins) as source files — but do not activate them yet.
4. `bash -n`-equivalent checks where shell is involved; template syntax via
   `chezmoi execute-template` in the spike env.
5. Update `AGENTS.md`/`.hermes.md` draft (deployment model, approval rules)
   for Ali's review — content changes to those files need explicit approval.

**Gates:** stow packages untouched; the repo still fully works as today.
`home/` is inert to the current system (not a catalogued package — verified:
top-level dirs are never inferred; add a doctor skip for `home/` if needed).

**Exit:** new tree builds and `chezmoi diff` (spike HOME) shows the expected
targets; **container smoke test passes** (fresh container →
`get.chezmoi.io` → `init --apply` → `verify` exit 0 → script effects
checked) — moved here from Phase 6 per GLM review F2, so the first real
host conversion is rehearsed, not experimental; Ali reviews the tree
layout.

---

## Phase 3 — Convert one host at a time

Pilot order: **servalws** (main machine, full stack — do it first while the
spike context is fresh, with full backup) → minisforoum / netmaster →
zotac-box (dual-user; highest complexity) → macbook → honor.
(DECIDED D10-A, 2026-08-17.)

Per host, with explicit approval per step:

0. **Mandatory snapshot (gate, not optional — GLM review F4):** `cp -a` of
   every managed target path **plus** `~/.config/chezmoi/` (config file +
   `chezmoistate.boltdb`) to a timestamped dir outside the repo. This is the
   fallback behind the fallback.
1. Pre-flight: `chezmoi doctor` (save the output per host), full
   `chezmoi diff` review with `diff.exclude = ["scripts"]` set so file
   diffs stay readable.
2. **Conversion sequence per package tree (GLM review F1 fix — never
   apply-then-unstow wholesale):**
   a. `chezmoi add --follow --secrets=error <tree>` — imports the stow
      symlink targets as managed source, with secrets hygiene at import.
   b. `chezmoi chattr` adjustments for the hybrid model (D2-A).
   c. **Seq A (default):** unstow that one package while its links are
      still links (`configure-host.sh prune --stow-package <id>`, run by
      the user) — clean removal — then immediately `chezmoi apply` for
      that tree to materialize real files. The unstow→apply gap is
      seconds; an app reading a config inside that window sees a
      momentary missing file (low but real — GLM:88), kept bounded by
      per-package granularity.
      **ssh-overlay exception (readiness E1):** `prune` refuses
      `ssh-overlay` outright (verified: scripts/configure-host.sh:439–442),
      and every host has an overlay. For `~/.ssh`, the unstow step is raw
      stow — `stow -D` against the overlay dir (`--dir=ssh/<overlay>
      --target=$HOME`); stow is stateless so worst case is warnings, but
      the exact invocation is rehearsed in spike U7 before any host uses
      it. Convert `~/.ssh` as its own single batch, never mixed into a
      package group.
      **Seq B (if spike U7 prefers):** `chezmoi apply` directly over the
      symlink farm (chezmoi replaces the symlinks), then best-effort
      `stow -D` (Stow is stateless — worst case is warnings, never
      corruption) and a dangling-link sweep
      (`find ~ -maxdepth 4 -xtype l`) to prove none remain.
   d. First full apply on a host runs `--exclude=scripts` (files only);
      scripts activate only after file state verifies green. **`--force`
      is forbidden during migration** — drifted files go through
      `chezmoi merge` so live changes are kept, not bulldozed.
3. Verify per package: `chezmoi status` clean for that tree, spot-check
   live files (perms, symlink vs copy), app smoke (wezterm/awesome/
   quickshell still load).
4. Commit history: Ali handles git as usual.

**servalws conversion order:** start with one leaf package (e.g. `delta` or
`picom`) to prove the chosen sequence live, then batch the static packages,
and convert the `symlink_` desktop trees (wezterm, awesome, quickshell,
awesome_wm_scripts) last — they are the live-edit surfaces. Install the
`dot` / `dot-apply` / `dot-edit` / `chx` aliases on day one (R1 mitigation),
not as later polish.

Special cases:
- **servalws**: after home conversion, Phase 4 (modules/tools) before
  pruning the last packages; `user:awesome-auth-startup` references
  `awesome/` — verify after conversion.
- **zotac-box**: two users, two conversions. tima first or Ali first per
  preference; per-user age keys and configs; shared-group repo access
  unchanged; confirm tima's `apps`-only selection via `.chezmoiignore`.
- **honor**: Termux — no local shell for agents; Ali drives; templates must
  not rely on `/bin/bash` (`lookPath`).

**Exit:** host fully managed by chezmoi, stow symlinks gone, no drift, user
confirms behavior.

---

## Phase 4 — Port modules + tools to chezmoi scripts (servalws)

1. `run_onchange_install-packages.sh.tmpl` from the tool registry (branch
   fedora/ubuntu; manual-hint tools echo instructions).
2. `run_after_system-modules.sh.tmpl`: ly, polkit, X11, battery unit, mate
   polkit package, gnome-keyring units — ported from `module-runner.sh`
   logic, preserving `install -D` + `cmp` self-verification and
   idempotency. Hostname-guarded to servalws.
3. tmux plugins: port `--ensure` to a `run_after_` script or
   `.chezmoiexternal` (D7); `--update` stays manual.
4. Test in a container (see Phase 6 validation) before touching servalws.
5. On servalws: `chezmoi apply` with the scripts; verify each module's
   `cmp`/`systemctl is-active` state.

**Exit:** configure-host's modules/tools/bootstrap are fully replaced;
`configure-host.sh` no longer needed on servalws.

---

## Phase 5 — Retire the stow machinery

**Entry gate (GLM review F3 — the governing safety invariant):**
- Every host has run chezmoi exclusively for a soak period (≥1–2 weeks,
  including at least one reboot) with no incidents.
- **Invariant until this phase completes:** the entire old system (stow
  packages, profiles, configure-host) remains intact and functional, so any
  host can revert by disabling chezmoi and re-running
  `configure-host apply`. No stow package is deleted from the repo before
  this gate passes.
- Per-phase revert runbook written and approved:
  - Phase 3 revert: chezmoi state removal + restore the mandatory snapshot
    + re-stow via `configure-host apply`.
  - Phase 4 revert: disable the `run_*` scripts (empty their templates or
    flip data flags) + old module-runner/tools still present → re-run.
  - Phase 5 revert: git revert of the retirement commits (history is the
    undo — D12-A).

1. Remove stow packages/overlays from the repo per D9 (user-approved);
   retire `scripts/profiles/`, `stow-catalog.sh`, `stow.sh`,
   `ssh-overlay.sh`, `check-fold.sh`, `stow-host.sh`, `.stowrc`,
   `install-tmux-plugins.sh` (if ported), `tests/deploy/*` (if replaced by
   the container smoke test — D11). Keep them in git history; no deletion of
   history.
2. Rewrite `docs/configure-host.md` → `docs/chezmoi.md` operator manual
   (daily commands, new-machine runbook, zotac dual-user section, secrets
   recovery).
3. Update AGENTS.md/.hermes.md (user-owned) to the new model: no more stow
   commands for agents; chezmoi apply is a live deployment requiring
   approval; `home/` is the source of truth.
4. Update `check-fold.sh` references; fold checks are obsolete.

**Exit:** no stow artifacts remain in active use; docs current.

---

## Phase 6 — Fleet completion + validation

1. Finish host conversions (any remaining in Phase 3).
2. Validation:
   - Per host: `chezmoi verify` green.
   - **Container smoke test** (mkasberg/shunk031 pattern): disposable
     container → `get.chezmoi.io` → `init --apply` → `verify` → script
     effects checked. This replaces `tests/deploy/` as the deployment
     regression suite (D11).
   - zotac dual-user: both users verified on the box.
3. Optional polish: aliases (`dot`, `chx`), optional gum wrapper (D8),
   Watchman/`edit --watch` for the symlink_ trees, gitleaks pre-commit if
   desired.
4. Final comparison vs Phase 0 baseline; close the migration; update
   `README.md` status.

**Exit:** every host runs on chezmoi; old system fully decommissioned;
docs + tests reflect the new system.

---

## Approval gates summary

| Phase | What needs approval |
|---|---|
| 0 | none (read-only + decisions) |
| 1 | installing the chezmoi binary (scratch or `~/.local/bin`); everything else is in /tmp |
| 2 | writing new repo content (explicit user request to build the tree), updating AGENTS.md/.hermes.md |
| 3 | per-host: snapshot, conversion sequence (add → unstow → apply per package), first `--exclude=scripts` apply — each a separate approved action |
| 4 | script activation on servalws (live modules/tools mutation) |
| 5 | soak-period gate passed; deleting/retiring repo artifacts |
| 6 | fleet apply on remaining hosts; docs rewrite |
