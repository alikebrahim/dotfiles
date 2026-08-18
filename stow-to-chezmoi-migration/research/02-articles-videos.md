# Annotated Bibliography: Chezmoi Articles, Videos, Podcasts, Repos & Comparisons

*Research for migrating a GNU Stow + custom-orchestrator dotfiles repo to chezmoi.*
*All URLs were verified on 2026-08-15 via web extraction/search. Entries marked "hub-listed" come from the official chezmoi.io link hubs (https://www.chezmoi.io/links/...), which the project itself curates; entries marked "search-verified" were confirmed via search-engine results where the target site blocks automated fetching (Reddit).*

---

## 1. Articles (15)

### 1.1 The definitive Stow-to-chezmoi migration post
- **Title:** Migrating from GNU stow to chezmoi
- **Author:** Redowan Delowar
- **URL:** https://rednafi.com/misc/chezmoi
- **Date:** 2026-06-12
- **Takeaways:**
  - Written by someone who ran Stow across 3 Macs for years; explains exactly *why* Stow breaks down multi-machine: symlink write-through leaves dirty, conflicting working trees on every clone, and `stow` refuses to link over pre-existing files (`.zprofile`, `.gitconfig` created by Homebrew) on fresh machines.
  - His replacement workflow: `brew install chezmoi` then `chezmoi init --apply --promptString machineName=mini https://github.com/rednafi/dotfiles.git` — two commands bootstrap a machine, with `run_onchange_*` scripts installing Homebrew packages and setting macOS defaults.
  - Clever trick: a template embeds `{{ include "Brewfile" | sha256sum }}` in a comment of a `run_onchange_before_install-homebrew-bundle.sh.tmpl` script, so `brew bundle` fires exactly when the Brewfile changes and stays quiet otherwise.
  - Uses templates *sparingly* — one `promptStringOnce` for the machine name; dislikes Go template syntax, keeps `.chezmoi.toml.tmpl` tiny.
- **Relevance:** The closest match to our project. Concrete pain-point list (write-through edits, fresh-machine conflicts, non-file concerns like Homebrew) maps 1:1 to why we are leaving Stow.

### 1.2 Fedora Magazine introduction (still the canonical intro)
- **Title:** Take back your dotfiles with Chezmoi
- **Author:** Ryan Walter
- **URL:** https://fedoramagazine.org/take-back-your-dotfiles-with-chezmoi/
- **Date:** 2020-04-03
- **Takeaways:**
  - Frames the three classic problems dotfile managers must solve: symlink chore (Stow/RCM), secrets in git, and per-device differences.
  - Walks through `chezmoi init` / `chezmoi add` / `chezmoi diff` / `chezmoi apply`, `dot_` naming, `--autotemplate`, and `private_` prefixes.
  - Explicit warning that `private_` files are *not encrypted* — they are plaintext in your repo with tight permissions; real secrets need age/gpg/password-manager integration.
  - Shows `chezmoi doctor`, which checks for password-manager CLIs (op, bw, gopass, keepassxc, lpass, pass, vault).
- **Relevance:** Best 10-minute primer to hand anyone on the team who has never used chezmoi; the Stow-vs-chezmoi distinction ("dotfiles are files, not symlinks") is made early and clearly.

### 1.3 A long-term user's journey (5+ years of chezmoi)
- **Title:** My Dotfiles Story: A Journey to Chezmoi
- **Author:** Mike Kasberg
- **URL:** https://www.mikekasberg.com/blog/2021/05/12/my-dotfiles-story.html
- **Date:** 2021-05-12
- **Takeaways:**
  - Traces the evolution Dropbox-copy → homegrown bash diff script → chezmoi, and why each stop failed (files out of sync, per-machine diffs unmanageable).
  - The memorable quote: "Chezmoi is like what you might get if you re-wrote my bash script in Go, came up with better solutions than `diff` for managing config on multiple machines, added in secrets management... and tweaked and perfected it over years."
  - Recommends starting small: adopt one file (`.bashrc`/`.vimrc`) via `chezmoi add`, then grow the repo.
- **Relevance:** Shows what "real-world usage over years" looks like; sets expectations that the tool grows with you. His dotfiles repo (see §4) is the accompanying artifact.

### 1.4 Secrets without password-manager fatigue
- **Title:** Dotfiles Secrets in Chezmoi, Without Password Headaches
- **Author:** Mike Kasberg
- **URL:** https://www.mikekasberg.com/blog/2026/01/31/dotfiles-secrets-in-chezmoi.html
- **Date:** 2026-01-31
- **Takeaways:**
  - The recurring anti-pattern: wiring Bitwarden template functions into every template means *every* `chezmoi apply/update` demands an unlock + OTP, so he began avoiding updates entirely.
  - His fix: a checked-in script fetches secrets from Bitwarden once and writes them to a git-ignored `secrets.yml` inside `.chezmoidata/`; templates read `.chezmoidata` values, so apply never prompts.
  - Deliberately rejected age-encrypting files in a public repo ("feels like you're asking for someone to try to break it").
  - Notes chezmoi's flexibility "is both good and bad... gives you all the tools you need to shoot yourself in the foot."
- **Relevance:** Directly informs our secrets strategy decision (age vs password-manager vs `.chezmoidata` cache). The failure mode he hit (avoiding updates because of auth friction) is a realistic long-term risk.

### 1.5 A hands-on symlink-farm → chezmoi swap
- **Title:** Swapping to Chezmoi
- **Author:** Jason Fowler
- **URL:** https://jsnfwlr.com/blog/2024/11/16/swapping-to-chezmoi/
- **Date:** 2024-11-16
- **Takeaways:**
  - His previous setup was a manual `.user.d` symlink farm — "pretty much re-creating a manual version of GNU stow" — and he documents the teardown: break links, `find . -type l -ls`, then `cp` real files into place before `chezmoi add`.
  - The all-in-one reinstall command he converged on: `sh -c "$(curl -fsLS get.chezmoi.io/lb)" -- init --apply git@git...dot-files.git`.
  - Honest about the ongoing learning curve: wants per-host `.gitconfig`/`.ssh/config` *without* templates, wants a re-add prompt on edit, wants an apply prompt on sync — items he left for "future Jason."
- **Relevance:** The closest published account of the *mechanical* migration (break symlinks → materialize files → add) that we will repeat; also validates that per-host non-templated files are a real design tension.

### 1.6 From hand-rolled symlink scripts to chezmoi + 1Password
- **Title:** Managing dotfiles with Chezmoi
- **Author:** Nathaniel Landau
- **URL:** https://natelandau.com/managing-dotfiles-with-chezmoi/
- **Date:** 2025-01-19
- **Takeaways:**
  - Migrated from a handcrafted symlink system ("maintaining the sync scripts became increasingly complex as I added more features") and lists his evaluation criteria: security, flexibility, maintenance ease.
  - His `.chezmoi.toml.tmpl` uses `promptBoolOnce`/`promptStringOnce` at the top to gate whole feature areas (`use_secrets`, `personal_computer`, `homelab_member`, `dev_computer`) — a clean pattern for one repo serving multiple roles.
  - Template examples for boolean logic, OS checks (`eq .chezmoi.os "darwin"`), and data-driven generation from `.chezmoidata/packages.toml`.
  - Script hooks: numbered `run_before_00_homebrew.sh` etc., with alphabetical ordering controlling execution.
- **Relevance:** A mid-complexity real-world repo; the prompt-gated feature flags are a strong pattern for a multi-machine migration where Stow used "packages."

### 1.7 From Dotbot (symlinks) to chezmoi — the app-pollution argument
- **Title:** Dotfiles, Part 2: Managing Cross-Machine Config and Secrets with Chezmoi
- **Author:** David (blahaj.uk)
- **URL:** https://blog.blahaj.uk/posts/dotfiles-advanced-chezmoi/
- **Date:** 2026-05-19
- **Takeaways:**
  - Argues the core Dotbot/Stow flaw: with symlinks, when an app writes to its config (tokens, caches, window positions), it writes *into your git repo* — "a feature (changes show up as diffs instantly) and a bug (tokens, caches, recently opened files... can all sneak in)." chezmoi's source/apply model keeps the repo clean; you `chezmoi re-add` deliberately.
  - Shows why `.local` include-files can't replace templates: GUI apps read `~/.config/app/settings.json` and will never load `settings.json.local`, whereas a template composes machine data before the app reads it.
  - Secrets via Bitwarden template functions (`bitwarden "item" ...`), with the caveat that generated files still contain plaintext on disk — password managers solve "secrets in git," not "plaintext on disk."
  - Shares his `.gitignore`/`.chezmoiignore` rules and explicit "don't track" advice: `gh hosts.yml` login state, per-machine SSH keys.
- **Relevance:** The strongest articulation of why symlink-based management is actively hazardous for app-managed configs — the same reason our Stow setup risks token leakage.

### 1.8 Cross-platform migration (org-babel → chezmoi; Stow dismissed for NTFS)
- **Title:** Migrating my systems from org-babel to chezmoi
- **Author:** Simen Endsjø
- **URL:** https://simendsjo.me/blog/20240513200515-migrating_my_systems_from_org_babel_to_chezmoi.html
- **Date:** 2024-05-13
- **Takeaways:**
  - Explains why he never used Stow for Windows/WSL sharing: "heavily built around symlinks, so I don't dare to use it anywhere near NTFS."
  - chezmoi works because it copies files and runs natively on Windows; he applies the same repo to two destinations with `chezmoi apply` and `chezmoi apply --destination d:`.
  - Candid criticism from a real user: "It's way too bloated for my needs, and I don't like the configuration, but it seems to work as announced."
  - One-evening migration; worked first try on Windows.
- **Relevance:** Shows chezmoi's advantage when machines span OSes/filesystems (a scenario Stow structurally can't serve), plus a realistic "it's overkill but it works" counterpoint.

