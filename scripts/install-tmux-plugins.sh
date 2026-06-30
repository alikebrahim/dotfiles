#!/usr/bin/env bash
set -euo pipefail

# Install tmux plugins directly into ~/.tmux/plugins/
# Run AFTER stowing tmux-remote. This script is idempotent.
#
# Plugins are excluded from stow via .stow-local-ignore so they are
# cloned per-host rather than symlinked from the dotfiles repo.

PLUGINS_DIR="${HOME}/.tmux/plugins"

# name|github-url — order matters only for readability; tpm listed first.
PLUGINS=(
  "tpm|https://github.com/tmux-plugins/tpm"
  "tmux-sensible|https://github.com/tmux-plugins/tmux-sensible"
  "tmux-resurrect|https://github.com/tmux-plugins/tmux-resurrect"
  "tmux-continuum|https://github.com/tmux-plugins/tmux-continuum"
  "tmux-fzf|https://github.com/sainnhe/tmux-fzf"
)

mkdir -p "$PLUGINS_DIR"

for entry in "${PLUGINS[@]}"; do
  name="${entry%%|*}"
  url="${entry##*|}"
  dest="${PLUGINS_DIR}/${name}"

  if [[ -d "${dest}/.git" ]]; then
    echo "Updating ${name}..."
    git -C "$dest" pull --quiet --ff-only
  else
    if [[ -d "$dest" ]]; then
      echo "Removing stale ${name} (not a git repo)..."
      rm -rf "$dest"
    fi
    echo "Cloning ${name}..."
    git clone --quiet --depth=1 "$url" "$dest"
  fi
done

echo "Done. tmux plugins installed to ${PLUGINS_DIR}"
