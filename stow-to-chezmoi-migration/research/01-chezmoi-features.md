# chezmoi (v2.72.0) — Feature Deep-Dive for the Stow → chezmoi Migration

> Research report #1 of the stow-to-chezmoi migration. Everything below is grounded in the
> official chezmoi documentation at https://www.chezmoi.io/ (current release: **2.72.0**, per
> https://www.chezmoi.io/install/ and the homepage). Where the docs are silent, that is stated
> explicitly. No chezmoi code was run to produce this report; feature names and flags are taken
> verbatim from the reference.
>
> Note on URLs: the docs moved some pages; several paths in older articles 404. Verified paths
> are used throughout (e.g. `/user-guide/setup/` is the page formerly known as
> "manage-your-dotfiles"; `/user-guide/frequently-asked-questions/...` is the FAQ).

---

## 1. Core model: source state, target state, working tree

**What it is.** chezmoi computes a *target state* for the current machine from a *source state*
and then updates the *destination directory* to match. Official definitions (https://www.chezmoi.io/reference/concepts/):

| Term | Meaning |
|---|---|
| *source directory* | where the source state lives, `~/.local/share/chezmoi` by default; overridable via `-S`/`--source` flag or `sourceDir` config variable |
| *source state* | the declared desired state of your home directory; regular files + directories only, plus templates, scripts, externals |
| *target state* | the desired state of the destination directory, *computed* from source state + config file + destination state; may include symlinks, scripts to run, targets to remove |
| *destination directory* | what chezmoi manages, usually `~`; overridable via `-D`/`--destination` or `destDir` config |
| *destination state* | current on-disk state of all targets |
| *working tree* | the git working tree — normally identical to the source directory, but can be an ancestor (`-w`/`--working-tree`) |

**How it works.** The mapping between source state and target state is **1:1 and bidirectional**
(documented rationale in https://www.chezmoi.io/user-guide/frequently-asked-questions/design/ —
this is why source filenames carry attributes rather than a sidecar config file). Directories in
the source state map to directories in the destination; everything else is a file. Files whose
names begin with `.` in the source directory are ignored *unless* they are the special `.chezmoi*`
files (see §3). All changes are applied atomically per-file (temp file + rename; "you will never
be left with incomplete files" — https://www.chezmoi.io/what-does-chezmoi-do/).

**Per-file attributes** (https://www.chezmoi.io/reference/source-state-attributes/), encoded as
filename prefixes/suffixes. Prefix order matters and depends on target type (see the "Allowed
prefixes in order" table on that page):

- `dot_` — leading dot: `dot_zshrc` → `.zshrc` (also on directories, e.g. `dot_config/`)
- `private_` — strip group/world permissions (0600/0700)
- `readonly_` — remove write permissions (0444)
- `executable_` — add exec bits (0755)
- `symlink_` — create a symlink whose target is the file contents
- `encrypted_` — ciphertext in source, decrypted on demand; suffix `.age` (age) or `.asc` (gpg) is stripped
- `create_` — create the file only if absent (never overwrite; perms still enforced)
- `modify_` — contents are a script that transforms the existing file (stdin → stdout; see §5/§11)
- `remove_` — remove the target if it exists (or if empty, for directories)
- `empty_` — keep the file even if empty (by default empty files are removed)
- `exact_` (directories) — remove anything in the target dir not managed by chezmoi
- `external_` (directories) — stop attribute parsing in children (used for git submodules)
- `once_` / `onchange_` / `run_` / `before_` / `after_` — script scheduling (§5)
- `literal_` prefix / `.literal` suffix — stop attribute parsing (escape hatch for colliding names)
- `.tmpl` suffix — treat contents as a Go template (§2)
- Attributes can be changed with `chezmoi chattr` (e.g. `chezmoi chattr +template ~/.zshrc`) or by renaming.

**Relevance to our migration.** This model directly addresses our two biggest Stow hazards:
(1) **tree-folding of `~/.local`** — chezmoi manages directories natively, no folding, no
unfolding races; (2) **`stow -R` delete-then-create** — chezmoi computes a diff and only touches
what changed; removals are declarative (`remove_` prefix, `.chezmoiremove`, or `exact_`), never
"delete everything and rebuild". The 1:1 mapping also means one source file = one target file:
no package manifest to keep in sync (our `profiles/<host>.conf` package lists disappear — see §3, §7).

---

## 2. Templates and data

**What it is.** chezmoi templates are Go `text/template` extended with the full [sprig](http://masterminds.github.io/sprig/) function library
plus chezmoi's own functions (https://www.chezmoi.io/user-guide/templating/, https://www.chezmoi.io/reference/templates/functions/).

**How it works.**
- A source file is a template if it has a `.tmpl` suffix or lives in `.chezmoitemplates/`.
- **Template data precedence** (later wins): built-in `.chezmoi.*` variables → your
  `.chezmoidata.$FORMAT` files (`json`/`jsonc`/`toml`/`yaml`, read in alphabetical order) and
  `.chezmoidata/` directory files → the `data` section of the config file
  (`~/.config/chezmoi/chezmoi.toml` by default). A complete machine data dump is available via `chezmoi data`.
- **Built-in variables** (https://www.chezmoi.io/reference/templates/variables/): `.chezmoi.hostname`
  (up to first `.`), `.chezmoi.fqdnHostname`, `.chezmoi.os`, `.chezmoi.arch`, `.chezmoi.username`,
  `.chezmoi.homeDir`, `.chezmoi.uid`, `.chezmoi.gid`, `.chezmoi.group`, `.chezmoi.sourceDir`,
  `.chezmoi.sourceFile`, `.chezmoi.targetFile`, `.chezmoi.destDir`, `.chezmoi.config`,
  `.chezmoi.osRelease` (Linux), `.chezmoi.kernel` (Linux), `.chezmoi.windowsVersion`,
  `.chezmoi.version`, `.chezmoi.executable`, `.chezmoi.workingTree`, plus path/args/flags helpers.
- **Key template functions** (full list: https://www.chezmoi.io/reference/templates/functions/):
  `include` / `includeTemplate` (paste another source file's contents), `lookPath` (resolve an
  executable in `$PATH` — the documented way to write portable shebangs), `stat`, `onArch`/
  `onOs`/`onChange`, `promptString`/`promptBool`/`promptChoice`/`promptInt`/`promptMultichoice`
  (+ `*Once` variants, **only usable in config-file templates**, i.e. at `chezmoi init` time),
  `output`/`exec`, `readFile`, `writeToStdout`, `fromJson`/`fromYaml`/`fromToml`, `quote`,
  `joinPath`, `glob`, `sha256sum`, `ternary`, `urlJoin`, `walk`, `jq`, and the password-manager
  functions (§4).
- **Shared templates**: `.chezmoitemplates/<name>` files are included via `{{ template "<name>" . }}`;
  passing `.` carries the template data in. This is the documented pattern for "same contents,
  different locations on different machines" and for generating near-identical files (e.g. the
  alacritty example in the templating guide).
- **Tooling**: `chezmoi execute-template` (test snippets/whole files), `chezmoi cat`,
  `chezmoi data`, `chezmoi add --template` / `--autotemplate`, `chezmoi chattr +template`,
  `chezmoi edit` preserves `.tmpl` and checks syntax on exit.
- Empty template output ⇒ the target file is **removed** (use `empty_` if you want an empty file).
  Whitespace control is `{{-` / `-}}`; literal `{{` needs escaping (FAQ usage).
- `templateonly` is **not** an attribute in current chezmoi (the attribute table has no such
  entry); the modern equivalent of "a template used only by other templates" is a file in
  `.chezmoitemplates/` (never installed) or an `include`-ed file listed in `.chezmoiignore`.

**Relevance to our migration.** Templates + `.chezmoidata` + per-machine config `data` are the
direct replacement for our **per-host overlay files** (`scripts/profiles/<host>.conf` selecting
packages, `ssh/<host>/` overlays, `tmux-remote-<HOST>` overlays):

- `dot_ssh/config.tmpl` with `{{ if eq .chezmoi.hostname "zotac-box" }}...{{ end }}` blocks replaces `ssh/<host>/` overlay dirs.
- Per-machine values (email, git identity, monitor counts, user names) go in
  `.chezmoidata.toml` or the per-machine `[data]` config section, referenced as `.email`, etc.
- Completely different files per machine: `include` function (e.g. `.bashrc_linux` /
  `.bashrc_darwin` picked by `{{ if eq .chezmoi.os "linux" }}`), or per-machine `.chezmoiignore` (§3).
- Dual-user zotac-box: `.chezmoi.username` conditionals give each user their own file variants.
- **No need to keep a data file per host in the repo** — but the docs' data-precedence means the
  *config file* (`~/.config/chezmoi/chezmoi.toml`, not in the repo) is the per-machine knob.

---

## 3. Ignore / include / root / version

(https://www.chezmoi.io/reference/special-files/, evaluated in this order)

- **`.chezmoiignore{,.tmpl}`** (https://www.chezmoi.io/reference/special-files/chezmoiignore/):
  glob patterns (**doublestar**) matched against the *target path*; `!` prefix re-includes; `#`
  comments; **always interpreted as a template** regardless of suffix, so you can write
  `{{ if ne .chezmoi.hostname "work-laptop" }}dot_work{{ end }}` — the docs stress the inverted
  logic: "chezmoi installs everything by default, so ignore unless host…". Subdirectory
  `.chezmoiignore` files scope to that subtree. `chezmoi ignored` lists the result.
- **`.chezmoiremove{,.tmpl}`** (https://www.chezmoi.io/reference/special-files/chezmoiremove/):
  patterns of targets to *remove* during apply (template, per-machine). Negative matches and
  ignored targets are never removed. Docs warn it is "potentially dangerous" — dry-run with
  `-n -v` first.
- **`.chezmoiroot`** (https://www.chezmoi.io/reference/special-files/chezmoiroot/): read *first*;
  relocates the source-state root to a subdirectory of the repo (e.g. `home/`), so a repo can
  hold chezmoi files plus anything else. All other special files must move into the new root.
  Also the documented answer to "too many entries at the source root" (FAQ design) and the
  enabler for keeping the repo at `~/.dotfiles` with chezmoi state in a subdir.
- **`.chezmoiversion`**: minimum chezmoi version required, checked before any operation.
- **`.chezmoi.$FORMAT.tmpl`**: config-file template used by `chezmoi init` / `--init` to generate
  `~/.config/chezmoi/chezmoi.toml` on new machines (with `promptStringOnce` for interactive
  first-run values). See §8.
- **`.chezmoiexternal.$FORMAT` / `.chezmoiexternals/`**: external content (§6).

**Relevance to our migration.** `.chezmoiignore` (as a template) is the primary mechanism that
replaces **package selection** from `scripts/profiles/<host>.conf`: instead of "install package X
on host Y", you keep all ~33 packages' files in the tree and ignore the ones that don't apply on
the current machine, keyed on `.chezmoi.hostname` / `.chezmoi.os`. `chezmoi ignored` gives a
checkable inventory, replacing our per-host package listing tooling.

---

## 4. Secrets

**What it is.** Two complementary mechanisms: (a) **encryption at rest** in the repo, (b)
**password-manager integration** at apply time. (https://www.chezmoi.io/user-guide/encryption/)

**Encryption at rest.** `encrypted_` prefix; source files hold ASCII-armored ciphertext (`.age` /
`.asc` suffix stripped); `chezmoi add --encrypt` to add, `chezmoi edit` decrypts/re-encrypts
transparently, `chezmoi encrypt`/`decrypt`/`age`/`age-keygen` commands. Backends:

- **age** (https://www.chezmoi.io/user-guide/encryption/age/): config
  `encryption = "age"`, `[age] identity = <private key>`, `recipient = <public key>`; supports
  multiple identities/recipients; symmetric mode (`symmetric = true`, e.g. an SSH key as
  identity) and passphrase mode (`passphrase = true`, prompted per operation). **Builtin age**
  (used automatically when `age` isn't in `$PATH`, controllable via `--use-builtin-age`) does
  **not** support passphrases, symmetric encryption, or SSH keys.
- **gpg**: `encryption = "gpg"`, `[gpg] recipient` (https://www.chezmoi.io/user-guide/encryption/gpg/).
- **git-crypt** and **transcrypt** are listed as supported backends on the encryption page
  (repo-level encryption via git filters, rather than per-file chezmoi encryption).
- FAQ encryption's recommended first-init-only passphrase pattern: commit a
  passphrase-encrypted `key.txt.age` (ignored via `.chezmoiignore`), decrypt it into
  `~/.config/chezmoi/key.txt` via a `run_onchange_before_decrypt-private-key.sh.tmpl` on first
  init, point `[age] identity` at it. Rotation: `chezmoi forget`/`unmanage` + `chezmoi add --encrypt`.

**Password-manager integration** (https://www.chezmoi.io/user-guide/password-managers/): `chezmoi secret`
command plus template functions for 1Password (`onepassword`, `onepasswordRead`,
`onepasswordDocument`, `onepasswordDetailsFields`, `onepasswordItemFields`), Bitwarden
(`bitwarden`, `bitwardenSecretsManager`), LastPass, KeePassXC, `pass`, Vault, Keeper, Dashlane,
Doppler, gopass, ejson, Proton Pass, passhole, AWS Secrets Manager, Azure Key Vault,
Keychain/Windows Credentials Manager, and **generic** `secret`/`secretJSON` (arbitrary command
wrappers). 1Password specifics (https://www.chezmoi.io/user-guide/password-managers/1password/):
works via the `op` CLI; interactive sign-in prompt unless `[onepassword] prompt = false`;
headless modes `[onepassword] mode = "connect"` (Connect server) or `"service"` (Service
Accounts); docs **warn: do not use the interactive prompt on shared machines** — the session
token is passed on the command line, visible to other users. `--skip-secrets` global flag skips
all templates containing secrets.

**Tradeoffs (from the docs).** age: simple, per-machine keys, builtin support, no key server;
gpg: ubiquitous, but key management ceremony; git-crypt/transcrypt: transparent at rest but
whole-repo and dependent on git tooling; password managers: zero secrets at rest in the repo
(public-repo safe) but require CLI + unlocked vault/network at apply time. The docs' overall
stance: chezmoi is designed so the dotfiles repo *can be public* — store secrets either in a
password manager or in encrypted files (setup page, "Use a private repo").

**Relevance to our migration.**
- Today SSH configs sit **unencrypted** in the repo. Minimum viable fix: `encrypted_` + age with
  a per-machine identity. Docs-endorsed pattern = passphrase-protected `key.txt.age` in repo.
- 1Password is already in use (git signing); `onepassword*` functions can inject signing-relevant
  config or SSH keys into templates, and `[onepassword] mode` handles headless machines.
- **zotac-box dual user**: encryption is configured per machine (each user's `chezmoi.toml` has
  their own `[age] identity/recipient`), so per-user files (e.g. `dot_ssh/config.tmpl` variants
  keyed on `.chezmoi.username`) can be encrypted to the respective user's recipient; shared
  secrets need either a shared passphrase (`age.passphrase = true`) or multiple recipients.
  The 1Password interactive-prompt warning is directly relevant — keep `prompt = false` and use
  Service Account/Connect tokens on shared hosts.

---

## 5. Scripts

**What it is.** Files with `run_` prefix are scripts executed during `chezmoi apply`/`update`/
`init --apply` (https://www.chezmoi.io/user-guide/use-scripts-to-perform-actions/,
https://www.chezmoi.io/reference/source-state-attributes/). Scripts are the escape hatch:
"Scripts break chezmoi's declarative approach and should be used sparingly. All scripts should
be idempotent."

**How it works.**
- **Types** (combine with `before_`/`after_`): `run_` (every apply), `run_once_` (once per
  unique content — SHA256 of the rendered content is stored; a template change re-runs it; runs
  even under a different filename if content matches), `run_onchange_` (only when content
  changed since last *successful* run). `run_once_before_...`, `run_onchange_after_...`, etc.
  are valid. There is **no `run_oncreate_`** in current chezmoi (not in the attribute table).
- **Order**: `run_before_*` scripts in alphabetical order → target entries (incl. remaining
  scripts) in alphabetical order of target name (directories before their contents) →
  `run_after_*` scripts in alphabetical order (https://www.chezmoi.io/reference/application-order/).
  Caveats from the same page: `run_before_` scripts must not mutate source/destination state
  (undefined behavior); externals are refreshed during the update phase, so `run_before_` must
  not depend on them; `run_after_` may.
- **Execution**: no executable bit needed in source; if the script is a template (`.tmpl`), the
  rendered result is executed; **empty rendered content ⇒ script skipped** (per-machine
  disabling); the script is written to a temp file (exec bit set) and run via `exec(3)`, so it
  needs a `#!` line or be a binary; cwd = first existing parent dir in the destination tree;
  env includes `CHEZMOI=1`, `CHEZMOI_OS`, `CHEZMOI_ARCH`, plus anything in `[scriptEnv]`.
  Scripts in `.chezmoiscripts/` run the same way but are **not** installed as target files.
- **Visibility**: dry-run (`-n`) never executes scripts; verbose prints their contents;
  `chezmoi diff`/`status` show pending scripts (`R`) — suppress via `[diff] exclude =
  ["scripts"]` / `[status] exclude`.
- **State**: run hashes live in the persistent state database
  (`chezmoistate.boltdb` next to the config file; `scriptState` bucket for `run_once_`,
  `entryState` for `run_onchange_`); clearing is documented ("Clear the state of all
  run_onchange_ and run_once_ scripts") via the `state` command — maintainer-recommended
  invocation `chezmoi state delete-bucket --bucket=scriptState` (GitHub discussion #1678).
- **Known pitfalls** (FAQ troubleshooting): newline before `#!` in a template script breaks
  exec (`{{-` fix); `noexec` tmpdirs break scripts (`scriptTempDir` config); hardcoded
  `/bin/bash` breaks on Nix/Termux (use `#!{{ lookPath "bash" }}`); a `run_` script that itself
  invokes chezmoi deadlocks on the persistent-state lock (§9).
- **Periodic runs**: documented pattern = `run_onchange_*.tmpl` embedding the current
  date/week — "How do I run a script periodically?" (FAQ usage).
- Script stdin: **no documented stdin-script mechanism**; the documented ways to feed scripts
  data are templates, `scriptEnv`, and the secret functions.

**Relevance to our migration.** This is the chezmoi equivalent of our **bootstrap + system/user
modules + tools registry**:
- one-time provisioning → `run_once_before_` (e.g. package manager setup, age key bootstrap);
- tools registry → `run_onchange_install-packages.sh` (content-hash means adding a tool to the
  script re-runs it) or `run_onchange_` templates with `onArch`/`lookPath` guards;
- systemd units / polkit / X11 root-owned files → can't be managed as files by a user-level
  chezmoi; put the *unit files* under `~/.config/systemd/user/` where possible, and use
  `run_after_` scripts (with `sudo`) for `systemctl daemon-reload`/`enable` and
  `install -D`-style root installs. FAQ design confirms: scripts execute as the invoking user;
  add `sudo` yourself; managing outside `$HOME` is possible via scripts but "strongly
  discouraged" as a general pattern.
- Our runner's rollback manifests have **no chezmoi counterpart** (see §9).

---

## 6. Importing external content

**What it is.** Declarative fetching of files/archives/git repos into the source state
(https://www.chezmoi.io/user-guide/include-files-from-elsewhere/,
https://www.chezmoi.io/reference/special-files/chezmoiexternal-format/), plus one-shot
`chezmoi import`.

**How it works.**
- `.chezmoiexternal.$FORMAT` (or `.chezmoiexternals/` dir, read lexically) is a template itself
  (per-machine externals). Entries are keyed by target path; fields: `type` (`file`, `archive`,
  `archive-file`, `git-repo`), `url`/`urls`, `refreshPeriod` (0 = never re-download unless
  `-R`/`--refresh-externals`), `checksum.sha256/384/512/size`, `exact`, `private`, `readonly`,
  `executable`, `encrypted`, `include`/`exclude` (archive member patterns), `stripComponents`,
  `format` (tar, tar.gz, tgz, tar.bz2, tbz2, xz, tar.zst, zip), `decompress`, `filter.command`,
  `targetPath`, `clone.args`/`pull.args`, `archive.extractAppleDouble`.
- `archive` + `exact = true`: apply removes anything in that target dir not present in the
  archive — the "keep in sync with upstream" pattern. `archive-file` extracts one member.
- `git-repo`: `git clone`/`git pull` into the target dir. Docs warnings: needs a `git` binary;
  the dir is managed entirely by git — chezmoi cannot manage other files inside it; contents are
  **not** manifested in `chezmoi diff`/`dump` and show up in `chezmoi unmanaged`. (git-repo type
  was *added* in v2.50.0; it is current in 2.72.)
- One-shot: `chezmoi import --strip-components=N --destination ~/...` brings an archive into the
  source state; `--exact` for dirs; for migration from symlink-based managers,
  `chezmoi add --follow ~/.bashrc` imports the *target* of a symlink (i.e. Stow-managed files)
  as regular files (https://www.chezmoi.io/migrating-from-another-dotfile-manager/).
- Git submodules in the source dir: mark the directory `external_` so chezmoi doesn't recurse.
- If an external's parent dir is ignored via `.chezmoiignore`, its entries are ignored too.
- Known gotcha (FAQ troubleshooting): `chezmoi add` into a path that only exists as an external
  fails until you create the dir + `.keep` file in the source state.

**Relevance to our migration.** **tmux TPM plugins** and **Neovim/Vim plugins** are the named
use cases in the docs ("importing files from archives (great for shell and editor plugins)").
Two options: let the plugin managers do their own thing (TPM's git-based install,
lazy.nvim/plug) via a `run_after_` script — simplest and keeps plugin state out of chezmoi; or
pin/refresh them declaratively with `archive`/`git-repo` externals (docs examples include
`.oh-my-zsh`, vim-plug, powerlevel10k). Given our catalog includes oh-my-zsh-style shell
frameworks and TPM, externals with `exact = true` + `refreshPeriod` give us versioned, drift-free
plugin trees without bundling them in git.

---

## 7. Multi-machine workflows

**What it is.** The per-machine model: one repo, per-machine config + data, and a small command
set. (https://www.chezmoi.io/user-guide/setup/, https://www.chezmoi.io/user-guide/command-overview/,
https://www.chezmoi.io/user-guide/manage-machine-to-machine-differences/)

**How it works.**
- **Per-machine config**: `~/.config/chezmoi/chezmoi.toml` (also yaml/json/jsonc) holds
  machine-specific settings and a `[data]` section with per-machine template variables
  (docs recommend `0600` if private data goes there). The repo can ship a
  `.chezmoi.$FORMAT.tmpl` that *generates* this config on first init (with `promptStringOnce`
  etc.). On shared hosts each **user** has their own config + their own persistent state.
- **Adding a machine**: install chezmoi → `chezmoi init <repo>` (clones into the source dir,
  guesses GitHub URLs, `--ssh` for SSH URLs) → `chezmoi diff` → `chezmoi apply`; or one shot:
  `chezmoi init --apply <repo>`. Update an existing machine: `chezmoi update` = `git pull
  --autostash --rebase` + `chezmoi apply` (https://www.chezmoi.io/user-guide/daily-operations/,
  https://www.chezmoi.io/reference/commands/update/).
- **Editing**: `chezmoi edit $FILE` (source file in your editor; `--apply` on quit; `--watch`
  on save), `chezmoi cd` (subshell in source dir), direct edits + `chezmoi re-add` (doesn't
  work with templates), or `chezmoi merge`/`merge-all` (3-way merge tool when both source and
  destination changed). Bare edits to a target file are detected: `chezmoi apply` prompts
  before overwriting a file modified since chezmoi last wrote it.
- **Removal bookkeeping**: `chezmoi forget`/`unmanage` (stop managing, keep the file),
  `chezmoi remove`/`rm` (also delete the target), `chezmoi destroy` (source + target),
  `chezmoi managed` / `unmanaged` / `list` / `ignored` for inventory.
- **Symlink vs copy — the live-edit question**: by default chezmoi writes **regular files**;
  `symlink_` attribute (or global `--mode=symlink`) makes a target a symlink to a file in the
  source dir. FAQ design: symlinks are first-class but only "where you really need one"; the
  Stow advantage (edits to the central file are immediately live) is replicated with
  `chezmoi edit --watch` or `edit.watch = true`; symlink mode can't represent encrypted,
  executable, private, or templated files, and cannot symlink entire directories. The docs'
  recommended workflow is regular files + `chezmoi edit`/`re-add`. A documented middle ground
  for externally-modified files (e.g. VSCode settings): `symlink_` back to the source file
  (https://www.chezmoi.io/user-guide/manage-different-types-of-file/).
- **exact_ for dirs**: `exact_dot_config/foo` prunes unmanaged files in `~/.config/foo`;
  `chezmoi re-add` on exact dirs statefully syncs (deleted target files removed from source,
  new ones added — documented on the `add` reference page).

**Relevance to our migration.** `init --apply` + `update` replace our bootstrap/runner flows;
`.chezmoi.$FORMAT.tmpl` replaces per-host config scaffolding; `merge` covers the
"edited live file AND changed repo" conflict our symlink setup silently resolves in one
direction. Critical decision: **keep the current live-symlink behavior** (map every Stow
symlink to `symlink_` files — preserves "edit live file = edit repo source", which our team
relies on) **or switch to regular files + `re-add`/`edit --apply`** (the docs-recommended path;
safer with templates/encryption, but changes the edit workflow). Both are supported; the choice
should be explicit in the migration plan.

---

## 8. Bootstrapping a new machine

**What it is.** chezmoi is a single statically-linked binary, no dependencies, **no root
required**, runs on Linux/macOS/Windows/FreeBSD/OpenBSD/Android-Temux (homepage; https://www.chezmoi.io/install/).

**How it works.**
- **Install**: `sh -c "$(curl -fsLS get.chezmoi.io)"` (defaults to `./bin`, `-b` to choose a dir,
  `https://get.chezmoi.io/lb` → `~/.local/bin`); PowerShell `iex "&{$(irm 'https://get.chezmoi.io/ps1')}"`;
  every major package manager (apt, dnf, pacman/paru, brew, nix, scoop, winget, choco, snap…,
  see repology.org/project/chezmoi); prebuilt .deb/.rpm/.apk/.msix/archives; `go install`;
  checksums are cosign-signed and verifiable.
- **One-command new machine** (https://www.chezmoi.io/user-guide/daily-operations/):
  `sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply $GITHUB_USERNAME` — installs chezmoi,
  clones the repo (guessing `github.com/<user>/dotfiles`), generates the config from
  `.chezmoi.$FORMAT.tmpl` (interactive prompts on first run only), and applies everything.
  Private repos: `--ssh`, or git credentials as usual.
- **`chezmoi init`** reference (https://www.chezmoi.io/reference/commands/init/): `--apply`,
  `--branch/--tag/--revision`, `--depth`, `--ssh`, `--one-shot` (= apply + purge + purge-binary
  — for containers), `--purge`, `--prompt*` pairs for non-interactive seeding, `-C` config path.
  Non-git VCS: supported via `update.command` etc.; an empty `.git` dir marks the source dir
  (https://www.chezmoi.io/user-guide/advanced/customize-your-source-directory/).
- Our machines include macOS + Android (Termux build exists) — both covered.

**Relevance to our migration.** Replaces our bootstrap command almost 1:1:
`sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply <repo>` per host, with `run_once_before_`
scripts taking over the provisioning steps our bootstrap performs, and `chezmoi doctor` (§9)
replacing our doctor. What we lose: the runner's rollback manifests and its structured
provisioning log — no chezmoi equivalent exists (see §9/§11).

---

## 9. Operational concerns: doctor, diff, locking, exit codes, rollback, update

- **`chezmoi doctor`** (https://www.chezmoi.io/reference/commands/doctor/): checks version,
  os/arch, uname, go version, executable, config file, source dir (git working tree clean/dirty),
  suspicious entries, dest dir, umask, and presence/version of `cd`, `diff`, `edit`, `git`,
  `merge`, `shell`, `age`, `gpg`, `pinentry`, and all password-manager CLIs (`ok`/`warning`/
  `info`/`error`; `--no-network` flag). First thing to run on a new machine (command overview).
- **Preview/safety**: `chezmoi diff` (unified diff; color + pager; external diff command
  configurable), `chezmoi status` (summary), `chezmoi verify` (read-only; exits 0 if all
  targets match, 1 otherwise — the only documented exit-code contract), `-n/--dry-run` +
  `-v/--verbose` (changes printed as approximate shell commands), `--force`,
  `--interactive`/`--less-interactive`, `-k/--keep-going`, `--skip-secrets`, `--refresh-externals`.
- **Locking**: chezmoi serializes via a bbolt lock on the persistent state
  (`~/.config/chezmoi/chezmoistate.boltdb`); write lock: `add`, `apply`, `edit`, `forget`,
  `import`, `init`, `state`, `unmanage`, `update`; read lock: `diff`, `status`, `verify`.
  Concurrent invocations (e.g. a `run_` script calling chezmoi) yield
  "timeout obtaining persistent state lock" (FAQ troubleshooting).
- **Exit codes**: only `verify` documents 0/1 semantics; the docs otherwise do not publish a
  stable exit-code table (standard Unix 0/≠0 is the working assumption).
- **Backups / rollback: there is none.** Verified by absence in the reference: no backup
  command, no `--backup` flag on `apply`, no rollback concept in the docs. The documented
  safety model is: git history of the source state + `chezmoi diff`/dry-run before applying +
  prompts before overwriting locally-modified targets + atomic per-file writes. Our runner's
  rollback manifests have no equivalent; replace them with pre-apply diff review (a
  `run_after_` snapshot script would be our invention, not a chezmoi feature).
- **Update flow**: `chezmoi update` = pull (`--autostash --rebase`, `--apply=false` to pull
  only, `--init`) + apply; optional `[git] autoCommit`/`autoPush` with
  `commitMessageTemplate` (autoPush on a public repo can leak secrets). Periodic automation:
  no dedicated cron page; documented patterns are cron/systemd-timer calling `chezmoi update`
  (FAQ usage), time-based `run_onchange_` scripts, and an advanced Watchman page
  (https://www.chezmoi.io/user-guide/advanced/use-chezmoi-with-watchman/). `chezmoi upgrade`
  self-updates where the install method supports it.
- **Concurrency between machines**: nothing built-in beyond git; per-machine state (script
  hashes, etc.) is local, so machines drift until `chezmoi update`; cross-machine conflicts are
  ordinary git conflicts, resolved via `chezmoi merge`-style workflows or per-machine data.

**Relevance to our migration.** `doctor` replaces our doctor; `diff -n -v` + prompts replace
the runner's rollback manifests (weaker, but the standard chezmoi way); `update` replaces
per-host pull scripts; `verify` gives us a CI-able check; the bbolt lock explains why
nested chezmoi calls (e.g. in scripts) must be avoided.

---

## 10. Comparison table (chezmoi vs others, incl. Stow)

The official table (https://www.chezmoi.io/comparison-table/) compares chezmoi against
**dotbot, rcm, vcsh, yadm, and bare git** — GNU Stow is *not* a column. Notable claims:

| Capability | chezmoi | dotbot | rcm | vcsh | yadm | bare git |
|---|---|---|---|---|---|---|
| Distribution | Single binary | Python pkg | Multiple files | Script/pkg | Script | – |
| Bootstrap requirements | **None** | Python, git | Bash | sh, git | git | git |
| Windows support | ✅ | ✅ | ❌ | ❌ | ✅ | ✅ |
| dotfiles are… | **Files** | Symlinks | Symlinks | Files | Files | Files |
| Private files | ✅ | ❌ | ❌ | ❌ | ✅ | ❌ |
| Whole-file encryption | ✅ | ❌ | ❌ | ❌ | ✅ | ❌ |
| Password manager integration | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ |
| Machine-to-machine differences | **Templates** | Alt. files | Alt. files | Branches | Alt. files + templates | ⁉️ |
| Custom template variables | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ |
| Externals | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ |
| File removal | ✅ | ❌ | ❌ | ✅ | ✅ | ❌ |
| Run-once scripts | ✅ | ❌ | ❌ | ✅ | ✅ | ❌ |
| Archive import/export | ✅ | ❌ | ❌ | ✅ | ❌ | ✅ |
| Show diffs without applying | ✅ | ❌ | ❌ | ✅ | ✅ | ✅ |

**Stow-specific discussion** (FAQ design, "Why doesn't chezmoi use symlinks like GNU Stow?"):
Stow-style managers use symlinks as an indirection layer between a dotfile's location and its
content in a central directory; chezmoi instead generates regular files from the central
source. chezmoi's symlinks are first-class (create/update/remove/templated targets) but used
only where needed, because symlinks *cannot* represent encrypted, executable, private, or
templated files, nor entire managed directories. The docs concede exactly one Stow advantage —
edits to the central file are immediately visible — and answer it with `chezmoi edit --watch` /
`edit.watch`. A `--mode=symlink` global mode exists to "work like GNU Stow", but the docs call
it manual/experimental (issue #167). **Migrating from a symlink-based manager** is documented:
`chezmoi add --follow` converts Stow-style symlinks into managed regular files
(https://www.chezmoi.io/migrating-from-another-dotfile-manager/).

---

## 11. Limitations and gotchas

- **No package concept.** Source entries map 1:1 to targets; there are no named "packages" like
  our 33 Stow packages. Emulation is per-machine `.chezmoiignore` + templates (§3) and/or
  `apply --include/--exclude` by entry type (`files`, `dirs`, `symlinks`, `scripts`,
  `encrypted`, `externals`).
- **Outside `$HOME` / root-owned files**: managing files outside the home dir is possible via
  scripts (with `sudo`) or `destDir`, but the docs *strongly discourage* it and point to
  Ansible/Chef/Puppet/Salt for system config. Our root-owned `/etc` files, polkit rules, and
  systemd units must be scripted (or moved to user-scope equivalents), not declared as files.
- **Symlink mode limitations**: no symlinks for encrypted/executable/private/templated files,
  no symlinked directories; `chezmoi add` in symlink mode needs an `apply` to materialize.
  A `symlink_` file whose target is a directory is not recursed/managed.
- **exact_ is destructive by design**: it deletes unmanaged entries in the target dir on
  `apply` (that's the point), and `re-add` statefully syncs exact dirs both ways — review
  `diff` before enabling on `~/.local`-style shared dirs. `.chezmoiremove` is similarly
  powerful; docs prescribe dry-run first.
- **Large trees / flat source root**: the 1:1 mapping puts all home-root files at the source
  root (mitigated by `.chezmoiroot`); chezmoi reads source/destination lazily and assumes
  neither changes mid-run (perf model, application-order page). It is not a config-management
  system and is not optimized for huge trees of machine-generated content.
- **Concurrency**: bbolt lock serializes chezmoi instances per user; a script that calls
  chezmoi deadlocks/timeouts (§9). Multi-machine concurrency is plain git — no distributed
  state.
- **Templates**: empty rendered output deletes the target (use `empty_`); `re-add` doesn't
  work on templates; modify-templates must not carry `.tmpl`; `{{`/`}}` need escaping;
  `prompt*` only in config templates; a leading newline before `#!` breaks template scripts.
- **Environment gotchas** (FAQ troubleshooting): `umask` (group-writable files, e.g.
  `~/.ssh/config` — set `umask = 0o022`); `noexec` tmpdir (set `scriptTempDir`); snap's
  /dev/stdin bug; musl binary + LDAP user lookup failure; Nix/Termux missing `/bin/bash`
  (use `lookPath`); `chezmoi edit` needs a foreground editor (`vim -f` / `code --wait`).
- **Encryption**: builtin age lacks passphrase/symmetric/SSH-key support; passphrase prompts
  fire on every decrypt-needing command (`apply`, `diff`, `status`).
- **No backups/rollback** (§9) — plan around it.
- **Windows**: supported but with caveats — symlinks need privilege/dev-mode, attributes like
  `executable_` have no direct equivalent, `.chezmoi.pathSeparator`/`windowsVersion` exist for
  templates; not a concern for our Linux/macOS/Android fleet beyond knowing it's there.
- **Multiple source states**: explicitly not supported (FAQ design) — one repo, one source
  state; per-machine differences live in templates/config, not in separate trees.

---

## 12. Migration lens (Stow + custom orchestrator → chezmoi)

| Current mechanism | chezmoi replacement | Notes |
|---|---|---|
| Stow packages (~33 dirs) | Flat source tree; per-host `.chezmoiignore` template lines; `.chezmoiroot` subdir if we want a `home/` namespace | No package abstraction exists; ignore-lists keyed on `.chezmoi.hostname`/`.chezmoi.os` |
| `scripts/profiles/<host>.conf` (package selection) | `.chezmoiignore` template + per-machine `[data]` + `.chezmoi.$FORMAT.tmpl` config generation | `chezmoi ignored` lists the effective selection |
| `ssh/<host>/` overlays | `dot_ssh/config.tmpl` conditionals; per-machine data variables | Per-user variants (zotac-box) via `.chezmoi.username` |
| zotac-box per-user subpackages | Templates on `.chezmoi.username`; per-user config/state; per-user age identities/recipients | 1Password interactive prompt must stay off on shared hosts |
| system modules (root `/etc`, polkit, systemd, X11 `install -D`) | `run_after_`/`run_once_` scripts with `sudo`; user-scope units under `~/.config/systemd/user/` | No declarative root-file support — bigges loss vs Stow-era `install -D` |
| tools registry | `run_onchange_install-packages.sh` (+ `onArch`/`lookPath` guards) or archive-file externals | Content-hash re-runs when the list changes |
| bootstrap command | `sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply <repo>` + `run_once_before_*` | One command per machine; `--one-shot` for ephemeral hosts |
| runner + rollback manifests | **No equivalent** — `chezmoi diff -n -v` review + prompts + git history instead | Plan an explicit pre-apply diff habit |
| doctor | `chezmoi doctor` | Superset of our checks |
| live symlinks (edit live = edit repo) | Option A: `symlink_` files (preserve behavior); Option B (docs-preferred): regular files + `chezmoi edit --apply`/`re-add` | Option B enables templates/encryption for those files |
| Stow tree-folding / `stow -R` failure mode | Native directory management; diff-based apply; `.chezmoiremove`/`remove_`/`exact_` for deletions | Root cause of our worst hazards disappears |
| unencrypted SSH configs in repo | `encrypted_` + age (per-machine identity; passphrase-protected `key.txt.age` in repo) or 1Password functions | Docs are explicit that the repo *can* be public afterwards |
| 1Password git signing | Unchanged (external); chezmoi templates inject non-secret config only | `onepassword*` functions available if needed |

**Things with no chezmoi equivalent (plan around them):** rollback manifests/transactional
apply; a named package catalog; declarative root-owned file installation; per-host overlay
directories as a concept (replaced by templates); Stow's immediate-live-edit property (replaced
by `edit --watch`).

**Repo-layout decision for the plan:** keep the git repo at `~/.dotfiles` and either set
`sourceDir` to it in each machine's config, or use `.chezmoiroot` to scope the source state to
a subdirectory (e.g. `~/.dotfiles/home/`) — the latter keeps the repo clean for migration
artifacts (this `research/` dir, plans) and non-chezmoi content. `chezmoi init` normally clones
into `~/.local/share/chezmoi`; using the existing repo means running `chezmoi init` against a
local path or initializing the source dir manually — verify exact flags during the migration
spike. First concrete migration step, per the official guide: `stow -D` (unstow) then
`chezmoi add --follow` per managed file to convert symlinks into managed regular files.