### 1.9 First-boot bootstrap details (HTTPS → SSH switch)
- **Title:** Bootstrapping chezmoi from HTTPS to SSH After First Apply
- **Author:** Lorenzo Bettini
- **URL:** https://www.lorenzobettini.it/2026/05/bootstrapping-chezmoi-from-https-to-ssh-after-first-apply/
- **Date:** 2026-05-08
- **Takeaways:**
  - Solves a real chicken-and-egg: clone over HTTPS (no SSH keys yet), apply (installs keys), then a `run_once_after_switch-origin-to-ssh.sh.tmpl` rewrites the git remote to SSH.
  - Pitfall documented with exact error: a script running *inside* `chezmoi apply` must not call `chezmoi source-path` (persistent state lock timeout) — inject paths via `{{ .chezmoi.sourceDir }}` templating instead.
  - `chezmoi state delete-bucket --bucket=scriptState` resets `run_once_` scripts for testing.
- **Relevance:** Practical first-boot sequencing we will need for the one-command new-machine story; the "no nested chezmoi in scripts" rule is a migration trap.

### 1.10 Tool comparison from a skeptic
- **Title:** Exploring Tools For Managing Your Dotfiles
- **Author:** GBergatto
- **URL:** https://gbergatto.github.io/posts/tools-managing-dotfiles
- **Date:** 2024-12-17
- **Takeaways:**
  - Even-handed tour: bare git repo, GNU Stow, yadm, chezmoi, with pros/cons per tool and a worked Stow example (packages, `~/.config` symlink folding).
  - Concludes chezmoi is "probably the most user-friendly and feature-rich tool on this list... if you need the advanced features or just want to go with the safest option."
  - Chose yadm for himself as "the most minimal solution"; calls chezmoi "a bit overkill" for a single machine — the recurring counterpoint.
  - Notes a chezmoi advantage over Stow: because deployed files are real files, "you can stop using Chezmoi at any point without needing to take any further action" (no symlink cleanup).
