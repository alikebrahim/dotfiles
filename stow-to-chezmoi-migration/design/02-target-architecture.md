# Target Architecture — the chezmoi-based system

Design synthesis: how the new system is structured, how the current
mechanisms map into it, and the decisions that shape it. Decisions marked
"DECISION" are open for Ali; recommendations are given. The detailed decision
log with options and risks is `04-decisions-and-risks.md`.

---

## 1. Design principles (from research consensus)

1. **One repo, one source state, Syncthing stays the distribution channel.**
   The repo stays at `~/.dotfiles`; chezmoi's source state is scoped to a
   `home/` subdirectory via `.chezmoiroot`. Everything else in the repo
   (scripts, docs, tests, migration project) is inert to chezmoi.
2. **Copies by default, symlinks deliberately.** Regular files are the
   documented, community-consensus model (apps can't pollute the repo, files
   can be templated/encrypted/private). `symlink_` is used only where
   write-through actually matters (active desktop development, app-managed
   configs). — DECIDED D2-A (2026-08-17).
3. **Templates sparingly.** Only for genuine per-host/per-user variance:
   ssh config, tmux theme, git identity, ignore selection. Everything else
   stays a plain file. The 13-theme tmux library stays plain files; only the
   `theme.conf` selector is a template.
4. **Secrets encrypted, not plaintext.** age with per-user recipients;
   `create_` for `known_hosts` seeds. — DECIDED D4-A (2026-08-17).
5. **Scripts few, idempotent, self-verifying.** `run_once_*` for one-time
   provisioning, `run_onchange_*` for content-keyed installs, `run_after_*`
   for root-file delivery (sudo, `install -D` + `cmp` verify, as today).
   Never call chezmoi from inside a chezmoi script (state lock).
6. **Everything diffable, everything reversible via git.** `chezmoi diff`
   before every apply; commit before deploy on the authoring host.
7. **Agent rules unchanged.** No agent git operations; live deployment only
   with explicit user approval. AGENTS.md/.hermes.md get rewritten for the
   new model (user-owned step).

---

## 2. Repo layout

```
~/.dotfiles/                          <- git repo + Syncthing root (unchanged)
├── home/                             <- .chezmoiroot: chezmoi source state
│   ├── .chezmoiversion               <- minimum chezmoi version
│   ├── .chezmoiignore                <- template: per-host/user/OS selection
│   ├── .chezmoidata.toml             <- shared data (theme library, defaults)
│   ├── .chezmoi.toml.tmpl            <- first-init config generator (prompts)
│   ├── .chezmoitemplates/
│   │   └── ssh/
│   │       ├── netmaster.tmpl        <- per-host ssh config fragments
│   │       ├── servalws.tmpl
│   │       ├── minisforoum.tmpl
│   │       ├── macbook.tmpl
│   │       ├── honor.tmpl
│   │       └── zotac-box.tmpl        <- + per-user fragments or username blocks
│   ├── dot_zshrc  dot_zprofile  dot_p10k.zsh  dot_zsh/
│   ├── dot_bashrc  dot_bash_profile
│   ├── dot_gitconfig.tmpl            <- identity from data
│   ├── dot_vimrc
│   ├── dot_config/
│   │   ├── nvim/                     <- LazyVim tree (plain files)
│   │   ├── delta/  wezterm/  awesome/  quickshell/  picom/  flameshot/
│   │   ├── alacritty/  atuin/  posting/
│   │   └── git/1password-signing.gitconfig   <- if kept (D9)
│   ├── dot_tmux.conf
│   ├── dot_tmux/
│   │   ├── scripts/                  <- osc52-copy, status
│   │   ├── themes/                   <- the 13 .conf themes (plain files)
│   │   └── theme.conf.tmpl           <- renders {{ .tmuxTheme }}  (replaces 6 overlays)
│   ├── dot_local/bin/                <- my-bin scripts (executable_ or symlink_)
│   ├── dot_ssh/
│   │   ├── config.tmpl               <- dispatcher → include per-host fragment
│   │   ├── private_allowed_signers   <- or encrypted_
│   │   └── create_known_hosts.tmpl   <- seed if absent; ssh owns afterwards
│   ├── run_onchange_install-packages.sh.tmpl
│   ├── run_onchange_before_age-key-bootstrap.sh.tmpl  <- if passphrase pattern used (FAQ pattern; content-hash re-runs on rotation)
│   ├── run_after_system-modules-servalws.sh.tmpl    <- root files, sudo (D5)
│   ├── run_after_ensure-tmux-plugins.sh             <- or .chezmoiexternal (D7)
│   └── run_after_gnome-keyring-user-units.sh.tmpl   <- user services (D5)
├── scripts/                          <- retained repo tooling (outside source state)
│   ├── check-wm-servalws.sh          <- WM diagnostics (kept)
│   ├── system/  modules/             <- module assets until ported (D5)
│   └── ...configure-host.sh*         <- retired after Phase 4 (kept for reference)
├── docs/  tests/  ssh/  *-archived/  <- inert to chezmoi; retired/cleaned per D9
├── stow-to-chezmoi-migration/        <- this project (inert)
├── AGENTS.md  .hermes.md  .stfolder  .stignore  .gitignore
└── .stowrc*                          <- removed when stow retires
```

