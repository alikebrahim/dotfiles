#!/usr/bin/env bash
set -euo pipefail

# Per-host GNU Stow dispatcher for the dotfiles repo.
# Detects hostname, verifies deployment safety, unstows all known packages,
# then stows only the packages appropriate for this host.

DOTFILES="${DOTFILES:-${HOME}/.dotfiles}"
PROGRAM="$(basename "$0")"
XORG_INPUT_CONFIG_REL="scripts/xorg/40-libinput-natural-scrolling.conf"
XORG_INPUT_CONFIG_TARGET="/etc/X11/xorg.conf.d/40-libinput-natural-scrolling.conf"

MODE="run"
HOST_OVERRIDE=""
VERBOSE=false
FORCE=false
ADOPT=false
NO_TMUX=false
NO_SSH=false
NO_XORG_INPUT=false
CHECK_ONLY=false
DRY_RUN=false
LIST_ONLY=false

PASS_COUNT=0
WARN_COUNT=0
FAIL_COUNT=0
ERRORS=()
WARNINGS=()

# --- Package inventory -----------------------------------------------------
# All packages known to this repo. Used for clean unstow.
ALL_PACKAGES=(
  zsh bash git vim nvim delta atuin my-bin apps
  1Password wezterm alacritty posting postman
  awesome awesome_wm_scripts picom dunst rofi polybar themes awesomewm-bin
  quickshell
  tmux
  tmux-remote
  tmux-remote-netmaster tmux-remote-servalws tmux-remote-minisforoum
  tmux-remote-zotac-box tmux-remote-macbook tmux-remote-honor
)

# Packages common to every host.
COMMON=(
  zsh bash git vim nvim delta my-bin
  tmux-remote
)

STOW_LIST=()
EXTRA=()
TMUX_OVERLAY=""
SSH_OVERLAY=""
HOST=""

usage() {
  cat <<'EOF'
Usage:
  stow-host.sh [options]

Purpose:
  Safely deploy this dotfiles repo on the current host using GNU Stow.
  The script selects host-appropriate packages, performs pre-flight checks,
  then unstows all known packages and stows the selected set.

Default behavior:
  1. Detect hostname.
  2. Select packages for that host.
  3. Run pre-flight checks.
  4. Create safety directories that prevent GNU Stow tree-folding.
  5. Unstow all known packages.
  6. Stow selected packages and the per-host SSH overlay.
  7. Install/update system Xorg input policy unless skipped.
  8. Install/update tmux plugins unless skipped.
  9. Reload tmux only if already inside a tmux session.

Options:
  -h, --help          Show this help text and exit.
  -l, --list          Show detected host, package selection, overlays, then exit.
  -c, --check         Run pre-flight checks only. Make no changes.
  -n, --dry-run       Show what would run. Uses stow --simulate where possible.
      --host HOST     Override hostname detection for planning/testing.
  -v, --verbose       Print stow command output on success too.
      --adopt         Use stow --adopt during stow phase.
                      WARNING: this moves existing real files into the repo.
      --force         Skip blocking pre-flight failures and run anyway.
      --no-tmux       Skip tmux plugin installation/update and tmux reload.
      --no-ssh        Skip per-host SSH overlay stowing.
      --no-xorg-input Skip installing the Xorg/libinput natural scrolling config.
      --dotfiles DIR  Override dotfiles repo path. Default: $HOME/.dotfiles.

Examples:
  bash ~/.dotfiles/scripts/stow-host.sh --help
  bash ~/.dotfiles/scripts/stow-host.sh --list
  bash ~/.dotfiles/scripts/stow-host.sh --check
  bash ~/.dotfiles/scripts/stow-host.sh --dry-run
  bash ~/.dotfiles/scripts/stow-host.sh --host servalws --list
  bash ~/.dotfiles/scripts/stow-host.sh --no-tmux

Host package map:
  common on all hosts:
    zsh bash git vim nvim delta my-bin tmux-remote

  netmaster:
    common + tmux-remote-netmaster + ssh/netmaster

  servalws:
    common + tmux-remote-servalws + ssh/servalws
    + 1Password wezterm awesome awesome_wm_scripts picom dunst rofi polybar awesomewm-bin
    Note: themes is intentionally not stowed here. It is too large for the shared
    dotfiles sync folder and should live outside the fleet-wide repo.

  minisforoum:
    common + tmux-remote-minisforoum + ssh/minisforoum
    + 1Password wezterm

  zotac-box:
    common + tmux-remote-zotac-box + ssh/zotac-box

  macbook:
    common + tmux-remote-macbook + ssh/macbook

Pre-flight checks include:
  - dotfiles repo exists
  - stow is installed and version is reported
  - GNU Stow dry-run conflict check for every selected package
  - per-host SSH overlay dry-run conflict check
  - ~/.local is not tree-folded into the repo
  - ~/.local/state and ~/.local/share are real directories when present
  - safety directories that would be created are listed
  - broken symlinks pointing into this dotfiles repo are reported
  - Xorg/libinput natural scrolling config source exists unless --no-xorg-input is used
  - tmux plugin installer exists unless --no-tmux is used

Tree-folding note:
  GNU Stow 2.3.1 has no --no-folding flag. This script prevents the known
  my-bin folding hazard by ensuring ~/.local exists as a real directory and by
  creating real ~/.local/state and ~/.local/share directories before stowing.
EOF
}

