# READINESS-TO-MIGRATE REPORT — Stow → chezmoi

Independent evaluation, 2026-08-17. Reviewer: Hermes subagent (fresh context; not an
author of any evaluated document). Scope: all 10 project documents + AGENTS.md +
.hermes.md, plus read-only code verification of one load-bearing claim (cited below).
No git commands, no installs, no chezmoi commands, no live changes.

## VERDICT: CONDITIONAL GO for Phase 1 (sandbox spike)

Phase 1 is sandbox-only (scratch HOME, copied repo, one approved binary install —
design/03:24-28, 59-61) and the decisions that block it (D1–D4) are locked. Every
condition below is either documentation hygiene or a cheap pre-spike addition; none
makes the spike itself risky. The one substantive safety hole found (E1: the ssh
overlay has no unstow path) endangers Phase 3, not Phase 1 — and the spike (U7) is
exactly where it should be fixed, which is why the scope extension in E1 is a
condition rather than a blocker.

## Scorecard

| Dimension | Grade | Evidence |
|---|---|---|
| A. Decision completeness | A | design/04:27–256 — all 12 recorded with choice + date; D7 honestly open (170–171); status accurate (283–287) |
| B. Cross-doc consistency | B+ | Core GLM amendments all landed; 4 stale-marker defects remain (E2–E4, E8) |
| C. Safety of sequence | A− | Seq A/B + mandatory snapshot + Phase-5 soak gate solid; one real hole (E1) + one overstatement (E7) |
| Research grounding | A | research/01 (~540 lines, 36 cited URLs); GLM_Review §3 independently re-verified claims |
| Phase-1 executability | B+ | Phase-0 baseline not captured (E5); container runtime unstated (E6); D7 gating stricter than needed (E9) |

## Framework answers

**A — Decision completeness.** All 12 decisions are properly recorded: D1–D6 and
D8–D12 each carry a dated "DECIDED — A" block (design/04:27, 50, 67, 84, 102, 116,
185, 206, 227, 241, 256). D7's openness is honest and well handled: a plain-English
A/B explanation was added on request (design/04:133–168) and the status block says
"open, awaiting Ali's A/B choice (everything else in this document is decided)"
(design/04:170–171). The Status section (283–287) matches reality. No decision is
recorded as decided that isn't, in design/04 itself.

**B — Cross-document consistency.** The GLM amendments landed correctly where they
matter: Seq A/B + U7 (design/03:49–54, 118–133), U8 (55–57), Phase-2 container smoke
gate (93–98), Phase-5 entry gate + revert runbooks (186–199), mandatory snapshot
(111–114), no-`--force`/`--exclude=scripts` first apply (134–137), R5/R7 re-scored and
R14 added (design/04:268, 270, 277), `run_onchange_before_` age bootstrap
(design/02:76, 203–208), target-relative ignores + `--secrets=error`
(design/02:98–103), never-`chezmoi update` (design/02:281–284). Residual defects are
the marker/staleness items E2–E4 and the internal tension E8 — none change behavior,
all are one-line fixes.

**C — Safety of the migration sequence.** The corrected Phase 3 sequence (snapshot →
per-package `add --follow --secrets=error` → chattr → unstow-while-links → apply →
verify; design/03:109–140) is sound for every *catalogued* package, and per-package
granularity with a leaf-package first (143–148) is the right shape. The Phase 5 entry
gate (soak ≥1–2 weeks incl. reboot, old-system-intact invariant, per-phase revert
runbook) makes "nothing breaks while migrating" adequately protected *for the
packages the plan names*. Remaining misses: E1 (ssh overlay — no unstow mechanism,
and it is the most sensitive tree: config, authorized_keys, known_hosts), E7
 overstated gap claim, and (minor) no stated plan for the repo-root `.ssh/`
relative symlinks (analysis/02:31) that dangle once `ssh/` retires in Phase 5.

**D — Residual gaps before Phase 1.** E5 (Phase-0 baseline not captured despite
being Phase 0's exit criterion), E6 (container runtime availability/approval for the
U7 rehearsal), plus the docs hygiene items. D7 is *not* a Phase-1 blocker by the
plan's own blocking table (design/04:131 — D7 blocks Phase 4), so README:11's
sequencing ("Ali picks A or B on D7, then Phase 1") is stricter than required (E9).