Notes:
- `home/` must be synced by Syncthing (it is the content). Nothing in
  `.stignore` currently excludes it; verify during the spike.
- chezmoi's own host-local state (`~/.config/chezmoi/chezmoi.toml`,
  `chezmoistate.boltdb`, age keys) lives outside the repo — nothing to
  exclude from sync.
- The old `ssh/<host>/` dirs and `tmux-remote-*` packages become inert; they
  are retired (or kept as reference) per D9 after all hosts migrate.
- `.chezmoiignore` patterns are **target-relative** — they match destination
  paths (e.g. `.config/awesome`, not `dot_config/awesome`). Author
  accordingly; check with `chezmoi ignored` after writing.
- Import files during Phase 2/3 with `chezmoi add --secrets=error` so
  secrets are caught at import time (free hygiene; gitleaks stays deferred
  per D4-A).

---

## 3. Data model (replaces `scripts/profiles/*.conf`)

| Current profile variable | New home | Example |
|---|---|---|
| `PROFILE_TMUX_OVERLAY` | per-machine config `[data]` | `tmuxTheme = "orange-gas-plasma"` |
| `PROFILE_SSH_OVERLAY` | per-machine config `[data]` + dispatcher | `sshFragment = "servalws"`; zotac: also `.chezmoi.username` |
| `PROFILE_TOOL_SET` | per-machine config `[data]` | `toolset = "desktop-full"` → run_onchange script branches |
| `PROFILE_UI_THEME` | per-machine config `[data]` | `gumTheme = "orange-gas-plasma"` (wrapper only) |
| `PROFILE_EXTRA_STOW_PACKAGES` | `.chezmoiignore` conditionals or data booleans | workstation → `dot_config/awesome`, `dot_config/quickshell`... |
| `PROFILE_MODULES` | data booleans / hostname conditions in scripts | `systemModules = true` on servalws |
| `PROFILE_ALLOWED_OS` | `.chezmoi.os` conditionals | install script branches fedora/ubuntu |
| `PROFILE_USER` (zotac) | built-in `.chezmoi.username` | per-user ssh fragment, per-user age key |

Where the value lives:
- **Shared defaults** (theme library, git user name, role presets) →
  `.chezmoidata.toml` in the repo.
- **Per-machine facts** (which machine this is, theme choice, toolset, ssh
  fragment) → `[data]` in `~/.config/chezmoi/chezmoi.toml`, generated on
  first init by `.chezmoi.toml.tmpl` using `promptStringOnce`/`promptBoolOnce`
  (only legal in config templates) — the rednafi/natelandau pattern.
- **Per-user facts** (zotac-box) → `.chezmoi.username` built-ins, plus the
  user's own config/state/age identity.

This collapses 7 profile files + a 31-entry catalog + validation code into
one small data file per machine and one ignore template.

---

## 4. Per-host / per-user modeling

### 4.1 ssh config (replaces `ssh/<host>/` overlays)

`dot_ssh/config.tmpl` dispatcher:
```gotemplate
{{ if eq .chezmoi.hostname "netmaster" }}{{ include "ssh/netmaster" . }}{{ end }}
{{ if eq .chezmoi.hostname "servalws" }}{{ include "ssh/servalws" . }}{{ end }}
...
{{ if and (eq .chezmoi.hostname "zotac-box") (eq .chezmoi.username "tima") }}
{{ include "ssh/zotac-box-tima" . }}{{ end }}
```
Per-host fragments stay in `.chezmoitemplates/ssh/` — same separation of
concerns as today's overlay dirs, but one target file and no stow.

`authorized_keys`: keep managed per host (template-selected fragments) or
`create_` seeds — spike decision; it is mostly read-only operational data.
`known_hosts`: `create_dot_ssh/known_hosts.tmpl` — seeded once, then ssh
owns it (fixes the temp+rename symlink-break problem permanently; no more
drift/apply loops).