log_pass() {
  echo "[PASS] $*"
  PASS_COUNT=$((PASS_COUNT + 1))
}

log_warn() {
  echo "[WARN] $*"
  WARN_COUNT=$((WARN_COUNT + 1))
  WARNINGS+=("$*")
}

log_fail() {
  echo "[FAIL] $*"
  FAIL_COUNT=$((FAIL_COUNT + 1))
  ERRORS+=("$*")
}

run_cmd() {
  if $DRY_RUN; then
    printf '[DRY] '
    printf '%q ' "$@"
    printf '\n'
    return 0
  fi
  "$@"
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h|--help)
        usage
        exit 0
        ;;
      -l|--list)
        LIST_ONLY=true
        MODE="list"
        shift
        ;;
      -c|--check)
        CHECK_ONLY=true
        MODE="check"
        shift
        ;;
      -n|--dry-run)
        DRY_RUN=true
        MODE="dry-run"
        shift
        ;;
      --host)
        [[ $# -ge 2 ]] || { echo "ERROR: --host requires an argument" >&2; exit 2; }
        HOST_OVERRIDE="$2"
        shift 2
        ;;
      --dotfiles)
        [[ $# -ge 2 ]] || { echo "ERROR: --dotfiles requires an argument" >&2; exit 2; }
        DOTFILES="$2"
        shift 2
        ;;
      -v|--verbose)
        VERBOSE=true
        shift
        ;;
      --force)
        FORCE=true
        shift
        ;;
      --adopt)
        ADOPT=true
        shift
        ;;
      --no-tmux)
        NO_TMUX=true
        shift
        ;;
      --no-ssh)
        NO_SSH=true
        shift
        ;;
      --no-xorg-input)
        NO_XORG_INPUT=true
        shift
        ;;
      *)
        echo "ERROR: unknown option: $1" >&2
        echo "Run: $PROGRAM --help" >&2
        exit 2
        ;;
    esac
  done
}

detect_host() {
  if [[ -n "$HOST_OVERRIDE" ]]; then
    HOST="$HOST_OVERRIDE"
  else
    HOST="$(hostnamectl hostname 2>/dev/null || hostname | sed 's/\..*//')"
  fi
  CURRENT_USER="$(id -un)"
}

