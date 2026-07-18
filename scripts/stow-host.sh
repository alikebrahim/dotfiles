#!/usr/bin/env bash
set -euo pipefail

# Compatibility wrapper. configure-host.sh is the sole deployment engine.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIGURE_HOST="$SCRIPT_DIR/configure-host.sh"
DOTFILES="${DOTFILES:-$(cd "$SCRIPT_DIR/.." && pwd)}"
COMMAND="apply"
HOST_ARGS=()
FORWARD_ARGS=(--scope stow)

usage() {
    cat <<'EOF'
stow-host.sh compatibility wrapper

Use scripts/configure-host.sh for new workflows.

Legacy mappings:
  --list             -> configure-host status --scope stow
  --check            -> configure-host check --scope stow
  --dry-run          -> configure-host plan --scope stow
  --no-ssh           -> --no-ssh-overlay
  --no-tmux          -> no-op; plugin updates are now explicit
  --no-xorg-input    -> no-op; this wrapper is Stow-only
  --host HOST        -> --host HOST
  --dotfiles DIR     -> DOTFILES=DIR
  --verbose          -> --verbose
  --yes              -> --yes

The unsafe legacy --adopt and --force modes are not supported.
EOF
}

while (( $# > 0 )); do
    case "$1" in
        -h|--help) usage; exit 0 ;;
        -l|--list) COMMAND=status; shift ;;
        -c|--check) COMMAND=check; shift ;;
        -n|--dry-run) COMMAND=plan; shift ;;
        --host)
            [[ $# -ge 2 ]] || { printf 'ERROR: --host requires an argument\n' >&2; exit 2; }
            HOST_ARGS=(--host "$2"); shift 2 ;;
        --dotfiles)
            [[ $# -ge 2 ]] || { printf 'ERROR: --dotfiles requires an argument\n' >&2; exit 2; }
            DOTFILES="$2"; CONFIGURE_HOST="$DOTFILES/scripts/configure-host.sh"; shift 2 ;;
        -v|--verbose) FORWARD_ARGS+=(--verbose); shift ;;
        --yes) FORWARD_ARGS+=(--yes); shift ;;
        --no-ssh) FORWARD_ARGS+=(--no-ssh-overlay); shift ;;
        --no-tmux|--no-xorg-input)
            printf 'NOTE: %s is a no-op in the Stow-only compatibility wrapper.\n' "$1" >&2
            shift
            ;;
        --adopt|--force)
            printf 'ERROR: %s is not supported by the safe compatibility wrapper.\n' "$1" >&2
            exit 2
            ;;
        *)
            printf 'ERROR: unsupported legacy option: %s\n' "$1" >&2
            exit 2
            ;;
    esac
done

[[ -f "$CONFIGURE_HOST" ]] || { printf 'ERROR: configure-host entrypoint is missing: %s\n' "$CONFIGURE_HOST" >&2; exit 2; }
printf 'NOTE: stow-host.sh is a compatibility wrapper; use configure-host.sh directly.\n' >&2
DOTFILES="$DOTFILES" exec bash "$CONFIGURE_HOST" "$COMMAND" "${HOST_ARGS[@]}" "${FORWARD_ARGS[@]}"
