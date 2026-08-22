# Spike Report — Phase 1 sandbox results

**Date:** 2026-08-18 · **Status:** COMPLETE — all unknowns U1–U8 closed
**Environment:** chezmoi v2.72.0 (Fedora build, servalws), age 1.3.1, sandbox
at `/tmp/chezmoi-spike` (fake HOME + source repo), plus one rootless podman
container (`fedora-minimal:latest`, stow 2.4.1 + chezmoi installed via dnf)
for the U7 rehearsal. No live file, no stow package, no repo content outside
this project directory was touched.

**Verdict:** the target architecture works as designed. Seq A is confirmed as
the Phase 3 default. Four findings (S1–S4 below) require small corrections,
all now folded into design/02 and design/03. Nothing reopens a decision.

---

## Quick reference

| # | Unknown | Verdict |
|---|---------|---------|
| U1 | `.chezmoiroot` + non-git sourceDir | ✅ works; two footnotes (init plants `.git`; state lives in destination) |
| U2 | age encryption + template composition | ✅ works; decrypt→render order confirmed; `default` does not guard missing keys |
| U3 | `symlink_` mechanics | ✅ dir symlink = `symlink_<name>` **file**; `add` auto-relativizes; `--follow` refuses dirs |
| U4 | config template + prompts + data merge | ✅ works; **whole-config render** — age settings must live in the template |
| U5 | `run_once_` / `run_onchange_` semantics | ✅ works; onchange hash is NOT in the scriptState bucket |
| U6 | Termux/macOS guards | ✅ render correct on Linux; branch syntax parse-validated |
| U7 | Seq A vs Seq B container rehearsal | ✅ **Seq A default confirmed**, 23/24 automated PASS; ssh-overlay raw `stow -D` validated |
| U8 | `create_` + known_hosts status noise | ✅ status/diff quiet after external rewrite — **but source must be non-empty** |

---

## U1 — `.chezmoiroot` + non-git sourceDir

Tested: `chezmoi init --source <repo> --destination <fake-home>` where repo
has `.chezmoiroot` = `home/` and is a plain directory (no git).

- Init, apply, `chezmoi add`, status all work against a non-git sourceDir.
  The Syncthing-only shape is fully supported.
- `chezmoistate.boltdb` lives in the **destination home**, not the repo —
  nothing stateful enters the synced tree (as designed).
- **Footnote 1:** `chezmoi init` planted a `.git` directory in a source repo
  that had none (chezmoi assumes the git workflow when no repo URL is given).
  Harmless for `~/.dotfiles` (already a git repo). For a truly Syncthing-only
  source, delete the planted `.git` or init with an explicit no-clone path.
- **Footnote 2:** `chezmoi doctor` will warn about the git tree forever
  (dirty/untracked files). Permanent and cosmetic — document in the operator
  manual so nobody "fixes" it.

## U2 — age encryption × template composition

Tested: test keypair via `age-keygen`; `chezmoi add --encrypt`;
`encrypted_dot_secret-netconf.age`; composite `encrypted_dot_ssh-config.tmpl.age`.

- age encrypt/decrypt round-trip clean; `status` stays quiet.
- Composite name `encrypted_<name>.tmpl.age` is recognized and manages
  `<name>` — the D4-A fragment shape is valid.
- **Order confirmed: decrypt first, then render template.** Post-decryption
  content is a normal Go template (attributes like `.tmpl` work inside).
- **`{{ .key | default "x" }}` does NOT guard a missing data key** — Go map
  semantics: template evaluation fails before `default` applies. Every key
  referenced by a template must exist in `.chezmoidata.toml` or config
  `[data]`. This is a Phase-2 authoring rule (see S2).
- Drift UX: deleting a managed file outside chezmoi triggers the
  "file has changed since chezmoi last wrote it" prompt; in a TTY-less
  context apply **aborts cleanly — it never bulldozes**. Good failure mode.

## U3 — `symlink_` mechanics