### 4.2 tmux theme (replaces 6 overlay packages)

`dot_tmux/theme.conf.tmpl`:
```gotemplate
source-file "{{ .chezmoi.sourceDir }}/home/dot_tmux/themes/{{ .tmuxTheme }}.conf"
```
The 13-theme library stays as plain files; only the selector is data.

### 4.3 zotac-box dual user

- Same repo path for both users (existing shared-group symlink access keeps
  working; chezmoi `apply` only *reads* the source — no write access needed).
- Per-user: `~/.config/chezmoi/chezmoi.toml` (own `[data]`), own
  `chezmoistate.boltdb`, own age identity/recipient.
- Shared secrets: either a shared passphrase (age `passphrase = true`) or
  multiple recipients — spike to decide; docs warn against interactive
  1Password prompts on shared machines (`[onepassword] prompt = false`).
- tima's selection: `apps` only for tima → `.chezmoiignore` on
  `.chezmoi.username`, or data flag.

### 4.4 macbook / honor (today: no package flow at all)

chezmoi has official macOS and Termux builds — both hosts become first-class
with the same repo: common packages + their ssh fragments + their tmux theme.
macOS extras (brew installs, defaults) can be added later as
`run_onchange_*` scripts branching on `.chezmoi.os == "darwin"`. Out of scope
for v1 if Ali prefers.

---

## 5. Secrets (DECIDED D4-A, 2026-08-17: age, per-user recipients)

