#!/usr/bin/env bash
set -euo pipefail

# check-fold.sh — Detect and fix ~/.local tree folding across axmiNet hosts
#
# GNU Stow 2.3.1 "tree-folds" directories when the target contains only
# content from one package. If ~/.local has only my-bin content, Stow
# replaces it with a single symlink:
#   ~/.local -> .dotfiles/my-bin/.local
#
# This traps per-host runtime data (npm, nvim, uv, zinit, etc.) inside
# the Syncthing-synced dotfiles repo. Deleting my-bin/.local/share from
# the repo would propagate the deletion via Syncthing and destroy that
# data on every folded host.
#
# This script checks every host for folding at ~/.local and its subdirs,
# reports status, and optionally fixes folded hosts by unstowing my-bin
# and restoring ~/.local as a real directory with data preserved.
#
# Usage:
#   bash check-fold.sh           # check only, report status
#   bash check-fold.sh --fix     # check + fix folded hosts (with confirmation)

FIX=false
[[ "${1:-}" == "--fix" ]] && FIX=true

LOCAL_HOST="$(hostnamectl hostname 2>/dev/null || hostname | sed 's/\..*//')"
HOSTS=("netmaster" "servalws" "minisforoum" "zotac-box" "macbook")
FOLDED=()
PARTIAL=()
UNREACHABLE=()

echo "========================================"
echo "  ~/.local Tree Folding Check"
echo "========================================"
echo ""

# --- Check script (runs on each host via bash -s) ---
CHECK_SCRIPT=$(mktemp)
cat > "$CHECK_SCRIPT" <<'CHECK'
if [ -L "$HOME/.local" ]; then
  printf "FOLDED|%s\n" "$(readlink "$HOME/.local")"
elif [ -d "$HOME/.local" ]; then
  issues=""
  for d in bin share state lib; do
    if [ -L "$HOME/.local/$d" ]; then
      issues="${issues}${d}->$(readlink "$HOME/.local/$d");"
    fi
  done
  if [ -n "$issues" ]; then
    printf "PARTIAL|%s\n" "$issues"
  else
    sizes=""
    for d in bin share state lib; do
      if [ -d "$HOME/.local/$d" ]; then
        sz=$(du -sh "$HOME/.local/$d" 2>/dev/null | cut -f1)
        sizes="${sizes}${d}:${sz} "
      fi
    done
    printf "SAFE|%s\n" "$sizes"
  fi
else
  printf "MISSING|\n"
fi
CHECK

# --- Fix script (runs on a folded host via bash -s) ---
FIX_SCRIPT=$(mktemp)
cat > "$FIX_SCRIPT" <<'FIX'
set -euo pipefail
df="$HOME/.dotfiles"
ts=$(date +%Y%m%d-%H%M%S)

if [ ! -d "$df/my-bin" ]; then
  echo "  ERROR: $df/my-bin not found — cannot fix"
  exit 1
fi

# --- Full fold: ~/.local itself is a symlink ---
if [ -L "$HOME/.local" ]; then
  echo "  Full tree fold: ~/.local -> $(readlink "$HOME/.local")"
  echo ""
  echo "  Step 1: Backing up data from repo..."
  backup="/tmp/local-backup-$ts"
  cp -a "$df/my-bin/.local" "$backup"
  echo "    Backup: $backup ($(du -sh "$backup" | cut -f1))"

  echo "  Step 2: Breaking fold (unstow my-bin)..."
  cd "$df"
  stow -D my-bin 2>/dev/null || true
  # Fallback: remove symlink directly if stow didn't
  if [ -L "$HOME/.local" ]; then
    echo "    stow -D didn't remove it, removing symlink directly..."
    rm "$HOME/.local"
  fi

  echo "  Step 3: Creating real ~/.local directory..."
  mkdir -p "$HOME/.local"

  echo "  Step 4: Restoring data from backup..."
  cp -a "$backup/." "$HOME/.local/"

  echo "  Step 5: Verifying..."
  if [ -L "$HOME/.local" ]; then
    echo "    FAILED — ~/.local is still a symlink"
    echo "    Manual fix needed. Backup at: $backup"
  else
    echo "    OK — ~/.local is now a real directory"
    for d in bin share state lib; do
      if [ -d "$HOME/.local/$d" ]; then
        echo "    $d: $(du -sh "$HOME/.local/$d" 2>/dev/null | cut -f1)"
      fi
    done
  fi
  echo ""
  echo "  Backup preserved at: $backup"
  echo "  Remove it after verifying: rm -rf $backup"