- **Relevance:** Honest cost/benefit framing; useful to calibrate how much of chezmoi's feature set we actually need.

### 1.11 Modular shell layout (ZDOTDIR + chezmoi)
- **Title:** Dotfiles Without .zshrc: ZDOTDIR and chezmoi
- **Author:** SHIINAYANE
- **URL:** https://www.shiinayane.com/posts/dotfiles/
- **Date:** 2026-05-30
- **Takeaways:**
  - Keeps only `~/.zshenv` in $HOME (sets `ZDOTDIR`); all zsh config lives in `~/.config/zsh/` as numbered fragments (00-env, 10-completion, ... 90-local) loaded in order.
  - `90-local.zsh` is the designated per-machine, not-tracked fragment — a deliberate alternative to templates for machine-local shell bits.
  - The `zhealth` function surfaces drift (installers re-adding `~/.zshrc` to $HOME).
  - Ignore strategy: `.gitignore` keeps cruft out of git; `.chezmoiignore` stops chezmoi managing target paths (`.zcompdump*`, `.zsh_history`).
- **Relevance:** A proven structure for reorganizing a Stow-era shell config into small, chezmoi-friendly pieces — reduces the need for templates in the first place.

### 1.12 Decluttering migration ("Marie Kondo" your dotfiles)
- **Title:** I Deprecated Dotfiles and Oh My Zsh, and Moved to Chezmoi
- **Author:** @samwize
- **URL:** https://samwize.com/2026/02/13/i-deprecated-dotfiles-and-oh-my-zsh-and-moved-to-chezmoi/
- **Date:** 2026-02-13
- **Takeaways:**
  - Migrating a 10-year-old dotfiles + oh-my-zsh setup: kept only what he uses weekly — "if an alias or script did not spark joy... I removed it."
  - His daily loop is deliberately simple: edit live files, `chezmoi add ~/.zshrc`, apply, commit/push; on other machines `chezmoi cd && git pull && chezmoi apply`.
  - Notes AI assistants (Codex/Claude) make lean rewrites cheap — no reason to carry years of baggage.
- **Relevance:** Migration as cleanup, not just tool swap; warns against porting Stow-era cruft verbatim.

### 1.13 chezmoi inside a broader automation stack (Ansible)
- **Title:** Improving My Dotfiles Posture
- **Author:** Ben Prisby
- **URL:** https://benprisby.com/blog/improving-my-dotfiles-posture/
- **Date:** 2025-09-08
- **Takeaways:**
  - Rejected copying files by hand and rejected extending Ansible to deliver dotfiles (machines outside the inventory — work Mac, test VMs — would be left out); chezmoi covers the personal-config niche between "manual" and "full CM."
  - `chezmoi update` as the single sync command; templates handle OS differences (macOS Zsh vs Debian Bash); Ansible playbooks invoke chezmoi for managed hosts.
