# Decisions and Risks

Open decisions for Ali, with options and recommendations, plus the risk
register. Decisions are ordered by when they block work. The design docs
(`02-target-architecture.md`, `03-migration-plan.md`) reference these by ID.

---

## Decisions

### D1 — Distribution channel

**Question:** Syncthing keeps carrying the repo to all hosts (today's model),
or do we switch to git-based distribution (`chezmoi update` pulls + applies)?

- **A (recommended): keep Syncthing.** Repo stays at `~/.dotfiles` synced as
  today; the daily command becomes `chezmoi apply`; git remains
  authoring/history-only on the primary host. `.stignore` discipline
  unchanged. chezmoi works fine with a non-git source dir.
- B: git distribution (`chezmoi update` everywhere; private repo + SSH).
  More conventional chezmoi, but changes sync infrastructure, requires
  handling remote hosts' git access, and touches the user-owned Syncthing
  rules. Defer; re-evaluate later.

**Blocks:** nothing (applies to both). **Recommended: A.**

> **DECIDED — A (2026-08-17, Ali):** Syncthing handles distribution; git is
> for safekeeping and history. Never run `chezmoi update` on this repo.

### D2 — File model: copies vs symlinks

**Question:** what should the deployed files be?

- **A (recommended): hybrid.** Default copies; `symlink_` for the actively
  developed desktop trees (wezterm, awesome, quickshell,
  awesome_wm_scripts), my-bin scripts, and app-managed configs
  (flameshot.ini); templates (⇒ copies) for per-host files (ssh, tmux theme,
  gitconfig); `create_` for known_hosts seeds.
  Preserves today's live-edit loops where they matter, follows docs/community
  elsewhere, and is reversible per-tree via `chezmoi chattr`.
- B: all copies (docs' default). Simplest mental model; loses write-through
  everywhere — every edit needs `chezmoi apply` (or `edit --watch`).
- C: all symlinks (`--mode=symlink` style). Closest to today; but no
  templates/encryption/private perms on those files, and the research
  consensus says copies win for repo hygiene.

**Blocks:** Phase 2 (tree layout). **Recommended: A**, confirmed by spike
unknowns U1/U3.

> **DECIDED — A (2026-08-17, Ali):** hybrid file model.

### D3 — Repo layout

**Question:** scope chezmoi's source state.

- **A (recommended): `.chezmoiroot` → `home/`.** Repo root stays the git +
  Syncthing root; everything outside `home/` is inert to chezmoi
  (scripts, docs, tests, legacy dirs, this migration project). Matches the
  author's own repo (twpayne/dotfiles) and shunk031/dotfiles.
- B: whole repo is source state (sourceDir = `~/.dotfiles`, no
  `.chezmoiroot`). Requires `.chezmoiignore`-ing scripts/, docs/, tests/,
  ssh/, *-archived/, stow-to-chezmoi-migration/ — more ignore surface and
  accidental-deploy risk.

**Blocks:** Phase 2. **Recommended: A.**

> **DECIDED — A (2026-08-17, Ali):** `.chezmoiroot` → `home/`.

### D4 — Secrets

**Question:** how do SSH configs / allowed_signers / signing config live?

- **A (recommended): age, per-user recipients**, with the docs' passphrase-
  protected `key.txt.age` bootstrap; `private_` for 0600 files;
  `create_` known_hosts seeds; gitleaks pre-commit only if repo goes public.
- B: 1Password template functions (`onepasswordRead`). No secrets at rest in
  the repo, but every apply needs `op` unlocked — the documented fatigue
  failure mode; also the shared-host prompt warning applies to zotac-box.
- C: keep plaintext in the (private) repo. Works, but the migration is the
  cheap moment to fix it; plaintext ssh configs are the main hygiene debt.

**Blocks:** Phase 2 (ssh files). **Recommended: A.**

> **DECIDED — A (2026-08-17, Ali):** age with per-user recipients.

### D5 — System modules (root-owned /etc files, services)

**Question:** how do ly/polkit/X11/battery/keyring modules run under chezmoi?

- **A (recommended): port to idempotent `run_after_`/`run_once_` scripts
  with sudo**, preserving `install -D` + `cmp` self-verification and
  hostname guards (servalws-only). Loses declarative status/rollback for
  `/etc`; mitigation = diff review + optional snapshot.
- B: keep a slimmed `configure-host.sh` (system/user scope only) invoked by
  chezmoi or manually. Preserves status/verify/rollback; keeps a second
  engine alive.
- C: Ansible for /etc. New infrastructure; overkill for one desktop host.

**Blocks:** Phase 4. **Recommended: A** (B acceptable if Ali values the
rollback machinery).

> **DECIDED — A (2026-08-17, Ali):** port modules to idempotent
> `run_after_`/`run_onchange_` scripts with sudo + `cmp` self-verification.

### D6 — Tools registry (dnf/apt installs)

**Question:** replace `tools.sh`?

- **A (recommended): `run_onchange_install-packages.sh.tmpl`** keyed on the
  `toolset` data value (content-hash re-runs on change), branching
  fedora/ubuntu; manual-hint tools stay manual.
- B: keep `configure-host.sh tools` as an external command.

**Blocks:** Phase 4. **Recommended: A.**

> **DECIDED — A (2026-08-17, Ali):** `run_onchange_install-packages.sh.tmpl`
> keyed on the `toolset` data value.

### D7 — tmux plugins

**Question:** how do tpm/plugins get installed and updated?

- **A (recommended): port `--ensure` into a `run_after_` script**; keep
  `--update` as an explicit manual command (unchanged semantics, no surprise
  updates during apply).
- B: `.chezmoiexternal` `git-repo` entries (v2.50+) with pins +
  refreshPeriod — declarative, but externals are invisible to `chezmoi diff`
  and add git-binary dependency.
- C: leave `install-tmux-plugins.sh` external (status quo).

**Blocks:** Phase 4. **Recommended: A** (revisit B later).

#### Plain-English: Option A vs Option B (requested by Ali)

Both keep the plugins on disk working exactly as today; the difference is
*who does the fetching* and *what shows up in your review*.

**Option A — a script that ensures plugins exist (`run_after_`):**
Think of it as a checklist that runs at the end of every `chezmoi apply`:
"if `~/.tmux/plugins/tpm` (or a plugin) is missing, clone it at the pinned
commit; otherwise do nothing." It's the same idea as the existing
`install-tmux-plugins.sh --ensure` — a plain shell script, just triggered by
chezmoi instead of by you.
- You see and review the whole logic in the diff (it's just a text file you
  wrote).
- Updating a plugin stays a deliberate act you run by hand.
- chezmoi only tracks *the script*, not the plugin files — the plugins never
  enter the repo or the sync.

**Option B — `.chezmoiexternal` (chezmoi's built-in "fetch from elsewhere"):**
Here you write a small list that says "this directory's content comes from
that git repo at that revision," and chezmoi itself downloads/refreshes it
during apply (no script of yours involved).
- More declarative: "what should be there" rather than "how to put it
  there."
- BUT externals are **invisible to `chezmoi diff`** — your review shows
  nothing about them changing; you must trust the refresh machinery.
  Refreshes happen on a timer (`refreshPeriod`), so plugin updates can land
  without ever appearing in a diff you reviewed.
- Extra moving parts: chezmoi must shell out to `git` for every external.

**The trade-off in one line:** A = you keep eyes on everything, at the cost
of maintaining a small script; B = less code, but changes happen outside
your review surface and on a timer.

**Recommendation stands: A.** It matches your "no surprise updates" rule —
which you also chose to preserve explicitly for `--update`. Say A or B and
this decision closes.

> **DECIDED — A (2026-08-17, Ali):** accepted the recommendation —
> `run_after_ensure-tmux-plugins.sh` (Option A); `.chezmoiexternal` deferred
> (GLM §6). All 12 decisions are now closed — every one option A.

### D8 — gum dashboard

**Question:** keep the interactive dashboard?

- **A (recommended): retire it.** Shell aliases (`dot`, `dot-apply`,
  `dot-edit`, `chx`) + docs replace daily use; chezmoi is CLI-first and
  `diff`/`verify` give better review.
- B: thin gum wrapper around chezmoi commands reusing the existing UI themes
  (orange-gas-plasma etc.) — possible later polish.

**Blocks:** none. **Recommended: A now, B optional later.**

> **DECIDED — A (2026-08-17, Ali):** retire the dashboard; aliases replace
> it; gum wrapper possible later.

### D9 — Legacy surface

**Question:** what to delete vs keep inert during migration?

| Artifact | Recommendation |
|---|---|
| `bin/` (empty package) | drop from catalog/retire |
| stray root `.zshrc` | investigate + remove with approval (it is not the zsh package file) |
| `wezterm/.../\` (backslash file) | remove (never deployed intentionally) |
| duplicate `scripts/polkit/`, `scripts/xorg/` | consolidate to `scripts/system/` copies |
| `1Password/` package | mostly superseded by the SSH key migration; decide keep/drop with Ali |
| `*-archived/` dirs | keep (history), inert under `.chezmoiroot` |
| old `tmux/` package | already reference-only; stays inert |
| empty per-user package shells (`alikebrahim_zotac-box/`, `tima_zotac-box/`) | retire with stow |

**Blocks:** Phase 2/5. **Recommended:** as table, each deletion separately
approved.

> **DECIDED — agreed as table (2026-08-17, Ali).** Ali additionally notes
> the old `tmux/` reference package has been moved into archived.
> *Flag (agent, 2026-08-17):* on servalws the repo top level still shows
> `tmux-remote` + all six `tmux-remote-*` overlays and no `tmux-archived`
> dir (archived dirs present: awesome-pillbar, awesome_wm_scripts, dunst,
> polybar, rofi). If the move happened on another host, Syncthing may not
> have propagated yet — verify before Phase 5 retires anything tmux-related.
> Not investigated further (repo-state inspection is the user's domain).

### D10 — Pilot host order

**Question:** which host converts first?

- **A (recommended): servalws** — it is the machine being used daily, the
  spike runs locally, and it exercises the full stack (packages + modules +
  tools); hardest case first while context is fresh.
- B: a low-stakes remote first (minisforoum/netmaster) — safer but SSH-only
  iteration and doesn't cover modules/tools.

**Blocks:** Phase 3. **Recommended: A** (with full snapshot + diff review).

> **DECIDED — A (2026-08-17, Ali):** servalws first.

### D11 — Deployment tests

**Question:** what happens to `tests/deploy/` (~1,590 lines)?

- **A (recommended): replace with a container smoke test** (fresh container →
  `init --apply` → `verify` → script effects), the community-proven
  pattern (mkasberg, shunk031). It tests the real deliverable (fresh-machine
  bootstrap) instead of the retired orchestrator.
- B: keep the deploy test suite adapted to chezmoi (largely obsolete).

**Blocks:** Phase 5/6. **Recommended: A.**

> **DECIDED — A (2026-08-17, Ali):** container smoke test replaces
> `tests/deploy/`.

### D12 — Git history

**Question:** migrate in the existing repo or start fresh?

- **A (recommended): same repo, same history.** The repo's stow-era history
  stays; migration commits are normal commits. `.gitignore` evolves
  (1Password/ un-ignored only if adopted properly; known_hosts handling
  changes).
- B: new repo. Loses history; unnecessary.

**Blocks:** none. **Recommended: A.**

> **DECIDED — A (2026-08-17, Ali):** same repo, same history.

---

## Risk register

| # | Risk | Likelihood / impact | Mitigation |
|---|---|---|---|
| R1 | **Edit-reflex footgun**: editing the live copy and forgetting `chezmoi add`/`apply` (the #1 community failure after leaving symlinks) | High / medium | `chx` wrapper from day one; `edit --watch` where wanted; symlink_ trees for the highest-edit surfaces; docs + AGENTS.md |
| R2 | **Template sprawl**: per-host logic creeping into templates until they're unreadable | Medium / medium | Rule: templates only for real variance; review in diffs; the ssh dispatcher + theme + gitconfig are the allowed set |
| R3 | **age key loss** → encrypted files unrecoverable | Low / high | passphrase-protected `key.txt.age` in repo (passphrase remembered/backed up); document recovery + rotation; per-user keys on zotac |
| R4 | **zotac-box dual-user misconfig** (perms, recipients, tima's selection) | Medium / medium | Spike with two fake users; per-user recipients; tima conversion separately approved; shared-host 1Password prompt off |
| R5 | **Root-file rollback loss** (`/etc` modules) after retiring rollback.tsv | Medium / medium | `install -D` + `cmp` verify discipline preserved; mandatory per-host snapshots incl. chezmoi state (Phase 3 gate); Phase 5 revert runbook (git revert; old module-runner kept until soak gate); diff review before apply |
| R6 | **Syncthing × chezmoi sourceDir interplay** (sync races, `home/` exclusion mistakes, `.stignore` surprises) | Medium / medium | Spike U1 explicitly; verify `.stignore` after Phase 2; keep chezmoi host state outside the repo |
| R7 | **Stow and chezmoi coexisting during Phase 3** (double management of same paths, fold safety dirs still enforced by old system) | Low–Medium / medium (re-scored after F1 fix) | Per-package Seq A: add → unstow while links are links → apply; never both managing the same file; `stow -D` is stateless (worst case warnings, never corruption); dangling-link sweep after each package; safety dirs kept until last package pruned; Seq A/B choice rehearsed in spike U7 + container |
| R8 | **honor/macbook cannot be tested locally** (Termux/macOS quirks: `/bin/bash`, umask, no `op` prompt) | Medium / low | `lookPath` shebangs; minimal templates for those hosts; Ali drives conversion; verify via SSH |
| R9 | **`known_hosts` adoption churn** (ssh rewrites file → drift) | Medium / low | `create_` semantics (seed once, then ssh owns); no more apply loops |
| R10 | **AGENTS.md/.hermes.md stale** → agents apply old rules to new system (or run chezmoi without approval) | Medium / medium | Phase 5 rewrite explicitly; add "chezmoi apply = live deployment, approval required" rule |
| R11 | **chezmoi version drift across hosts** (features like `git-repo` externals need ≥2.50) | Low / low | `.chezmoiversion` pin; `chezmoi upgrade` note in runbook |
| R12 | **Scope creep**: porting tools/modules/gum/tests all at once stalls the migration | Medium / medium | Phases are independent; D5/D6/D8 explicitly deferrable; v1 = home dir + ssh + themes |
| R13 | **Nested chezmoi calls in scripts** (state-lock timeout) | Low / high | Script rule from day one; lint in review; spike U5 covers it |
| R14 | **`chezmoi update` misuse** — it runs `git pull --autostash --rebase`, wrong under Syncthing distribution (D1-A) and touches user-owned git state | Low / medium | Forbidden-command rule in runbook, docs, and AGENTS.md rewrite (Phase 5); standing rule in design/02 §8; daily driver is `chezmoi apply` only |

---

## Status

- **All 12 decisions locked 2026-08-17 (Ali) — every one option A,**
  matching recommendations. D7 closed late the same day: recommendation A
  accepted (`run_after_` ensure-script; `.chezmoiexternal` rejected for
  diff-invisibility).
- Risks re-scored 2026-08-17 after the GLM review (R5, R7 updated; R14
  added). Re-score again after the spike closes U1–U8.
