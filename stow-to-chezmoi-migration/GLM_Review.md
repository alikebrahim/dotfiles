# GLM Review — Stow → chezmoi Migration Plan

Reviewer: GLM-5.3 (via Z.AI), 2026-08-17.
Scope: `README.md`, `analysis/01–02`, `research/01–02`, `design/01–04`.
Method: full re-read of all nine documents plus independent re-verification of
load-bearing chezmoi claims against primary sources (chezmoi.io reference
pages, maintainer answers on GitHub, GNU Stow behavior). Per instruction,
**no documents were amended** — proposed amendments are listed in §7 for
approval.

---

## 1. Completeness audit — is everything in place?

| Expected deliverable | Status |
|---|---|
| Current-system architecture doc (analysis/01) | present, 319 lines, thorough |
| Repo inventory + legacy surface (analysis/02) | present, 195 lines, 30-package catalog |
| chezmoi feature deep-dive from official docs (research/01) | present, ~535 lines, 36 cited URLs |
| Articles/videos/podcasts bibliography (research/02) | present, ~370 lines, URLs verified |
| Pain-point → benefit mapping (design/01) | present, includes honest "what we lose" |
| Target architecture (design/02) | present: layout, data model, dual-user, secrets, scripts |
| Phased migration plan (design/03) | present, 7 phases, approval gates |
| Decisions + risk register (design/04) | present, D1–D12 + R1–R13 |
| Baseline snapshot (analysis/03), spike report (design/05) | correctly absent — Phase 0/1 deliverables |

**Verdict: complete for this stage.** Nothing promised is missing; nothing
present is stale. The two open slots are future-phase deliverables, correctly
marked.

---

## 2. Evaluation summary

| Dimension | Grade | Notes |
|---|---|---|
| Research grounding | **A** | Claims cited to official docs; version skew (2.3.1 vs 2.4.1) caught; dead links dropped honestly |
| Design soundness | **A−** | `.chezmoiroot` + data model + hybrid file model all match maintainer/community patterns; one encryption shape left open (correctly flagged as spike U2) |
| Plan structure | **B+** | Phases, gates, and exit criteria are good; two sequencing defects found (F1, F2) |
| Safety of migration | **B → A− after fixes** | Core safety property (old system intact as fallback until Phase 5) exists implicitly but is never stated as a gate; one Phase 3 ordering trap; see §4 |
| Optimized? | **B+** | Several concrete optimizations available (§6); plan is already lean |

**Overall: the plan is fundamentally sound and unusually well-researched. The
defects below are sequencing and explicitness problems, not architectural
ones. Fix F1–F4 before Phase 3 and the "nothing breaks" requirement is
realistically achievable.**

---

## 3. What I verified independently (with sources)

| Claim in the docs | Source checked | Result |
|---|---|---|
| Empty rendered `.tmpl` script is skipped (per-machine off switch) | user-guide/use-scripts-to-perform-actions | **Confirmed** — documented mechanism |
| `run_before_`/`run_after_` combined prefixes; scripts run in ASCII order | same + reference/target-types | **Confirmed** — design's script names are valid |
| `--exclude=scripts` exists on apply/init/diff | reference/commands/apply | **Confirmed** — enables files-first staged applies (unused by plan — see F5) |
| `create_` leaves existing file contents alone, still enforces perms | user-guide/manage-different-types-of-file | **Confirmed** — but status-noise after ssh writes needs spike check (F11) |
| `.chezmoiignore` is a template, `!` negation supported | user-guide/manage-machine-to-machine-differences | **Confirmed** — and patterns are **target-relative** (F8) |
| `.chezmoiroot` → `home/` subdir source state | user-guide/advanced/customize-your-source-directory | **Confirmed** — D3 option A is the documented pattern |
| `init` on a non-git dir creates a git repo; existing `.git` is detected | reference/commands/init | **Confirmed** — `~/.dotfiles` has `.git`, so init won't clone; but `chezmoi update` would `git pull` (F10) |
| `chezmoi add --follow`, `--secrets=ignore|warning|error` | reference/commands/add | **Confirmed** — `--secrets=error` unused by plan (F9) |
| `chezmoi edit --apply` / `--watch` | FAQ/usage | **Confirmed** — alias plan is valid |
| Encrypted templates cannot be partially encrypted directly; maintainer's `include \| decrypt` pattern | GitHub discussion #3713 (answered by twpayne) | **Verified workaround exists** — design's U2 should include it (F6) |
| age passphrase bootstrap: `key.txt.age` + decrypt-once script | FAQ/encryption | **Confirmed** — but FAQ uses `run_onchange_before_`, not `run_once_before_` (F7) |
| GNU Stow is stateless; `stow -D` only removes symlinks pointing into the package | Stow docs/behavior, community walkthroughs | **Confirmed** — this is what makes F1 a trap worth handling explicitly |