**E — Verdict.** See top. CONDITIONAL GO.

## Findings

- **E1 (moderate — Phase 3 safety hole; extend U7).** `configure-host.sh prune`
  refuses `ssh-overlay` outright — verified in code at scripts/configure-host.sh:439–442
  ("prune does not support ssh-overlay"), and analysis/01:141–144 already documented
  that "prune refuse[s] to touch it". Yet Phase 3 Seq A names
  `configure-host.sh prune --stow-package <id>` as the unstow step (design/03:125–127),
  and every host has an ssh overlay (analysis/02 §2.1 — 9 components minimum per
  host). The plan never says how `~/.ssh` converts. Fix: add the ssh overlay to U7's
  rehearsal (raw `stow -D --dir=ssh/<host> --target=$HOME <pkg>` is viable — stow is
  stateless) and a special-case entry in Phase 3.
- **E2 (minor — stale open marker).** design/02:26 still says "— DECISION D4" for
  the secrets principle while design/02:186 says "DECIDED D4-A" and design/04:84
  confirms. Per design/02:5–6's own convention ("Decisions marked 'DECISION' are
  open"), a reader concludes D4 is open.
- **E3 (minor — DECIDED mislabel).** design/02:227 reads "DECIDED D7 — pending
  Ali's A-vs-B choice": labels an open decision DECIDED (design/04:170–171 says
  open). Should be "OPEN D7".
- **E4 (minor — stale review status).** GLM_Review.md:247 ("NOT applied — awaiting
  approval") and :266 ("Ali decides D1–D4") are now stale — README:9-10 says F1–F12
  were folded in, and D1–D4 are decided. Add a one-line "amendments applied
  2026-08-17" note to the review file.
- **E5 (moderate — Phase 0 incomplete).** Phase 0's exit criterion is "decisions
  recorded; baseline captured" (design/03:20), with the baseline artifact named at
  design/03:15–17 and README:44 (still parenthetical = not existing). README's next
  steps (80–86) omit it entirely. Capture `analysis/03-baseline-2026-08.md` before,
  or explicitly concurrent with, the spike.
- **E6 (minor — unstated spike prerequisite).** U7 rehearses "against a real symlink
  farm in the container" (design/03:52–54) and the Phase-2 exit gate needs a
  container (93–96), but neither the Phase-1 setup (59–61) nor the approval-gates
  table row for Phase 1 (246) mentions a container runtime; availability on servalws
  is unverified.
- **E7 (minor — overstatement).** design/03:128–129 claims "no app ever reads a
  half-migrated state". The Seq A unstow→apply gap is seconds-long but real — GLM
  itself scored it "low but real" (GLM_Review:88, 213–218). Soften to match.
- **E8 (minor — internal tension).** design/02:250–252 ("start all-copies for a
  clean v1 and flip specific trees to `symlink_`… later") sits uneasily beside locked
  D2-A (hybrid, with named symlink_ trees) and Phase 3 converting "the `symlink_`
  desktop trees" (design/03:145–146). Reconcile: all-copies = Phase-2 authoring
  default; chattr flips at Phase-3 conversion per step 2b.
- **E9 (info).** D7 blocks Phase 4 only (design/04:131); gating Phase 1 on it
  (README:11) serializes unnecessarily. Conservative, not wrong.
- **E10 (info — positive).** Prune mechanics verified in code: explicit IDs only,
  catalog check, double confirmation (configure-host.sh:428–466) — per-package Seq A
  unstow is executable exactly as written for all 30 catalogued packages except the
  one in E1. Stow statelessness (F12) also checks out against the analysis docs.

## What would make it a full GO

1. Extend U7's scope to rehearse the ssh-overlay conversion and add the Phase 3
   special case (E1) — the only substantive item.
2. Capture the Phase-0 baseline `analysis/03-baseline-2026-08.md` (E5).
3. Confirm container runtime availability and add it to the Phase-1 approval row (E6).
4. Docs hygiene: fix E2/E3 markers, add GLM "applied" note (E4), soften E7, clarify E8.
5. Ali closes D7 with one word (not Phase-1-blocking, but it completes the record).

All five are cheap; none require re-architecture. After items 1–2, this plan is as
safe as a live dotfiles-manager swap can reasonably be made.
