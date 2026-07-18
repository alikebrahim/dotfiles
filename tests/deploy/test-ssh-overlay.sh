#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT/tests/deploy/testlib.sh"
source "$ROOT/scripts/lib/common.sh"
source "$ROOT/scripts/lib/ssh-overlay.sh"

TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT
REPO="$TMPDIR/repo"
HOME_DIR="$TMPDIR/home"
BIN="$TMPDIR/bin"
mkdir -p "$REPO/ssh/zotac-box/alikebrahim_zotac-box/.ssh" "$HOME_DIR" "$BIN"
printf 'managed\n' > "$REPO/ssh/zotac-box/alikebrahim_zotac-box/.ssh/config"

cat > "$BIN/stow" <<'MOCK'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$STOW_CALLS"
MOCK
chmod +x "$BIN/stow"
PATH="$BIN:$PATH"
export STOW_CALLS="$TMPDIR/calls"

ssh_overlay_init "$REPO" "$HOME_DIR" "zotac-box/alikebrahim_zotac-box"
assert_eq "nested overlay is discovered" "true" "$(ssh_overlay_exists && printf true || printf false)"
set +e
status="$(ssh_overlay_status)"
status_rc=$?
set -e
assert_eq "unlinked SSH overlay reports drift" "$EXIT_DRIFT" "$status_rc"
assert_text_contains "SSH status identifies component" "SSH overlay" "$status"

ssh_overlay_apply
calls="$(cat "$STOW_CALLS")"
assert_text_contains "SSH apply uses nested overlay directory" "--dir=$REPO/ssh/zotac-box" "$calls"
assert_text_contains "SSH apply uses explicit home target" "--target=$HOME_DIR" "$calls"
assert_text_contains "SSH apply selects only user package" "alikebrahim_zotac-box" "$calls"

finish_tests