---

## 4. Findings

Severity: **S1** = must fix before that phase runs; **S2** = should fix;
**S3** = note for the spike/runbook.

### F1 (S1) — Phase 3 conversion order: `chezmoi apply` then unstow will not unstow cleanly

Plan step 3 applies chezmoi over the live stow symlink farm (replacing links
with real files), then step 4 unstows via `configure-host prune`. But `stow
-D` removes only symlinks pointing into the package — after chezmoi has
replaced them with real files, unstow hits "not a symlink" conditions. The
prune wrapper's conflict scan would flag it; result: a half-clean state
needing manual cleanup, on the daily-driver machine, mid-migration.

Two viable corrected sequences (pick in spike — add as unknown U7):

- **Seq A (clean, seconds-long gap):** per package: `chezmoi add --follow` →
  `stow -D` (links still links — clean removal) → `chezmoi apply`
  (materializes real files). Window where configs don't exist is seconds;
  running apps keep loaded state. Gap risk is low but real — do it package by
  package, not all at once.
- **Seq B (zero-gap, messier cleanup):** `chezmoi add --follow` →
  `chezmoi apply` directly over the farm (chezmoi replaces symlinks) →
  best-effort `stow -D` (warns/skips real files; stow is stateless so there
  is no leftover DB, just noisy output) → symlink sweep `find ~ -maxdepth N
  -xtype l` to prove none remain. Requires confirming chezmoi's
  symlink→file replacement semantics never prompts in a loop.

Either way, the plan text ("chezmoi add --follow … then apply … then prune")
must be corrected before Phase 3.

### F2 (S1) — Container smoke test is scheduled *after* the first real conversions

Phase 6 contains the disposable-container bootstrap test, but Phase 3
converts servalws before it. The smoke test is exactly the cheap, zero-risk
rehearsal the first conversion needs. Move it to the end of Phase 2 (build
tree → smoke-test bootstrap in container → only then touch a real host). This
is the single highest-value re-ordering in the plan.

### F3 (S1) — The core safety property is implicit, not stated as a gate

The strongest guarantee the plan has — "until Phase 5 deletes anything, the
entire old system (packages, profiles, configure-host) remains intact, so any
host can revert by simply re-running `configure-host apply`" — is never
written down as the governing invariant. Make it explicit:

- Phase 3/4 rule: no stow package may be deleted from the repo; revert path =
  `chezmoi` state removal + `configure-host apply` (per host, documented).
- Phase 5 entry gate: every host has run chezmoi exclusively for a soak
  period (suggest ≥1–2 weeks including a reboot) with no incidents.
- Write the per-phase revert runbook (Phase 3: re-stow; Phase 4: disable
  scripts + old module-runner; Phase 5: git revert).

### F4 (S2) — Per-host snapshot should be mandatory, not "decide with Ali"