- **Relevance:** Shows how chezmoi coexists with an existing orchestrator — directly analogous to our custom orchestrator; chezmoi can absorb the dotfile part while scripts keep doing machine-specific setup.

### 1.14 The re-add workflow that keeps repos honest
- **Title:** How I use chezmoi to manage dotfiles across Macs
- **Author:** Sayz Lim
- **URL:** https://sayzlim.net/manage-dotfiles-across-macs-chezmoi/
- **Date:** 2026-04-16
- **Takeaways:**
  - Argues `chezmoi re-add` is "the part most dotfiles guides under-explain": apps edit configs in place, so pulling live state back into source (`chezmoi re-add ~/.config/karabiner/karabiner.json`) is what keeps the repo from becoming "a brittle idealized copy of your machine."
  - The mental model: `add` (live → source), `apply` (source → live), `re-add` (live → source again), `diff` (inspect).
  - Recommends against over-engineering the setup — predictability over cleverness.
- **Relevance:** Defines the steady-state editing workflow we must document for the team after migration; re-add replaces Stow's write-through.

### 1.15 Daily-driver pitfalls (forgetting `chezmoi edit`, `--watch` quirks)
- **Title:** Foolproof chezmoi changing
- **Author:** quietism.art ("Polyamorous Computers")
- **URL:** https://quietism.art/posts/foolproof-chezmoi-changing/
- **Date:** 2026-06-16
- **Takeaways:**
  - The #1 daily mistake after switching from symlink tools: editing the live file directly and forgetting to sync back into the source repo — impossible to notice until another machine lacks the change.
  - His `chx` shell function does `chezmoi add <file>` then `chezmoi edit <file>` to fold live edits into source before editing.
  - Documents `chezmoi edit --watch` hardlink behavior (only first save applies; workaround needs custom `tempDir`; loses VCS diff context).
  - Explicitly frames this as the behavioral difference from "symlink approaches like gnu stow, because there's no symlinks here."
- **Relevance:** The single most common post-migration footgun for Stow users; the fix (add-then-edit wrapper) is worth adopting day one.

---

## 2. Videos (8)

### 2.1 The author's own talk (best overview)
- **Title:** chezmoi: manage your dotfiles across multiple, diverse machines, securely (FOSDEM 2021)
- **Channel:** FOSDEM (speaker: Tom Payne, chezmoi author)
- **URL:** https://fosdem.org/2021/schedule/event/chezmoi/
- **Date:** 2021-02-06/07; lightning talk (length not shown on page)
- **Covers:** The problem space, quickstart (`chezmoi init` + one-liner), architecture and technical choices, comparison with other dotfile managers.
- **Relevance:** The recommended video per the official hub; hearing the design intent from the author beats any tutorial.

### 2.2 Typecraft's full-stack setup (chezmoi + Ansible)
- **Title:** The ultimate dotfiles setup
- **Channel:** Terminal Velocity (Typecraft)
- **URL:** https://www.youtube.com/watch?v=-RkANM9FfTM
- **Date:** 2023-12-05; 51k views, 1.4k likes (length not shown in extraction)
- **Covers:** Fresh-VM demo of a two-liner bootstrap; chezmoi for configs plus `run_once_`/`run_onchange_` scripts; Ansible playbook for application installs; `chezmoi diff/apply/edit/cd` workflow.
- **Relevance:** Great visual of the *end state* we're aiming for (new machine → configured in minutes) and of how run-once/on-change scripts replace an orchestrator.

### 2.3 Typecraft tutorial (written)
- **Title:** Automate Your Dotfiles with Chezmoi
- **Channel:** Typecraft Learn
- **URL:** https://learn.typecraft.dev/tutorial/our-place-chezmoi/
- **Date:** 2024-06-26
- **Covers:** Step-by-step chezmoi tutorial; **note:** full content is behind a membership wall (intro is public).
- **Relevance:** Useful as a structured walkthrough if a team member wants a guided path.

### 2.4 Practical walkthrough from a Stow user
- **Title:** Managing Dotfiles with Chezmoi
- **Channel:** Rumi
- **URL:** https://www.youtube.com/watch?v=KsEj_pvOXdE
- **Date:** 2025-04-22; 6.3k views
- **Covers:** Install via package managers, `chezmoi init`, `chezmoi add` for configs (rofi, kitty), the copy-not-symlink model, and wrapping apply into a one-shot setup script for reinstalls.
- **Relevance:** The transcript literally starts "I've been using GNU stow... I just came across an even better tool" — a stow-user's on-camera conversion; simple and unpretentious.

