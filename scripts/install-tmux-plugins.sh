#!/usr/bin/env bash
set -euo pipefail

# Provision tmux plugins directly into ~/.tmux/plugins/.
# Run AFTER stowing tmux-remote. --ensure is idempotent and never updates
# third-party checkouts; --update is the explicit mutable operation.
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

MODE="ensure"
case "${1:---ensure}" in
  --ensure)
    ;;
  --update)
    MODE="update"
    ;;
  --help|-h)
    cat <<'EOF'
Usage: install-tmux-plugins.sh [--ensure|--update]

  --ensure  Clone missing plugins only (default; never pulls existing checkouts).
  --update  Fast-forward existing plugin checkouts and clone missing plugins.
EOF
    exit 0
    ;;
  *)
    printf 'Unknown option: %s\n' "$1" >&2
    exit 2
    ;;
esac

mkdir -p "$PLUGINS_DIR"

for entry in "${PLUGINS[@]}"; do
  name="${entry%%|*}"
  url="${entry##*|}"
  dest="${PLUGINS_DIR}/${name}"

  if [[ -d "${dest}/.git" ]]; then
    if [[ "$MODE" == update ]]; then
      echo "Updating ${name}..."
      git -C "$dest" pull --quiet --ff-only
    else
      echo "Current ${name} (left unchanged)."
    fi
  else
    if [[ -d "$dest" ]]; then
      printf 'BLOCKED %s exists but is not a Git checkout: %s\n' "$name" "$dest" >&2
      exit 2
    fi
    echo "Cloning ${name}..."
    git clone --quiet --depth=1 "$url" "$dest"
  fi
done

echo "Done. tmux plugins ${MODE}d in ${PLUGINS_DIR}"