For "nothing should break," make the Phase 3 snapshot a hard gate: `cp -a` of
all managed target paths + `~/.config/chezmoi/` (config + chezmoistate.boltdb)
to a timestamped dir outside the repo. Cheap, boring, and the fallback behind
the fallback.

### F5 (S2) — First apply on a drifted host: stage it, never `--force`

Live files will have drifted from the repo on every host (that drift is
invisible to the current system). chezmoi will prompt "modified since last
wrote" on first apply. Runbook additions: first apply per host uses
`--exclude=scripts` (files only, verified flag), review the full `chezmoi
diff` first, use `chezmoi merge` for drifted keep-both files, and treat
`--force` as forbidden during migration. Also set `diff.exclude = ["scripts"]`
in config so file diffs stay readable.

### F6 (S2) — Verified fallback shape for U2 encryption spike

The maintainer-confirmed pattern for mixing encryption with templates:
keep a separately encrypted data file and pull it in with
`{{ "file" | include | decrypt }}` (discussion #3713). If
`encrypted_` + `.tmpl` composition proves awkward in the spike, this is the
documented escape hatch — it should be listed in U2's options so the spike
doesn't stall.

### F7 (S3) — age-key bootstrap: prefer `run_onchange_before_` over `run_once_before_`

The official FAQ pattern uses `run_onchange_before_decrypt-private-key.sh.tmpl`
so key rotation re-runs the decrypt. `run_once_` would leave a stale key on
rotation. Cheap fix in Phase 2 authoring.

### F8 (S3) — `.chezmoiignore` patterns are target-relative

Ignore patterns match destination paths (e.g. `.config/awesome`, no `dot_`
prefixes). The design's ignore-template section doesn't state the convention;
Phase 2 authoring should, or the first `chezmoi ignored` check will confuse.

### F9 (S3) — Use `chezmoi add --secrets=error` during Phase 2/3 imports

The flag exists on `add` and catches secrets at import time — free hygiene
during the mass import, complementing the deferred gitleaks decision.

### F10 (S3) — Operator rule: never `chezmoi update` on this repo

`update` runs `git pull --autostash --rebase` — under the Syncthing model
(D1-A) that's the wrong distribution path and could surprise the user-owned
git state. Add to the Phase 5 runbook, docs rewrite, and AGENTS.md text:
daily driver is `chezmoi apply`; `update` is not used.

### F11 (S3) — `create_` known_hosts: verify no perpetual status noise

Docs confirm existing-file contents are left alone, but ssh appends to
known_hosts constantly. Spike must confirm `chezmoi status`/`diff` stays
quiet for a `create_` file whose contents changed after creation (expected:
quiet, because create_ doesn't track contents — verify, don't assume).

### F12 (info) — Stow's statelessness works in our favor

Stow keeps no database; a best-effort `stow -D` cannot corrupt anything —
worst case is warnings about non-symlinks. This is why both Seq A and Seq B
in F1 are safe to *try* in a container.

---

## 5. Direct answers to your questions

**Is everything being handled properly?**
Yes for analysis, research, design, and decision structure — all deliverables
present, decisions well-framed with recommendations, risks mostly real.
The handling gap is operational sequencing: F1 (conversion order), F2 (smoke
test timing), F3 (revert invariant not stated). Nothing architectural is
missing.

**Can it be better optimized?**
Yes, modestly: §6. The big ones are moving the container smoke test to
Phase 2 (F2), staged first-applies with `--exclude=scripts` (F5), and
per-package conversion granularity on servalws so the daily driver is never
mid-migration all at once.

**Evaluation of plan/design?**
Design: sound and verified against official patterns (`.chezmoiroot`, data
model, hybrid file model, honest loss table). Plan: well-gated but has the
two sequencing defects. Safety: strong *because the old system survives as
fallback until Phase 5* — after making that explicit (F3) and fixing F1/F2,
the residual break-risk windows are: (a) a seconds-long unstow→apply gap per
package (Seq A), (b) prompt-gated first applies on drifted files, (c) Phase 4
scripts, which are container-rehearsed and servalws-only. I'd call that low
residual risk.

**Will anything break while migrating?**
With F1–F4 applied: the most likely "break" is a running app reading a config
file during the seconds-long Seq A gap — mitigate by converting one package
at a time when the dependent app isn't mid-restart, and by preferring Seq B
if the spike confirms chezmoi's symlink-replacement is prompt-free. Without
F1 fixed, the likely failure isn't breakage but a stranded half-migrated
state needing manual cleanup on servalws — annoying, recoverable, avoidable.

---

## 6. Optimization opportunities (beyond findings)

1. **Rehearse in container first, always** (F2) — the smoke test becomes the
   regression suite *and* the rehearsal; run it per Phase-2 milestone, not
   once at the end.
2. **Per-package conversion order on servalws**: start with a leaf package
   (e.g. `picom` or `delta`), confirm Seq A/B mechanics live, then batch the
   rest; do `wezterm/awesome/quickshell` (the symlink_ trees) last since
   they're the live-edit surfaces.
3. **`chx` + `dot` aliases installed early** (Phase 3, not Phase 6 polish) —
   R1 (edit-reflex footgun) is the top post-migration failure mode; give the
   user the right reflexes from day one.
4. **`diff.exclude = ["scripts"]`** in per-machine config immediately — keeps
   every review readable.
5. **`chezmoi doctor` as a pre-flight artifact**: save output per host at
   conversion time; it doubles as the environment record for post-hoc
   debugging.
6. **Defer `.chezmoiexternal` entirely** (already leaning D7-A) — externals
   are invisible to diff; scripts keep everything reviewable.
7. **Phase 2 authoring order**: write `.chezmoiignore` + data model first,
   then bulk-import with `--secrets=error`, then templates last — templates
   are the only hand-written part; everything else is mechanical.

---

## 7. Proposed amendments (APPLIED 2026-08-17 — Ali approved; F1–F12 folded
into design/02–04 + README. All of D1–D12 recorded as A the same day (D7:
recommendation A accepted). Readiness pass E1–E4 fixes also applied. This
section is the historical change list.)

