# stow-to-chezmoi-migration

Analysis, research, design, and planning project for migrating `~/.dotfiles`
from the current GNU Stow + `configure-host.sh` architecture to
[chezmoi](https://www.chezmoi.io/).

**Status (2026-08-17): design finalized; readiness = CONDITIONAL GO.**
Decisions D1–D6 and D8–D12 locked by Ali (all option A). D7 (tmux
plugins) open — plain-English A/B comparison in design/04; it blocks
Phase 4 only, not the spike. GLM review findings (F1–F12) and
readiness-report findings (E1–E10) are folded into the design and plan.
Remaining before Phase 1: capture the Phase-0 baseline snapshot
(`analysis/03`), then run the sandbox spike (unknowns U1–U8, now
including the ssh-overlay unstow rehearsal).

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
    └── (05-spike-report.md    <- Phase 1 deliverable)
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

1. ~~Ali reviews decisions D1–D4~~ — done 2026-08-17 (all A; D7 open).
2. Close D7 (A vs B for tmux plugins — explanation in design/04).
3. Approve Phase 1: sandbox spike (install chezmoi to a scratch location,
   test `.chezmoiroot`/`symlink_`/encryption/scripts/seq-A-B against a fake
   HOME and a container — unknowns U1–U8).
4. Build the `home/` source tree (Phase 2, container smoke test as exit
   gate).