Recommended: **age, per-user recipients**.
- `encrypted_dot_ssh/config.tmpl`? — no: encryption applies to the *source
  file*; the dispatcher template itself contains no secrets (just hostnames),
  so the *fragments* are what need encryption. Fragments under
  `.chezmoitemplates/` cannot carry `encrypted_` (attributes apply to
  installed entries). Cleaner shape: put each host's `config` in
  `dot_ssh/config.<host>.tmpl` as an `encrypted_` entry selected by
  `.chezmoiignore`... this needs a spike to pick the exact shape. Fallback
  shape that definitely works: one `encrypted_dot_ssh/config.tmpl` whose
  plaintext (after age decrypt) is a Go template — attributes and `.tmpl`
  compose. Verify in spike (Phase 1, unknown U2). Fallback if composition
  disappoints (maintainer-confirmed, GitHub discussion #3713): keep the
  encrypted payload in a separate dot-ignored file and pull it into an
  ordinary template with `{{ "file" | include | decrypt }}`.
- `allowed_signers`: `private_` (0600) or encrypted — spike.
- Bootstrap: docs-endorsed pattern — commit a passphrase-encrypted
  `key.txt.age`, decrypt once via `run_onchange_before_` into
  `~/.config/chezmoi/key.txt`, point `[age] identity` at it; rotate via
  forget + add --encrypt. Requires one passphrase entry per new machine.
  (`run_onchange_`, not `run_once_`: the content hash guarantees the decrypt
  re-runs after key rotation — the official FAQ pattern.)
- `private_` everywhere `.ssh` perms matter; set `umask = 0o022` per docs.
- 1Password template functions: available but deferred (keeps `apply` free of
  `op` dependency; avoid the password-manager-fatigue failure mode from the
  research).
- Optional hardening: gitleaks pre-commit + `.secrets.baseline` if the repo
  ever goes public; not required while it stays private.

---

## 6. Scripts (replaces modules, tools, bootstrap, plugins)

| Current mechanism | New script | Trigger | Notes |
|---|---|---|---|
| `bootstrap` (stow/gum/flock prereqs) | none | — | chezmoi is the only prereq; `curl | sh` or dnf/brew/pkg |
| tools registry + sets | `run_onchange_install-packages.sh.tmpl` | content-hash (toolset value embedded → re-runs when toolset changes) | branches on `.chezmoi.os`; manual-hint tools stay manual (BLOCKED→echo hint) |
| `system:*` modules (ly, polkit, X11, battery) | `run_after_system-modules.sh.tmpl` (sudo, `install -D` + `cmp` verify; only when data/systemModules) | apply, onchange | servalws-only via hostname guard; keeps current idempotency + verify discipline |
| `user:gnome-keyring-units` | `run_after_...` (systemctl --user enable) or a `.config/systemd/user/` unit set | apply | trivial |
| `user:awesome-auth-startup` | verification-only: keep as a `run_after_` check or fold into docs | apply | it only greps rc.lua |
| `install-tmux-plugins.sh` | Option A: `run_after_ensure-tmux-plugins.sh` (port: `--ensure` semantics); Option B: `.chezmoiexternal` `git-repo` entries (v2.50+) with pins + refreshPeriod | apply (A) / refresh (B) | OPEN D7 — pending Ali's A-vs-B choice (see design/04 for the plain-English explanation); explicit `--update` command stays manual either way |
| `update tmux-plugins` | unchanged as an explicit manual command (kept out of apply, as today) | manual | preserves the "no surprise plugin updates" rule |
| runner + rollback | **none** — replaced by `chezmoi diff` review + git | — | optional tiny pre-apply snapshot script for `/etc` if Ali wants belt-and-braces |

Script rules (from docs + community): every script idempotent; `#!` via
`lookPath` where needed (Termux/macOS); no chezmoi calls inside scripts;
`run_before_*` must not touch source/destination state; empty rendered
content = script skipped (that is the per-machine off switch).

---

## 7. File model per package family (DECIDED D2-A — hybrid)

| Family | Model | Why |
|---|---|---|
| zsh, bash, git, vim, delta, nvim, picom, apps, posting, atuin, alacritty | **copies** (default) | static configs; no hot-edit need; keeps repo clean |
| wezterm, awesome, quickshell, awesome_wm_scripts | **`symlink_`** (recommended) | actively developed; editing repo file should be live (wezterm restart / awesome reload pick it up); QML/Lua trees are big — copies would double storage and slow applies |
| my-bin scripts | **`symlink_` or `executable_` copies** | `executable_` if copies (0755); `symlink_` preserves today's live-edit of scripts (Syncthing → live everywhere). Spike will confirm `symlink_` + exec-bit behavior |
| flameshot (app-writes-own-config) | **`symlink_`** (docs-recommended for externally-modified files) | app writes flow into repo instead of fighting apply prompts |
| tmux themes library | copies | static |
| `dot_ssh/*`, `dot_tmux/theme.conf`, `dot_gitconfig` | **templates** (⇒ copies) | per-host variance; cannot be symlinks |
| known_hosts | `create_` | ssh owns it after seeding |

The exact split is a spike deliverable (unknowns U1/U3). Authoring default in
Phase 2 is all-copies for a clean v1; the named `symlink_` trees (wezterm,
awesome, quickshell, awesome_wm_scripts) get their attribute flips via
`chezmoi chattr` at Phase-3 conversion (step 2b), not later — that is the
D2-A hybrid, and this paragraph describes its build order, not a different
model. Reversible either way.

---

## 8. Daily workflow after migration

Authoring (on any host):
```
edit ~/.dotfiles/home/...            # or: chezmoi edit ~/.config/wezterm/wezterm.lua
chezmoi apply                        # propagate to this host
# for symlink_ trees: edit is already live
# Syncthing carries the repo to other hosts; run chezmoi apply there
```
Safety habit (replaces runner/rollback):
```
chezmoi diff        # review
chezmoi apply
chezmoi verify      # read-only, exit-code checkable
```
New machine:
```
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply <repo>    # prompts once
```
Aliases (replaces the gum dashboard for daily use):
```
dot = chezmoi diff ; dot-apply = chezmoi apply ; dot-edit = chezmoi edit
chx = chezmoi add <file> && chezmoi edit <file>    # the anti-footgun wrapper
```

Standing rules:
- **Never run `chezmoi update` on this repo** — it does `git pull`;
  distribution is Syncthing (D1-A) and git is user-only. The daily command
  is `chezmoi apply`.
- Set `diff.exclude = ["scripts"]` in per-machine config so file diffs stay
  readable.

Optional later: a thin gum menu reusing the existing UI themes — DECIDED D8-A
(B optional later).

---

## 9. What stays in the repo outside `home/`

- `scripts/check-wm-servalws.sh` (WM diagnostics — product tooling, not
  deployment).
- `scripts/system/`, `scripts/modules/` assets until ported (D5); then
  consolidated under `home/`-adjacent `scripts/` or `.chezmoitemplates/`.
- `quickshell/docs`, `quickshell/tests` (product docs/tests — unchanged).
- `stow-to-chezmoi-migration/` (this project), `docs/` (rewritten operator
  manual), AGENTS.md/.hermes.md (rewritten deployment model — user-owned).
- Legacy surface per D9.

---

## 10. Explicit non-goals (v1)

- Switching distribution from Syncthing to git (D1; optional later).
- Moving the repo, making it public, or adding CI beyond a local smoke test.
- Full declarative `/etc` management (stays scripted via sudo).
- Porting the gum dashboard (D8).
- Managing `hermes` or other per-host binaries.