- `executable_` prefix preserves exec bits (my-bin shape).
- **A directory symlink is a `symlink_<name>` FILE whose content is the
  target path.** `chattr +symlink` on a directory is a **silent no-op**
  (returns success, changes nothing) — never rely on it; author the
  `symlink_` file directly.
- `chezmoi add` on a symlink WITHOUT `--follow` absorbs it as a `symlink_`
  entry and **auto-relativizes an absolute target** (created `→ /abs/path`,
  stored `../../repo/...`). The repo's "relative symlinks only" rule is
  enforced natively by `add`.
- **`--follow` refuses to recurse into directories** ("follow and recursive
  are mutually exclusive") — confirmed twice, including top-level
  tree-folded dirs. Kills `add --follow` as a bulk import path (see S1).
- Symlink pointing INTO the chezmoi source dir works: app write-through
  lands in the repo and `chezmoi status` stays clean — the stow-like
  live-edit shape for wezterm/awesome/quickshell is valid.

## U4 — config template, prompts, data merge

- `promptStringOnce` / `promptBoolOnce` / `promptChoiceOnce` are
  **interactive widgets** — they need a real TTY (piped stdin fails;
  scripted pty works; `promptChoiceOnce` is a fuzzy-select only navigable
  with arrow keys). Fine for real hosts (human runs init once); automation
  must use pre-seeded config or env data instead.
- **Critical: `.chezmoi.toml.tmpl` renders the ENTIRE config.** Re-running
  `init` regenerated the config from the template and **wiped a manually
  added `[age]` section**. Therefore the age identity/recipient settings
  must live inside `.chezmoi.toml.tmpl` itself (rendered from a prompt or
  data), or be re-applied after every init (see S3).
- Merge precedence measured: config `[data]` **overrides** `.chezmoidata.toml`
  for the same key. Per-machine facts win over shared defaults — matches the
  design's intent.
- Generated per-machine data correctly picked up the real hostname
  (`isServalws = true` while running on servalws against a fake HOME).

## U5 — script semantics

- `run_once_`: runs exactly once across repeated applies; re-runs after
  `chezmoi state delete-bucket --bucket=scriptState` — the documented reset
  works.
- `run_onchange_`: re-runs on content change (v1→v2 confirmed). **Its content
  hash does NOT live in the scriptState bucket** — deleting that bucket did
  NOT reset it (hash is keyed elsewhere in state). Practical effect: to
  force an onchange re-run, change the script content; state-bucket surgery
  won't do it (see S4).
- sudo `install -D` + `cmp` self-verification pattern works inside
  `run_after_` scripts (non-interactive sudo in sandbox; on live hosts the
  password prompt appears in the terminal running apply — expected).

## U6 — Termux/macOS guards (paper check)

Rendered a guard template on Linux: `.chezmoi.os` / `.chezmoi.arch` /
`.chezmoi.hostname` / `lookPath` all resolve correctly; the
darwin/android/else branches are valid chezmoi template syntax (renderer
parsed and evaluated the whole file). No local Termux/macOS execution —
accepted as paper-validated; Phase 3 host conversions will exercise the
real branches on macbook/honor.

## U7 — container rehearsal (Seq A vs Seq B) ★ the E1 answer

Environment: fresh fedora-minimal container, stow + chezmoi via dnf; a
miniature production farm (zsh + my-bin packages stowed with
`--dir/--target`, ssh overlay stowed with `stow -R --dir=repo/ssh
--target=$HOME servalws`, a REAL known_hosts file sitting in `~/.ssh`).
Automated result: **23/24 PASS** (the 24th was a test-script bug — wrong
flag placement in my probe, not a chezmoi behavior; the behavior it probed
was confirmed in a corrected follow-up run).

**Seq A (unstow while links are links → apply) — CONFIRMED DEFAULT:**
- Package unstow (`stow -D --dir repo --target $HOME zsh my-bin`): clean.
- **ssh overlay unstow via raw `stow -D --dir=repo/ssh --target=$HOME
  servalws` — the exact E1 invocation — works**, and the real
  `known_hosts` SURVIVED the unstow untouched.
- `chezmoi apply` materialized real files: correct content, exec bits,
  `.ssh/config` real file, and — key result — **`create_` did NOT clobber
  the existing known_hosts content**.
- `chezmoi status` clean after the full sequence; zero dangling links
  (`find -xtype l` empty).

**Seq B (apply over the farm, then late `stow -D` + sweep) — VIABLE
FALLBACK:**
- Without `--force`: chezmoi **refuses** (exit 1, prompt about modified
  files) — the safety net is real. On live migration this is why `--force`
  was forbidden; Seq B on live hosts would need per-file `merge` first.
- With `--force` (sandbox only): links replaced by real files, content
  correct, known_hosts intact, no dangling links, status clean.
- Late `stow -D` after chezmoi replaced the links: **clean no-op** (nothing
  left to remove — stow is stateless and just finds no symlinks).

**Bonus reproduction:** the container reproduced Stow tree-folding (`.local`
became ONE symlink to `repo/my-bin/.local`) — the exact hazard the current
safety machinery exists to fight. chezmoi has no equivalent hazard class.

## U8 — `create_` existence management

- **`create_` source files must be NON-EMPTY.** An empty `create_` source
  silently never materializes (apply exits 0, no file, no error). The
  known_hosts seed must carry a comment line. This cost an hour of
  debugging — recorded here so it never costs another one.
- With a non-empty seed, all three designed behaviors confirmed:
  1. apply seeds the file when absent;
  2. external rewrites (ssh writing known_hosts) leave `chezmoi status` and
     `chezmoi diff` **quiet** — no drift noise (F11 closed);
  3. deletion → next apply recreates it WITH the seed (ssh's copy returns).
- Collateral trap found while debugging: a stale `entryState` record of
  `{'type': 'remove'}` (left by an earlier aborted apply) suppressed
  recreation. Fix: `chezmoi state delete-bucket --bucket=entryState`.
  Relevant only if an apply is ever interrupted mid-flight on a live host.

---

## Spike findings → plan corrections (S1–S4)

These are folded into design/02 and design/03; listed here as the canonical
record.

- **S1 (from U3/U7): `chezmoi add --follow` cannot import directory trees**
  — it refuses recursion on dirs, including tree-folded top-level symlinks.
  Phase 2 bulk import is **authoring** (copy content into `dot_`/
  `executable_` names) or per-file `add`; Phase 3 step 2a is reworded
  accordingly. This was already the contingency; the spike confirms it's
  the only path.
- **S2 (from U2/U8): authoring rules** — every template-referenced data key
  must exist in `.chezmoidata.toml` (`default` does not rescue missing
  keys); every `create_` source must be non-empty (seed comment).
- **S3 (from U4): the age `[age]` identity/recipient config must be
  generated by `.chezmoi.toml.tmpl`** (prompt or data-driven) because init
  re-renders the whole config and wipes manual edits.
- **S4 (from U5): `run_onchange_` hashes are not reset by
  `state delete-bucket --bucket=scriptState`** — force a re-run by touching
  script content. scriptState reset only affects `run_once_`.

## Limitations / not covered

- No Termux or macOS execution (U6 is paper + Linux-render only).
- The rehearsal farm is a miniature (3 units), not a 30-package import;
  Phase 2's container smoke test remains the full-scale gate.
- Interactive prompt flows were exercised via pty scripting, not a human
  user; first real init will be the true UX test.
- Sandbox artifacts live in `/tmp/chezmoi-spike` (gone on reboot) and one
  podman image (~200 MB) kept deliberately for the Phase 2 smoke test.

## Phase 1 exit criteria check

- [x] `design/05-spike-report.md` written (this file)
- [x] Unknown list U1–U8 closed — none re-scoped
- [x] D2 file-model split confirmed by execution (copies + `symlink_`
      file-shape + `create_` seeds all behave as designed)
- [x] Seq A chosen as Phase 3 default (Seq B documented as fallback)
- [x] ssh-overlay raw unstow invocation rehearsed and recorded (E1 closed)

**Next:** Phase 2 — build the real `home/` source tree (needs explicit
approval to write repo content).
