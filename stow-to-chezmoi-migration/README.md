# stow-to-chezmoi-migration

Analysis, research, design, and planning project for migrating `~/.dotfiles`
from the current GNU Stow + `configure-host.sh` architecture to
[chezmoi](https://www.chezmoi.io/).

**Status (2026-08-22): HONOR IN PROGRESS.** Phase-A tree adaptation done
(honor's Termux blocks adopted fleet-wide behind $PREFIX guards, all
inert elsewhere; pyenv guard; extended-keys fix; secrets.env sourcing
line). One fleet age identity decided (2026-08-22): recipient in
`.chezmoidata.toml [age]`, encrypted_private_secrets.env carries
BRAVE_API_KEY, honor-only initially; identity off-repo.
**Gate: netmaster:dotfiles.git stale (head 242436e Aug 18, no home/) —
Ali must push the current tree before honor re-clone (Phase C).**
Phase 3 complete on minisforoum (design/09),
netmaster (design/10), macbook (design/11). Phase 4 complete on servalws — all
four run_* scripts activated and green live (record: design/08-phase4-record.md).
Phase 3 complete — all 130 stow symlinks
converted to chezmoi-managed files (276 unstows incl. 91-apps/icons,
status clean, idempotent; snapshot + record at
design/07-phase3-record.md). Phase 2 exit gate PASSED.** All 12 decisions locked by Ali (every one option A; D7 closed
2026-08-17: `run_after_` ensure-script, externals rejected). GLM review
findings (F1–F12) and readiness-report findings (E1–E10) folded into the
design and plan. Baseline captured (`analysis/03-baseline-2026-08.md`);
Phase 1 spike (U1–U8) executed and reported (`design/05-spike-report.md`).
Phase 2 (2026-08-18/19): `home/` tree built (299 files: bulk copy with
mode-derived attributes + authored templates/scripts), validated by a
six-host container apply matrix (rc=0, idempotent, per-host themes/ssh/
gating all correct) and the container smoke exit gate (fresh `init
--source` → apply → verify exit 0 → modes faithful). Deviations from
design/02 are logged in `design/06-phase2-record.md` (hostname-keyed
hostFacts instead of init prompts; never-selected packages skipped;
authorized_keys plaintext `private_` with encryption deferred per D4-A;
pre-existing `.gitconfig`→delta include mismatch preserved and PARKED for
a deliberate post-migration fix). Next: Phase 3 — convert servalws first,
with the mandatory snapshot gate.

## Why this project exists

The current dotfiles system works but carries significant machinery that
exists to manage Stow's limitations (tree folding, `stow -R` failure modes,
per-host overlays as separate packages, drift detection scripts, etc.).
chezmoi offers features (templates, per-machine data, encryption, scripts,
single-binary install) that can simplify or replace most of this system.

## The bottom line (short version)

- The majority of the ~4,800-line orchestrator exists to keep Stow from
  hurting us (13 safety mechanisms documented). chezmoi's native directory
  management + diff-based apply removes the entire hazard class.
- Per-host variance (6 tmux theme overlays, 7 ssh overlay dirs, per-user
  zotac packages) collapses into templates + per-machine data.
- Secrets (ssh configs currently plaintext in the repo) get age encryption
  and `create_` known_hosts seeds.
- New machines go from a multi-command bootstrap to one command
  (`get.chezmoi.io` → `init --apply`); macbook (macOS) and honor (Termux)
  become first-class instead of unsupported.
- Honest losses: system-file rollback manifests, the gum dashboard, named
  packages — each has a documented mitigation.

## Directory layout

```
stow-to-chezmoi-migration/
├── README.md                  <- this file (project home + status)
├── analysis/                  <- how the current system works
│   ├── 01-current-system.md   <- end-to-end architecture + safety machinery
│   ├── 02-repo-inventory.md   <- 30-package catalog, matrix, legacy surface
│   └── (03-baseline snapshot  <- Phase 0 of the plan)
├── research/                  <- what chezmoi offers and what people say
│   ├── 01-chezmoi-features.md <- feature deep-dive from official docs (v2.72.0)
│   └── 02-articles-videos.md  <- 15 articles, 8 videos, 4 podcasts, 5 repos, opinions
├── GLM_Review.md               <- adversarial review (2026-08-17); findings folded into design/
├── READINESS_REPORT.md         <- independent readiness evaluation (2026-08-17): CONDITIONAL GO
└── design/                    <- the new system
    ├── 01-benefit-mapping.md  <- pain points → chezmoi features, losses
    ├── 02-target-architecture.md <- repo layout, data model, per-host/user, secrets, scripts
    ├── 03-migration-plan.md   <- phases 0-6 with approval gates
    ├── 04-decisions-and-risks.md <- D1-D12 for Ali + risk register
    ├── 05-spike-report.md      <- Phase 1 spike results (U1–U8, S1–S4)
    └── 06-phase2-record.md     <- Phase 2 build record (tree, deviations, evidence)
```

## Key documents to read first

1. `design/04-decisions-and-risks.md` — the 12 decisions Ali needs to make
   (D1–D4 block the next phase) and the risk register.
2. `design/01-benefit-mapping.md` — why migrate: the pain-point → feature
   mapping and what we lose.
3. `design/02-target-architecture.md` — what the new system looks like.
4. `design/03-migration-plan.md` — how to get there, phase by phase.

## Working agreements (from repo rules)

- This project is **read-only** with respect to the existing dotfiles
  configuration. Nothing outside this directory is modified without explicit
  approval.
- No Git operations and no Syncthing coordination are performed by agents.
  The user owns repository history, review, and propagation.
- No live deployment (stow/configure-host/chezmoi apply, service changes)
  happens as part of this project without separate explicit authorization.
- This directory is a plain documentation project, **not** a Stow package and
  not chezmoi-managed (yet).

## Next steps

1. ~~Ali reviews decisions~~ — done 2026-08-17: all 12 decisions A
   (D7 closed same day).
2. ~~Capture the Phase-0 baseline snapshot~~ — done 2026-08-18
   (`analysis/03-baseline-2026-08.md`).
3. ~~Approve Phase 1: sandbox spike~~ — done 2026-08-18 ("age installed.
   Proceed"): all unknowns U1–U8 closed, `design/05-spike-report.md`
   written, corrections S1–S4 folded into design/02 + design/03.
4. Approve Phase 2: build the `home/` source tree in the repo
   (container smoke test as exit gate).
