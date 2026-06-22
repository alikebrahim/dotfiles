#!/usr/bin/env bash
set -euo pipefail

# Per-host stow dispatcher for the dotfiles repo.
# Detects hostname, unstows all packages (clean slate), then stows only
# the packages appropriate for this host. Installs tmux plugins and
# reloads tmux if a session is live.
#
# Usage:  bash ~/.dotfiles/static/stow-host.sh
# Run AFTER git pull on the dotfiles repo.

DOTFILES="${HOME}/.dotfiles"
cd "$DOTFILES"

# --- Identify host ---------------------------------------------------------
HOST="$(hostnamectl hostname 2>/dev/null || hostname | sed 's/\..*//')"

# --- All known stow packages (for clean unstow) ----------------------------
ALL_PACKAGES=(
  zsh bash git vim nvim delta atuin my-bin apps
  1Password wezterm alacritty posting postman
  awesome awesome_wm_scripts picom dunst rofi polybar themes awesomewm-bin
  quickshell
  tmux
  tmux-remote
  tmux-remote-netmaster tmux-remote-servalws tmux-remote-minisforoum
  tmux-remote-zotac-box tmux-remote-macbook
)

# --- Per-host package selection --------------------------------------------
# Common packages stowed on every host.
COMMON=(
  zsh bash git vim nvim delta my-bin
  tmux-remote
)

# Extra packages per host (appended to COMMON).
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
      1Password wezterm
      awesome awesome_wm_scripts picom dunst rofi polybar themes awesomewm-bin
    )
    ;;
  minisforoum)
    TMUX_OVERLAY="tmux-remote-minisforoum"
    SSH_OVERLAY="minisforoum"
    EXTRA=(1Password wezterm)
    ;;
  zotac-box)
    TMUX_OVERLAY="tmux-remote-zotac-box"
    SSH_OVERLAY="zotac-box"
    ;;
  macbook)
    TMUX_OVERLAY="tmux-remote-macbook"
    SSH_OVERLAY="macbook"
    ;;
  *)
    echo "Warning: unknown host '${HOST}'. Stowing common packages only." >&2
    ;;
esac

# Build the full stow list for this host
STOW_LIST=("${COMMON[@]}")
[[ -n "$TMUX_OVERLAY" ]] && STOW_LIST+=("$TMUX_OVERLAY")
[[ ${#EXTRA[@]} -gt 0 ]] && STOW_LIST+=("${EXTRA[@]}")

echo "Host:    ${HOST}"
echo "Packages: ${STOW_LIST[*]}"
[[ -n "$SSH_OVERLAY" ]] && echo "SSH:     ssh/${SSH_OVERLAY}"
echo ""

# --- 1. Unstow all packages (clean slate) ---------------------------------
echo "=== Unstowing all packages ==="
for pkg in "${ALL_PACKAGES[@]}"; do
  if [[ -d "$pkg" ]]; then
    stow -D "$pkg" 2>/dev/null || true
  fi
done
echo ""

# --- 2. Stow packages for this host ---------------------------------------
echo "=== Stowing packages ==="
for pkg in "${STOW_LIST[@]}"; do
  if [[ ! -d "$pkg" ]]; then
    echo "  [SKIP]  $pkg (directory not found in dotfiles)"
    continue
  fi
  # Safety: prevent my-bin from tree-folding ~/.local (Stow 2.3.1 has no --no-folding)
  if [[ "$pkg" == "my-bin" ]]; then
    if [[ -L "$HOME/.local" ]]; then
      echo "  [SKIP]  my-bin (~/.local is tree-folded — run check-fold.sh --fix)"
      continue
    fi
    mkdir -p "$HOME/.local/state"
  fi
  if stow -R "$pkg" 2>&1; then
    echo "  [OK]    $pkg"
  else
    echo "  [ERROR] $pkg — check for conflicts (real files in \$HOME)"
  fi
done
echo ""

# --- 2a. Stow per-host SSH config (ssh/HOST via --dir) --------------------
if [[ -n "$SSH_OVERLAY" ]]; then
  if [[ -d "ssh/$SSH_OVERLAY" ]]; then
    echo "=== Stowing SSH config (ssh/${SSH_OVERLAY}) ==="
    if stow -R --dir=ssh "$SSH_OVERLAY" 2>&1; then
      echo "  [OK]    ssh/${SSH_OVERLAY}"
    else
      echo "  [ERROR] ssh/${SSH_OVERLAY} — check for conflicts (real files in ~/.ssh/)"
    fi
  else
    echo "  [SKIP]  ssh/${SSH_OVERLAY} (directory not found)"
  fi
  echo ""
fi

# --- 3. Remove any real (non-symlink) tmux theme.conf, then re-stow overlay
if [[ -n "$TMUX_OVERLAY" ]]; then
  if [[ -f "${HOME}/.tmux/theme.conf" && ! -L "${HOME}/.tmux/theme.conf" ]]; then
    echo "Removing local ~/.tmux/theme.conf (replacing with symlink)..."
    rm -f "${HOME}/.tmux/theme.conf"
    stow -R "$TMUX_OVERLAY"
  fi
fi

# --- 4. Clean broken tmux plugin symlinks and install real plugins ---------
echo "=== Installing tmux plugins ==="
rm -rf "${HOME}/.tmux/plugins"
bash "${DOTFILES}/static/install-tmux-plugins.sh"
echo ""

# --- 5. Reload tmux config if session is live ------------------------------
if [[ -n "${TMUX:-}" ]]; then
  echo "=== Reloading tmux config ==="
  tmux source-file "${HOME}/.tmux.conf"
  echo "tmux config reloaded."
fi

echo ""
echo "Done. Dotfiles configured for ${HOST}."