### 2.5 Why automate dotfiles at all
- **Title:** Using Chezmoi to Automate dotfiles / Config Files (+ my bashrc)
- **Channel:** sudopluto
- **URL:** https://www.youtube.com/watch?v=id5UKYuX4-A
- **Date:** 2022-09-13; 6.9k views
- **Covers:** Version-control/revert story for configs, per-machine branches as an alternative to templates, spinning up containers/VMs with `chezmoi apply`, and why he chose chezmoi over Perl-based stow ("when you install stow you have to install all the Perl interpreter libraries").
- **Relevance:** Good motivation + a concrete stow-vs-chezmoi install-footprint comparison; encrypted files demo.

### 2.6 Converting an existing dotfiles repo
- **Title:** chezmoi: Organize your dotfiles across multiple computers | Let's Code
- **Channel:** chris biscardi
- **URL:** https://www.youtube.com/watch?v=L_Y3s0PS_Cg
- **Date:** 2021-09-06; 18.8k views
- **Covers:** Takes his *old, unmanaged dotfiles repo* and converts it into chezmoi source live: init, add, executables, `chezmoi git` passthrough; timestamped chapters.
- **Relevance:** The most direct "conversion of an existing repo" video — closest to our own migration mechanics.

### 2.7 Concepts explainer (hub-listed)
- **Title:** How CHEZMOI manages dotfiles
- **Channel:** (per official chezmoi.io videos hub)
- **URL:** https://www.youtube.com/watch?v=xXemcEdoI9Y
- **Date:** 2025-09-13 (per hub). *Extraction of the page was blocked; metadata from the official hub.*
- **Relevance:** Listed on the project's own videos page; title suggests a concept-level explainer useful for onboarding.

### 2.8 New-machine bootstrap demo (hub-listed, French)
- **Title:** Nouveau laptop ? Configurez TOUT en 5 min avec Chezmoi ("New laptop? Configure EVERYTHING in 5 min with Chezmoi")
- **Channel:** (per official chezmoi.io videos hub)
- **URL:** https://www.youtube.com/watch?v=6nqhBjvVVqE
- **Date:** 2026-01-01 (per hub). *Extraction of the page was blocked; metadata from the official hub.*
- **Relevance:** Demonstrates the one-command fresh-laptop story that motivates the whole migration.

---

## 3. Podcasts (4)

### 3.1 The author on FLOSS Weekly
- **Title:** FLOSS Weekly episode 556: Chezmoi
- **URL:** https://twit.tv/shows/floss-weekly/episodes/556
- **Date:** 2019-11-20
- **Key points:** Tom Payne interviewed; the show blurb highlights the security story: "particularly strong support for security, allowing you to manage secrets (e.g. passwords, access tokens, and private keys) securely... using either gpg encryption or a password manager." Audio/MP4 and YouTube links on the page.
- **Relevance:** Historical context from the author; still the best long-form interview.