| Doc | Amendment | Finding |
|---|---|---|
| design/03 Phase 3 | Replace step 3–4 with Seq A/B selection + spike U7; add per-package granularity on servalws | F1 |
| design/03 Phase 2 | Add container smoke test as Phase 2 exit criterion | F2 |
| design/03 Phase 5 | Add entry gate: soak period + explicit "old system is the fallback" invariant + per-phase revert runbook | F3, F4 |
| design/03 Phase 3 | Mandatory snapshot incl. `~/.config/chezmoi/`; first apply `--exclude=scripts`; no `--force` rule | F4, F5 |
| design/02 §5 | Add `include \| decrypt` fallback to U2 | F6 |
| design/02 §6 | `run_onchange_before_` for age-key bootstrap | F7 |
| design/02 §2 | Note target-relative ignore patterns; `--secrets=error` on import; `diff.exclude` | F8, F9 |
| design/04 risk register | Re-score R5/R7 after F1/F3; add R14 "chezmoi update misuse" | F10 |
| design/03 Phase 1 | Spike additions: U7 (apply-over-stow-farm semantics), U8 (create_ status noise) | F11 |
| README.md | Status line: "reviewed 2026-08-17; S1 findings pending amendment approval" | — |

---

## 8. Recommended action plan from here

1. ~~Ali decides D1–D12~~ — decided 2026-08-17: all A.
2. ~~Approve amendments in §7~~ — approved + applied 2026-08-17.
3. Phase 1 spike with U1–U6 + U7/U8 from this review.
4. Phase 2 with smoke test as exit gate.
5. Phase 3 pilot per corrected sequence (Seq A default, Seq B if spike
   prefers), servalws, package-at-a-time, snapshot mandatory.

No documents were modified by this review; the only file written is this one.