# --- Partial fold: a subdir is a symlink ---
elif [ -L "$HOME/.local/share" ] || [ -L "$HOME/.local/bin" ] || \
     [ -L "$HOME/.local/state" ] || [ -L "$HOME/.local/lib" ]; then

  for d in share bin state lib; do
    if [ ! -L "$HOME/.local/$d" ]; then
      continue
    fi

    echo "  Partial fold: ~/.local/$d -> $(readlink "$HOME/.local/$d")"
    echo ""

    # Check if the symlink target is inside the repo
    target=$(readlink "$HOME/.local/$d")
    case "$target" in
      */.dotfiles/*|.dotfiles/*)
        echo "  Step 1: Backing up $d from repo..."
        backup="/tmp/local-${d}-backup-$ts"
        cp -a "$df/my-bin/.local/$d" "$backup"
        echo "    Backup: $backup ($(du -sh "$backup" | cut -f1))"
        ;;
      *)
        echo "  WARNING: symlink target ($target) is not in .dotfiles"
        echo "  Backing up via symlink target..."
        backup="/tmp/local-${d}-backup-$ts"
        cp -aL "$HOME/.local/$d" "$backup"
        echo "    Backup: $backup ($(du -sh "$backup" | cut -f1))"
        ;;
    esac

    echo "  Step 2: Removing symlink..."
    rm "$HOME/.local/$d"

    echo "  Step 3: Creating real directory..."
    mkdir -p "$HOME/.local/$d"

    echo "  Step 4: Restoring data..."
    cp -a "$backup/." "$HOME/.local/$d/"

    echo "  Step 5: Verifying..."
    if [ -L "$HOME/.local/$d" ]; then
      echo "    FAILED — ~/.local/$d is still a symlink"
    else
      echo "    OK — ~/.local/$d is now a real directory"
      echo "    Size: $(du -sh "$HOME/.local/$d" 2>/dev/null | cut -f1)"
    fi
    echo ""
    echo "  Backup preserved at: $backup"
    echo "  Remove it after verifying: rm -rf $backup"
    echo ""
  done
else
  echo "  Nothing to fix — ~/.local is already a real directory"
fi
FIX

# Cleanup temp files on exit
trap 'rm -f "$CHECK_SCRIPT" "$FIX_SCRIPT"' EXIT

# --- Main loop: check each host ---
for host in "${HOSTS[@]}"; do
  printf -- "--- %s ---\n" "$host"

  if [[ "$host" == "$LOCAL_HOST" ]]; then
    result=$(bash "$CHECK_SCRIPT" 2>/dev/null)
  else
    result=$(ssh -o BatchMode=yes -o ConnectTimeout=5 "$host" 'bash -s' < "$CHECK_SCRIPT" 2>/dev/null) || result="UNREACHABLE|"
  fi

  status="${result%%|*}"
  detail="${result#*|}"

  case "$status" in
    FOLDED)
      echo "  *** TREE-FOLDED ***"
      echo "  ~/.local -> $detail"
      echo "  ALL per-host data trapped in repo!"
      FOLDED+=("$host")
      ;;
    PARTIAL)
      echo "  PARTIAL FOLD (some subdirs are symlinks)"
      echo "$detail" | tr ';' '\n' | grep -v '^$' | sed 's/^/    /'
      echo "  Some per-host data may be trapped in repo"
      PARTIAL+=("$host")
      ;;
    SAFE)
      echo "  SAFE — all real directories"
      echo "$detail" | tr ' ' '\n' | grep -v '^$' | sed 's/^/    /'
      ;;
    MISSING)
      echo "  ~/.local does not exist"
      ;;
    UNREACHABLE)
      echo "  UNREACHABLE (SSH failed)"
      UNREACHABLE+=("$host")
      ;;
  esac
  echo ""
done

# --- Summary ---
echo "========================================"
echo "  SUMMARY"
echo "========================================"
echo "  Hosts checked:  ${#HOSTS[@]}"
echo "  Safe:           $(( ${#HOSTS[@]} - ${#FOLDED[@]} - ${#PARTIAL[@]} - ${#UNREACHABLE[@]} ))"
echo "  Folded:         ${#FOLDED[@]}"
echo "  Partial:        ${#PARTIAL[@]}"
echo "  Unreachable:    ${#UNREACHABLE[@]}"
echo ""

if [[ ${#UNREACHABLE[@]} -gt 0 ]]; then
  echo "  UNREACHABLE hosts:"
  for h in "${UNREACHABLE[@]}"; do
    echo "    - $h"
  done
  echo ""
  echo "  WARNING: Cannot verify unreachable hosts."
  echo "  Do NOT delete my-bin/.local/share from repo until all hosts checked."
  echo ""
fi

ALL_PROBLEM=( "${FOLDED[@]}" "${PARTIAL[@]}" )

if [[ ${#ALL_PROBLEM[@]} -eq 0 && ${#UNREACHABLE[@]} -eq 0 ]]; then
  echo "  All hosts SAFE. Ready to proceed with repo cleanup."
elif [[ ${#ALL_PROBLEM[@]} -eq 0 ]]; then
  echo "  No folded hosts among reachable hosts."
  echo "  Verify unreachable hosts before proceeding."
else
  echo "  PROBLEM HOSTS:"
  for h in "${FOLDED[@]}"; do
    echo "    - $h (FOLDED)"
  done
  for h in "${PARTIAL[@]}"; do
    echo "    - $h (PARTIAL)"
  done
  echo ""
  if $FIX; then
    for host in "${ALL_PROBLEM[@]}"; do
      read -rp "Fix $host now? (y/N) " confirm
      if [[ "$confirm" =~ ^[Yy]$ ]]; then
        echo ""
        echo "  Fixing $host..."
        echo ""
        if [[ "$host" == "$LOCAL_HOST" ]]; then
          bash "$FIX_SCRIPT"
        else
          ssh -o BatchMode=yes -o ConnectTimeout=10 "$host" 'bash -s' < "$FIX_SCRIPT"
        fi
        echo ""
      else
        echo "  Skipped $host"
        echo ""
      fi
    done
    echo "  Fix pass complete. Re-run without --fix to verify all hosts are safe."
  else
    echo "  Run: bash check-fold.sh --fix"
    echo ""
    echo "  Do NOT delete my-bin/.local/share from repo until all hosts fixed."
  fi
fi
echo ""