# Split SSH_OVERLAY (e.g. "zotac-box/alikebrahim_zotac-box") into
# SSH_STOW_DIR (the --dir argument, e.g. "ssh/zotac-box") and
# SSH_STOW_PKG (the package name, e.g. "alikebrahim_zotac-box").
# Stow does not allow slashes in package names, so per-user SSH
# overlays under ssh/<host>/<user>_<host>/ must use --dir=ssh/<host>.
split_ssh_overlay() {
  if [[ "$SSH_OVERLAY" == */* ]]; then
    SSH_STOW_DIR="ssh/${SSH_OVERLAY%%/*}"
    SSH_STOW_PKG="${SSH_OVERLAY#*/}"
  else
    SSH_STOW_DIR="ssh"
    SSH_STOW_PKG="$SSH_OVERLAY"
  fi
}

select_packages() {
  EXTRA=()
  TMUX_OVERLAY=""
  SSH_OVERLAY=""

  case "$HOST" in
    netmaster)
      TMUX_OVERLAY="tmux-remote-netmaster"
      SSH_OVERLAY="netmaster"
      ;;
    servalws)
      TMUX_OVERLAY="tmux-remote-servalws"
      SSH_OVERLAY="servalws"
      EXTRA=(
        apps 1Password wezterm
        awesome awesome_wm_scripts picom dunst rofi polybar awesomewm-bin
      )
      ;;
    minisforoum)
      TMUX_OVERLAY="tmux-remote-minisforoum"
      SSH_OVERLAY="minisforoum"
      EXTRA=(apps 1Password wezterm)
      ;;
    zotac-box)
      TMUX_OVERLAY="tmux-remote-zotac-box"
      # zotac-box has per-user SSH subdirs: ssh/zotac-box/<user>_zotac-box/.ssh/
      local user_ssh="zotac-box/${CURRENT_USER}_zotac-box"
      if [[ -d "$DOTFILES/ssh/$user_ssh" ]]; then
        SSH_OVERLAY="$user_ssh"
      else
        log_warn "zotac-box: no SSH overlay found for user '${CURRENT_USER}' (expected ssh/${user_ssh})"
      fi
      # tima gets apps, alikebrahim doesn't
      if [[ "$CURRENT_USER" == "tima" ]]; then
        EXTRA=(apps)
      fi
      ;;
    macbook)
      TMUX_OVERLAY="tmux-remote-macbook"
      SSH_OVERLAY="macbook"
      ;;
    honor)
      TMUX_OVERLAY="tmux-remote-honor"
      SSH_OVERLAY="honor"
      ;;
    *)
      log_warn "unknown host '${HOST}'; using common packages only"
      ;;
  esac

  STOW_LIST=("${COMMON[@]}")
  [[ -n "$TMUX_OVERLAY" ]] && STOW_LIST+=("$TMUX_OVERLAY")
  if [[ ${#EXTRA[@]} -gt 0 ]]; then
    STOW_LIST+=("${EXTRA[@]}")
  fi
}

print_selection() {
  echo "Host:       ${HOST}"
  echo "User:       ${CURRENT_USER}"
  echo "Dotfiles:   ${DOTFILES}"
  echo "Mode:       ${MODE}"
  echo "Packages:   ${STOW_LIST[*]}"
  if [[ -n "$SSH_OVERLAY" ]]; then
    echo "SSH:        ssh/${SSH_OVERLAY}"
  else
    echo "SSH:        none"
  fi
  if [[ -n "$TMUX_OVERLAY" ]]; then
    echo "Tmux theme: ${TMUX_OVERLAY}"
  else
    echo "Tmux theme: none"
  fi
  echo "Options:    force=${FORCE} adopt=${ADOPT} no_tmux=${NO_TMUX} no_ssh=${NO_SSH} no_xorg_input=${NO_XORG_INPUT} verbose=${VERBOSE}"
}

stow_cmd_for_package() {
  local pkg="$1"
  local simulate="$2"
  local cmd=(stow)
  $simulate && cmd+=(--simulate -v)
  cmd+=(-R)
  $ADOPT && cmd+=(--adopt)
  cmd+=("$pkg")
  printf '%q ' "${cmd[@]}"
}

run_stow_package() {
  local pkg="$1"
  local output rc
  local cmd=(stow -R)
  $ADOPT && cmd+=(--adopt)
  cmd+=("$pkg")

  if [[ ! -d "$DOTFILES/$pkg" ]]; then
    echo "  [SKIP]  $pkg (directory not found in dotfiles)"
    return 0
  fi

  if $DRY_RUN; then
    echo "  [DRY]   $(stow_cmd_for_package "$pkg" true)"
    (cd "$DOTFILES" && stow --simulate -v -R "$pkg") || true
    return 0
  fi

  if output=$(cd "$DOTFILES" && "${cmd[@]}" 2>&1); then
    echo "  [OK]    $pkg"
    if $VERBOSE && [[ -n "$output" ]]; then
      echo "$output"
    fi
  else
    echo "  [ERROR] $pkg — stow failed"
    echo "$output"
    return 1
  fi
}

run_stow_ssh_overlay() {
  local output
  [[ -n "$SSH_OVERLAY" ]] || return 0
  $NO_SSH && { echo "=== Skipping SSH overlay (--no-ssh) ==="; return 0; }

  if [[ ! -d "$DOTFILES/ssh/$SSH_OVERLAY" ]]; then
    echo "  [SKIP]  ssh/${SSH_OVERLAY} (directory not found)"
    return 0
  fi

  split_ssh_overlay

  echo "=== Stowing SSH config (ssh/${SSH_OVERLAY}) ==="
  if $DRY_RUN; then
    printf '  [DRY]   stow -R --dir=%s %s\n' "$SSH_STOW_DIR" "$SSH_STOW_PKG"
    (cd "$DOTFILES" && stow --simulate -v -R --dir="$SSH_STOW_DIR" "$SSH_STOW_PKG") || true
    echo ""
    return 0
  fi

  local cmd=(stow -R --dir="$SSH_STOW_DIR")
  $ADOPT && cmd+=(--adopt)
  cmd+=("$SSH_STOW_PKG")

  if output=$(cd "$DOTFILES" && "${cmd[@]}" 2>&1); then
    echo "  [OK]    ssh/${SSH_OVERLAY}"
    if $VERBOSE && [[ -n "$output" ]]; then
      echo "$output"
    fi
  else
    echo "  [ERROR] ssh/${SSH_OVERLAY} — stow failed"
    echo "$output"
    return 1
  fi
  echo ""
}

ensure_safety_dirs() {
  echo "=== Safety directories ==="

  if [[ -L "$HOME/.local" ]]; then
    echo "  [ERROR] ~/.local is a symlink: $(readlink "$HOME/.local")"
    echo "          Refusing to stow my-bin. Run: bash ~/.dotfiles/scripts/check-fold.sh --fix"
    return 1
  fi

  local dirs=(
    "$HOME/.local"
    "$HOME/.local/state"
    "$HOME/.local/share"
    "$HOME/.tmux"
  )

  for dir in "${dirs[@]}"; do
    if [[ -e "$dir" && ! -d "$dir" ]]; then
      echo "  [ERROR] $dir exists but is not a directory"
      return 1
    fi
    if [[ -L "$dir" ]]; then
      echo "  [ERROR] $dir is a symlink: $(readlink "$dir")"
      return 1
    fi
    if [[ -d "$dir" ]]; then
      echo "  [OK]    exists: $dir"
    else
      echo "  [CREATE] $dir"
      run_cmd mkdir -p "$dir"
    fi
  done
  echo ""
}

check_stow_version() {
  local version
  if ! command -v stow >/dev/null 2>&1; then
    log_fail "GNU Stow is not installed or not in PATH"
    return 0
  fi
  version="$(stow --version 2>/dev/null | head -1 || true)"
  log_pass "stow available: ${version:-unknown version}"
  if [[ "$version" =~ 2\.3\.1 ]]; then
    log_warn "GNU Stow 2.3.1 has no --no-folding; safety directories are required"
  fi
}

check_repo() {
  if [[ -d "$DOTFILES" ]]; then
    log_pass "dotfiles repo exists: $DOTFILES"
  else
    log_fail "dotfiles repo missing: $DOTFILES"
    return 0
  fi

  if [[ -f "$DOTFILES/scripts/stow-host.sh" ]]; then
    log_pass "stow-host.sh present in repo"
  else
    log_warn "scripts/stow-host.sh not found under repo path"
  fi
}

check_xorg_input_config() {
  if $NO_XORG_INPUT; then
    log_pass "Xorg input config install skipped (--no-xorg-input)"
    return 0
  fi

  if [[ -f "$DOTFILES/$XORG_INPUT_CONFIG_REL" ]]; then
    log_pass "Xorg input config source present: $XORG_INPUT_CONFIG_REL"
  else
    log_fail "Xorg input config source missing: $DOTFILES/$XORG_INPUT_CONFIG_REL"
  fi
}

check_package_dirs() {
  local pkg
  for pkg in "${STOW_LIST[@]}"; do
    if [[ -d "$DOTFILES/$pkg" ]]; then
      log_pass "package exists: $pkg"
    else
      log_warn "selected package missing: $pkg"
    fi
  done

  if ! $NO_SSH && [[ -n "$SSH_OVERLAY" ]]; then
    if [[ -d "$DOTFILES/ssh/$SSH_OVERLAY" ]]; then
      log_pass "SSH overlay exists: ssh/$SSH_OVERLAY"
    else
      log_warn "SSH overlay missing: ssh/$SSH_OVERLAY"
    fi
  fi
}

check_tree_folding() {
  if [[ -L "$HOME/.local" ]]; then
    log_fail "~/.local is tree-folded: ~/.local -> $(readlink "$HOME/.local")"
  elif [[ -d "$HOME/.local" ]]; then
    log_pass "~/.local is a real directory"
  else
    log_warn "~/.local does not exist; run mode will create it"
  fi

  local d
  for d in "$HOME/.local/state" "$HOME/.local/share" "$HOME/.tmux"; do
    if [[ -L "$d" ]]; then
      log_fail "$d is a symlink: $(readlink "$d")"
    elif [[ -d "$d" ]]; then
      log_pass "$d is a real directory"
    else
      log_warn "$d does not exist; run mode will create it"
    fi
  done
}

check_stow_simulation() {
  local pkg output rc
  for pkg in "${STOW_LIST[@]}"; do
    [[ -d "$DOTFILES/$pkg" ]] || continue
    output=""
    rc=0
    output=$(cd "$DOTFILES" && stow --simulate -v -R "$pkg" 2>&1) || rc=$?
    if [[ $rc -eq 0 ]]; then
      log_pass "stow dry-run OK: $pkg"
      if $VERBOSE && [[ -n "$output" ]]; then
        echo "$output"
      fi
    else
      log_fail "stow dry-run failed: $pkg"
      echo "$output"
    fi
  done

  if ! $NO_SSH && [[ -n "$SSH_OVERLAY" && -d "$DOTFILES/ssh/$SSH_OVERLAY" ]]; then
    split_ssh_overlay
    # Unstow stale SSH overlays first so the simulation reflects real run order
    local stale_pkg stale_dir
    for stale_dir in "$DOTFILES"/ssh/*/; do
      [[ -d "${stale_dir}.ssh" ]] || continue
      stale_pkg="$(basename "$stale_dir")"
      [[ "$stale_pkg" == "zotac-box" ]] && continue
      (cd "$DOTFILES" && stow --simulate -D --dir=ssh "$stale_pkg") >/dev/null 2>&1 || true
    done
    for stale_dir in "$DOTFILES"/ssh/zotac-box/*/; do
      [[ -d "${stale_dir}.ssh" ]] || continue
      stale_pkg="$(basename "$stale_dir")"
      (cd "$DOTFILES" && stow --simulate -D --dir=ssh/zotac-box "$stale_pkg") >/dev/null 2>&1 || true
    done
    # Now simulate stowing the selected overlay
    output=""
    rc=0
    output=$(cd "$DOTFILES" && stow --simulate -R --dir="$SSH_STOW_DIR" "$SSH_STOW_PKG" 2>&1) || rc=$?
    if [[ $rc -eq 0 ]]; then
      log_pass "stow dry-run OK: ssh/$SSH_OVERLAY"
    # SSH overlay conflicts where existing links point to a different SSH
    # package are expected — unstow_ssh_overlays() handles them at runtime.
    # Only downgrade to WARN if the ONLY conflicts are cross-package links.
    elif echo "$output" | grep -q 'existing target is stowed to a different package' \
         && ! echo "$output" | grep -q 'existing target is neither'; then
      log_warn "stow ssh/$SSH_OVERLAY has cross-package conflicts (resolved by unstow_ssh_overlays at runtime)"
    else
      log_fail "stow dry-run failed: ssh/$SSH_OVERLAY"
      echo "$output"
    fi
  fi
}

check_broken_dotfiles_links() {
  local count
  count=$(find "$HOME" -xdev -type l 2>/dev/null \
    | while IFS= read -r link; do
        target=$(readlink "$link" || true)
        case "$target" in
          *".dotfiles"*)
            if [[ ! -e "$link" ]]; then
              printf '%s -> %s\n' "$link" "$target"
            fi
            ;;
        esac
      done \
    | tee /tmp/stow-host-broken-links.$$ \
    | wc -l) || true

  if [[ "$count" -eq 0 ]]; then
    log_pass "no broken symlinks into .dotfiles found under $HOME"
  else
    log_warn "broken symlinks into .dotfiles found: $count"
    sed -n '1,25{s/^/       /;p}' /tmp/stow-host-broken-links.$$
    if [[ "$count" -gt 25 ]]; then
      echo "       ... $((count - 25)) more omitted"
    fi
  fi
  rm -f /tmp/stow-host-broken-links.$$
}

check_tmux_installer() {
  if $NO_TMUX; then
    log_pass "tmux plugin handling skipped (--no-tmux)"
    return 0
  fi

  if [[ -x "$DOTFILES/scripts/install-tmux-plugins.sh" || -f "$DOTFILES/scripts/install-tmux-plugins.sh" ]]; then
    log_pass "tmux plugin installer present"
  else
    log_fail "tmux plugin installer missing: $DOTFILES/scripts/install-tmux-plugins.sh"
  fi
}

preflight() {
  echo "=== Pre-flight checks ==="
  check_repo
  check_stow_version
  check_package_dirs
  check_tree_folding
  check_stow_simulation
  check_broken_dotfiles_links
  check_xorg_input_config
  check_tmux_installer
  echo ""
  echo "=== Pre-flight summary ==="
  echo "PASS: $PASS_COUNT"
  echo "WARN: $WARN_COUNT"
  echo "FAIL: $FAIL_COUNT"
  echo ""

  if [[ $FAIL_COUNT -gt 0 ]]; then
    echo "Blocking failures:"
    printf '  - %s\n' "${ERRORS[@]}"
    echo ""
    if $DRY_RUN; then
      echo "Dry-run mode: continuing so the deployment plan can still be previewed."
      echo ""
      return 0
    fi
    if ! $FORCE; then
      echo "Refusing to continue. Re-run with --force only if you understand the risk."
      return 1
    fi
    echo "Continuing because --force was supplied."
    echo ""
  fi
}

unstow_all_packages() {
  local pkg output
  echo "=== Unstowing all known packages ==="
  for pkg in "${ALL_PACKAGES[@]}"; do
    [[ -d "$DOTFILES/$pkg" ]] || continue
    if $DRY_RUN; then
      echo "  [DRY]   stow --simulate -v -D $pkg"
      (cd "$DOTFILES" && stow --simulate -v -D "$pkg") || true
      continue
    fi
    if output=$(cd "$DOTFILES" && stow -D "$pkg" 2>&1); then
      echo "  [OK]    unstow $pkg"
      if $VERBOSE && [[ -n "$output" ]]; then
        echo "$output"
      fi
    else
      echo "  [WARN]  unstow $pkg reported issues"
      echo "$output"
    fi
  done
  echo ""
}

# Unstow all SSH overlays before stowing the selected one.
# SSH overlays live under ssh/ and are stowed with --dir=ssh/<host>.
# zotac-box uses per-user subdirs (ssh/zotac-box/<user>_zotac-box/).
unstow_ssh_overlays() {
  local dir pkg output
  echo "=== Unstowing all SSH overlays ==="
  if [[ ! -d "$DOTFILES/ssh" ]]; then
    echo "  [SKIP]  no ssh/ directory"
    echo ""
    return 0
  fi
  # Flat overlays: ssh/<host>/.ssh/
  for dir in "$DOTFILES"/ssh/*/; do
    [[ -d "$dir.ssh" ]] || continue
    local flat_pkg
    flat_pkg="$(basename "$dir")"
    # Skip zotac-box (handled below as per-user)
    [[ "$flat_pkg" == "zotac-box" ]] && continue
    if $DRY_RUN; then
      echo "  [DRY]   stow --simulate -v -D --dir=ssh $flat_pkg"
      (cd "$DOTFILES" && stow --simulate -v -D --dir=ssh "$flat_pkg") || true
      continue
    fi
    if output=$(cd "$DOTFILES" && stow -D --dir=ssh "$flat_pkg" 2>&1); then
      echo "  [OK]    unstow ssh/$flat_pkg"
    else
      echo "  [WARN]  unstow ssh/$flat_pkg reported issues"
      echo "$output"
    fi
  done
  # Per-user overlays: ssh/zotac-box/<user>_zotac-box/
  if [[ -d "$DOTFILES/ssh/zotac-box" ]]; then
    for dir in "$DOTFILES"/ssh/zotac-box/*/; do
      [[ -d "${dir}.ssh" ]] || continue
      local user_pkg
      user_pkg="$(basename "$dir")"
      if $DRY_RUN; then
        echo "  [DRY]   stow --simulate -v -D --dir=ssh/zotac-box $user_pkg"
        (cd "$DOTFILES" && stow --simulate -v -D --dir=ssh/zotac-box "$user_pkg") || true
        continue
      fi
      if output=$(cd "$DOTFILES" && stow -D --dir=ssh/zotac-box "$user_pkg" 2>&1); then
        echo "  [OK]    unstow ssh/zotac-box/$user_pkg"
      else
        echo "  [WARN]  unstow ssh/zotac-box/$user_pkg reported issues"
        echo "$output"
      fi
    done
  fi
  echo ""
}

stow_selected_packages() {
  local pkg failed=0
  echo "=== Stowing selected packages ==="
  for pkg in "${STOW_LIST[@]}"; do
    run_stow_package "$pkg" || failed=1
  done
  echo ""
  return "$failed"
}

install_xorg_input_config() {
  if $NO_XORG_INPUT; then
    echo "=== Skipping Xorg input config (--no-xorg-input) ==="
    echo ""
    return 0
  fi

  local source="${DOTFILES}/${XORG_INPUT_CONFIG_REL}"
  local target="$XORG_INPUT_CONFIG_TARGET"
  local install_cmd=(install -D -m 0644 "$source" "$target")

  echo "=== Installing Xorg input config ==="

  if [[ ! -f "$source" ]]; then
    echo "  [ERROR] missing source: $source"
    return 1
  fi

  if [[ ! -d /etc/X11 && ! -d /usr/share/X11/xorg.conf.d && ! -d /etc/X11/xorg.conf.d ]]; then
    echo "  [SKIP]  Xorg config directories not found on this host"
    echo ""
    return 0
  fi

  if $DRY_RUN; then
    printf '  [DRY]   sudo '
    printf '%q ' "${install_cmd[@]}"
    printf '\n\n'
    return 0
  fi

  if [[ -f "$target" ]] && cmp -s "$source" "$target"; then
    echo "  [OK]    already current: $target"
    echo ""
    return 0
  fi

  if [[ $EUID -eq 0 ]]; then
    run_cmd "${install_cmd[@]}"
  else
    if ! command -v sudo >/dev/null 2>&1; then
      echo "  [ERROR] sudo is required to install $target"
      return 1
    fi
    run_cmd sudo "${install_cmd[@]}"
  fi

  echo "  [OK]    installed: $target"
  echo ""
}

install_tmux_plugins() {
  if $NO_TMUX; then
    echo "=== Skipping tmux plugins (--no-tmux) ==="
    echo ""
    return 0
  fi

  echo "=== Installing/updating tmux plugins ==="
  if $DRY_RUN; then
    echo "  [DRY]   bash ${DOTFILES}/scripts/install-tmux-plugins.sh"
    echo ""
    return 0
  fi

  bash "${DOTFILES}/scripts/install-tmux-plugins.sh"
  echo ""
}

reload_tmux_if_live() {
  if $NO_TMUX; then
    return 0
  fi
  if [[ -n "${TMUX:-}" ]]; then
    echo "=== Reloading tmux config ==="
    if $DRY_RUN; then
      echo "  [DRY]   tmux source-file ${HOME}/.tmux.conf"
    else
      tmux source-file "${HOME}/.tmux.conf"
      echo "tmux config reloaded."
    fi
    echo ""
  fi
}

main() {
  parse_args "$@"
  detect_host
  select_packages

  print_selection
  echo ""

  if $LIST_ONLY; then
    exit 0
  fi

  if $CHECK_ONLY; then
    preflight
    exit $?
  fi

  if $DRY_RUN; then
    preflight || true
    echo "=== Dry-run deployment plan ==="
    ensure_safety_dirs || true
    unstow_all_packages
    unstow_ssh_overlays
    stow_selected_packages || true
    run_stow_ssh_overlay || true
    install_xorg_input_config
    install_tmux_plugins
    reload_tmux_if_live
    echo "Dry-run complete. No changes were made."
    exit 0
  fi

  preflight
  ensure_safety_dirs
  unstow_all_packages
  unstow_ssh_overlays
  stow_selected_packages
  run_stow_ssh_overlay
  install_xorg_input_config
  install_tmux_plugins
  reload_tmux_if_live

  echo "Done. Dotfiles configured for ${HOST}."
}

main "$@"