### 3.2 A gentle, multi-episode series for newcomers
- **Title:** CCATP #693 — Bart Busschots on PBS 121 — Managing Dot Files and an Introduction to Chezmoi
- **URL:** https://www.podfeet.com/blog/2021/07/ccatp-693/
- **Date:** 2021-07-23
- **Key points:** Teaching-style episode: why manage dotfiles at all, why Bart favors chezmoi, install + first two commands. Follow-ups in the same series cover backing up/syncing (#696), templates (#698), and multiple computers (#699) — see the official podcasts hub for the full list.
- **Relevance:** Ideal for a team member who needs the *why* before the *how*; the series covers templates and multi-machine, both central to our migration.

### 3.3 chezmoi on BSDs
- **Title:** BSD Now 581: Releasing more BSDs (segment: "Managing dotfiles with chezmoi")
- **URL:** https://www.bsdnow.tv/581
- **Date:** 2024-10-17; 53 min 34 sec
- **Key points:** News segment reviewing the Stoddart article (stoddart.github.io managing-dotfiles-with-chezmoi) alongside FreeBSD/OpenBSD coverage; the segment URL with timestamp is https://www.bsdnow.tv/581?t=2064.
- **Relevance:** Shows chezmoi as the dotfile answer on non-Linux Unixes — same class of machines as our servers.

### 3.4 Bootstrapping a new machine (Python community angle)
- **Title:** The Real Python Podcast, Episode 101: Tools for Setting Up Python on a New Machine
- **URL:** https://realpython.com/podcasts/rpp/101/
- **Date:** 2022-03-11 (per official podcasts hub; page itself doesn't show a date)
- **Key points:** Calvin Hendryx-Parker on bootstrapping new machines; chezmoi discussed as part of the workflow (chezmoi segment at t=3368 per the hub). Full show notes cover pyenv, virtualenvs, and CLI tooling.
- **Relevance:** The "set up a new machine, not just Python" framing matches our one-command goal.

---

## 4. Community dotfiles repos using chezmoi (5)

*Structure notes below are from the repos' GitHub file listings/READMEs, viewed via web extraction. Nothing was cloned.*

### 4.1 twpayne/dotfiles — the author's own
- **URL:** https://github.com/twpayne/dotfiles
- **Interesting structure:** The reference repo. `home/` subdirectory with `.chezmoiroot` pointing at it (keeps repo root clean); `.chezmoiversion` pins a minimum version; `install.sh` + README give a one-liner install. Personal secrets live in 1Password (needs the 1Password CLI).
- **Why it matters:** Smallest-dependency reference for "how the author actually structures a chezmoi source tree."

### 4.2 rednafi/dotfiles — minimal, script-driven (ex-Stow user)
- **URL:** https://github.com/rednafi/dotfiles
- **Interesting structure:** Companion to article §1.1: `.chezmoi.toml.tmpl` with a single `machineName` prompt, `.chezmoiscripts/macos/` with `run_onchange_before_install-homebrew-bundle.sh.tmpl` (Brewfile checksum trick), `run_onchange_after_init-macos-machine.sh.tmpl`, `dot_gitconfig` + `-pers`/`-werk` split with git `includeIf`, `dot_agents/skills`, `private_` files for gh hosts.yml and Codex config, Brewfile kept out of $HOME via `.chezmoiignore`.
- **Why it matters:** The best template for a Stow→chezmoi repo that wants *minimal* templating and maximum script reuse of an existing orchestrator.

### 4.3 mkasberg/dotfiles — secrets caching + testing
- **URL:** https://github.com/mkasberg/dotfiles
- **Interesting structure:** Companion to articles §1.3/§1.4. `bin/executable_kasm-secrets` fetches Bitwarden secrets into git-ignored `.chezmoidata/secrets.yml`; `private_dot_ssh/`, `private_dot_config/` for 0600 files; `install.sh` bootstraps via `git.io/chezmoi`; `test.sh` + Dockerfile(s) to test a fresh install in a disposable container; `dot_gitconfig.tmpl`, `dot_zprofile.tmpl`.
- **Why it matters:** Shows both the `.chezmoidata` secrets-cache pattern and containerized testing of the bootstrap — directly reusable ideas.

### 4.4 bketelsen/dotfiles — hardened public-repo secrets
- **URL:** https://github.com/bketelsen/dotfiles
- **Interesting structure:** age-encrypted sensitive files plus Bitwarden CLI for runtime retrieval, documented in `docs/encryption.md`; `bootstrap.sh` one-command setup; `.pre-commit-config.yaml` and `.secrets.baseline` (gitleaks) to stop secret leaks at commit time; `.chezmoiscripts/`; `dot_bashrc.tmpl`, `dot_zshrc.tmpl`, `dot_gitconfig.tmpl`.
- **Why it matters:** The strongest example of "public repo, no secrets" hygiene — age + gitleaks pre-commit is a cheap, high-value addition for a migration that inherits old secrets in git history.

### 4.5 shunk031/dotfiles — testable, layered repo
- **URL:** https://github.com/shunk031/dotfiles
- **Interesting structure:** `.chezmoiroot` → `home/` for chezmoi source; `install/` holds plain shell scripts that are later templated into `.chezmoiscripts`; separate `tests/` (with codecov) and `scripts/`; `Makefile` with `make watch` (watchexec → `chezmoi apply` on change, because chezmoi has no built-in watch, ref twpayne/chezmoi#2738); `setup.sh`; unified AI-coding-agent config (Claude Code, Codex, Gemini) — a 2025-2026 trend.
- **Why it matters:** Shows the "test your dotfiles" discipline and the shell-script → chezmoi-script migration pipeline, which parallels our own orchestrator-to-chezmoi conversion.

---

## 5. Comparisons and community opinion (8)

### 5.1 HN: "Migrating from GNU Stow to Chezmoi" (rednafi article)
- **URL:** https://news.ycombinator.com/item?id=48588413
- **Date:** ~2026-06 (141 points, 142 comments)
- **Praise:** chezmoi is "a darling of the community" (jdxcode, mise author); declarative templates + git rollback ("revert commits and `chezmoi apply`"); works well within "less-ambitious goals (compared to Nix)."
- **Criticism/counterpoints:** Some defend Stow's write-through as a *feature* ("git shows it as dirty, and I get to decide"); several note stow remains indispensable for managing `/usr/local` installs (`./configure --prefix=/usr/local/stow/myapp` + `stow myapp`) — i.e. the tools solve different problems; a few find chezmoi overkill and use 200-line shell scripts instead.
- **Takeaway:** Expect pushback from single-machine Stow users; the multi-machine + fresh-machine arguments carry the debate.

### 5.2 HN: "Better Dotfiles" (iamdan.me)
- **URL:** https://news.ycombinator.com/item?id=41453264
- **Date:** 2024-09-06 (153 points, 107 comments)
- **Praise:** "Chezmoi is good enough that I'm willing to let someone else handle maintaining all logic" (ex-Stow user); yadm → chezmoi converts cite built-in Go templating vs yadm's unmaintained jinja2 deps; age integration praised; `private_dot_ssh/` auto-handling of `.ssh/config` called "smart."
- **Criticism/gotchas:** `chezmoi cd` spawning a new shell is annoying (fix: `alias cm='cd $(chezmoi source-path)'`); author himself chimes in on why that's unavoidable; reminder that `private_` only sets permissions, not encryption.
- **Takeaway:** Consensus that chezmoi's templating is the killer feature; the alias fix should be in our team's shell config from day one.

### 5.3 HN: "Chezmoi – Manage your dotfiles..." (official site on HN)
- **URL:** https://news.ycombinator.com/item?id=32636051
- **Date:** 2022-08-29 (121 points, 59 comments)
- **Praise:** A long power-user comment lists what chezmoi replaced: vim/zsh plugins, SSH+GPG key generation, per-host/per-OS config, package installs on FreeBSD/Linux/macOS — "a tool that deepens with use"; single `dot_zshrc_tmpl` generating all variations.
- **Criticism:** When "symlinks or a bare git repo becomes unwieldy," some prefer Nix/home-manager or Ansible; chezmoi sits between simple and full CM.
- **Takeaway:** Long-horizon view of where chezmoi fits in the tooling spectrum.

### 5.4 Lobsters: "Managing dotfiles with chezmoi"
- **URL:** https://lobste.rs/s/czy3bp/managing_dotfiles_with_chezmoi
- **Date:** 2024-09 (26 comments)
- **Praise:** "The templating is exactly why I switched after years with rcm and GNU stow" — powerful across macOS/NixOS/OpenBSD/Windows and for credential-derived sections; author-maintainer engagement in GitHub discussions praised; 10-minute setup reports.
- **Criticism:** One user finds docs "somewhat twisted" and the basic workflow grating (changes thrown away/ applied wrongly); helix + `chezmoi edit` compatibility issue.
- **Takeaway:** Even enthusiasts admit a learning curve on the source/apply model; docs contributions are welcomed by the maintainer.

### 5.5 Reddit: "Why I stuck with GNU Stow instead of chezmoi or yadm"
- **URL:** https://www.reddit.com/r/dotfiles/comments/1qy9vbe/why_i_stuck_with_gnu_stow_instead_of_chezmoi_or
- **Date:** undated (recent; search-verified — Reddit blocks direct fetching)
- **Content:** A deliberate counterpoint: after investigating all three, the author stays on Stow — simple, idempotent, zero config format, no template language to learn.
- **Takeaway:** The honest "Stow is fine if you're single-machine and happy" position; our migration rationale must be multi-machine/secret/automation-driven, not fashion-driven.

### 5.6 Reddit: "Chezmoi vs yadm vs stow"
- **URL:** https://www.reddit.com/r/dotfiles/comments/1k8hxgo/chezmoi_vs_yadm_vs_stow
- **Date:** undated (recent; search-verified — Reddit blocks direct fetching)
- **Content:** Thread consensus: "Stow is really `ln` with a package defined by paths"; "yadm is extremely simple and convenient"; chezmoi users report being "completely satisfied." The recurring split is minimalism (yadm/stow) vs features (chezmoi).
- **Takeaway:** Good summary of the community's three-way trade-off; useful for the decision record.

### 5.7 chezmoi's own comparison table and design FAQ
- **URLs:** https://www.chezmoi.io/comparison-table/ and https://chezmoi.io/user-guide/frequently-asked-questions/design
- **Content:** Feature matrix vs dotbot, rcm, vcsh, yadm, bare git (templates, private files, whole-file encryption, password-manager integration, externals, run-once scripts — chezmoi is the only ✅ across the board except rcm-style multi-repo).
- **Design FAQ** explains the philosophy: "you only use a symlink where you really need a symlink, in contrast to... GNU Stow which require the use of symlinks as a layer of indirection"; a symlink mode exists if you want Stow-like behavior (issue #167), and the only stow advantage (instant write-through) is covered by `chezmoi edit --watch`.
- **Takeaway:** Read the design FAQ before writing the migration plan — it is the authoritative answer to "but what about my symlinks?"

### 5.8 The one true stow→chezmoi migration script
- **URL:** https://github.com/twpayne/chezmoi/issues/180
- **Date:** opened 2019-01-28
- **Content:** A community-contributed `stow-to-chezmoi.sh` that converts a stowed `~/dotfiles` into a chezmoi-managed homedir (`usage: stow-to-chezmoi.sh [BASE_DIR] [DOTFILES_DIRNAME]`); closed as a "won't build into chezmoi core" but the script file is still attached (stow-to-chezmoi.txt). Caveat: author says "probably got edge cases I haven't run into."
- **Takeaway:** A starting point if we want a scripted conversion, but expect to hand-verify every file; a semi-automated + manual review approach is safer.

---

## 6. Synthesis — recurring themes across all sources

**What people love**
- The source/apply model: real files in $HOME, git repo as single source of truth, no symlink indirection. Apps writing to configs no longer pollute the git repo (blahaj §1.7, rednafi §1.1, design FAQ §5.7).
- One-command bootstrap: `sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply <repo>` on a fresh machine, with `run_once_`/`run_onchange_` scripts replacing the custom orchestrator (fedoramagazine §1.2, jsnfwlr §1.5, Typecraft §2.2, mkasberg repo §4.3).
- Templates as the killer feature for machine differences — but almost every experienced user warns to use them *sparingly* (rednafi §1.1, gbergatto §1.10, HN §5.2).
- Secrets story: age whole-file encryption for public repos, password managers for values, `private_` prefix for permissions — and the docs' warning that `private_` ≠ encrypted (fedoramagazine §1.2, bketelsen §4.4, HN §5.2).
- Determinism: fewer shell scripts because logic moves into templates/data (HN §5.2/5.3); everything is diffable and rollback-able via git (HN §5.1).

**What people find confusing**
- The source/apply direction is the #1 recurring mistake: editing the live file and forgetting to `chezmoi add`/`re-add` (quietism §1.15, jsnfwlr §1.5). Stow's write-through trained us to edit-in-place; chezmoi requires an explicit sync step.
- `dot_`/`private_`/`executable_`/`symlink_` naming and `.tmpl` suffix feel alien at first (sayzlim §1.14, gbergatto §1.10).
- Go template syntax intimidates; several authors explicitly minimize it (rednafi §1.1, natelandau §1.6).
- Gotchas: `chezmoi cd` spawns a subshell; `chezmoi edit --watch` hardlink quirks; never call `chezmoi` from inside a chezmoi script (lock timeout) (HN §5.2, quietism §1.15, lorenzobettini §1.9).
- "Overkill for a single machine" is the standing criticism (gbergatto §1.10, Reddit §5.5/5.6) — chezmoi's complexity only pays off with 2+ machines, secrets, or per-host differences.

**Common migration mistakes (from the migration posts)**
- Porting Stow-era cruft verbatim instead of decluttering (samwize §1.12).
- Not materializing symlinked files before `chezmoi add` (`chezmoi add -f` follows symlinks, but the teardown order matters) (jsnfwlr §1.5).
- Underestimating fresh-machine conflicts: apps/Homebrew create `~/.zprofile`/`~/.gitconfig` before first apply — plan the init sequence (rednafi §1.1).
- Forgetting that `private_` files and gpg/age-encrypted files are different mechanisms, and that generated files still contain plaintext secrets on disk (blahaj §1.7, fedoramagazine §1.2).
- No backup before the switch; test the bootstrap in a container/VM first (htdocs-dev guidance echoed by mkasberg §4.3, shunk031 §4.5).
- Wiring a password manager into every template and then hating every `chezmoi update` (mikekasberg §1.4).

**Consensus recommendations**
- Symlinks vs copies: copies by default; use `symlink_` only for genuine symlink needs (rednafi's agent-skills case §1.1, design FAQ §5.7). If you truly want Stow behavior, chezmoi has a symlink mode — but almost nobody uses it.
- Templates: start with zero templates; add them only for per-machine data (email, hostname, OS branches); `promptStringOnce`/`promptBoolOnce` in `.chezmoi.toml.tmpl` is the standard way to collect machine facts (natelandau §1.6, rednafi §1.1).
- Secrets: age for whole-file encryption in public repos; password managers for values; `.chezmoidata` (git-ignored) as an auth-free cache; add gitleaks/pre-commit to protect history during migration (bketelsen §4.4, mikekasberg §1.4).
- Scripts: `run_onchange_` for package installs keyed to a checksum (Brewfile trick), `run_once_` for one-time setup; keep scripts few and deterministic (rednafi §1.1, HN §5.2).
- Don't track app login state (gh hosts.yml), shell history, or per-machine SSH keys; prefer per-machine key generation (blahaj §1.7).
- Adopt `chezmoi re-add` and an add-then-edit wrapper as the daily workflow to defeat the write-through reflex (sayzlim §1.14, quietism §1.15).
- Test the whole bootstrap in a disposable container before trusting it on real hardware (mkasberg §4.3, shunk031 §4.5).
- Keep Stow in the toolbox for what it's good at: `/usr/local` package management — the migration is about dotfiles, not about deleting a useful tool (HN §5.1).
