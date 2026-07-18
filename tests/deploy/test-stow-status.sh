#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT/tests/deploy/testlib.sh"
source "$ROOT/scripts/lib/common.sh"
source "$ROOT/scripts/lib/stow.sh"

TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT
REPO="$TMPDIR/repo"
HOME_DIR="$TMPDIR/home"
BIN="$TMPDIR/bin"
mkdir -p "$REPO/pkg/.config/app" "$REPO/pkg/.local/share/ignored" "$HOME_DIR/.config/app" "$BIN"
printf 'one\n' > "$REPO/pkg/.config/app/one"
printf 'two\n' > "$REPO/pkg/.config/app/two"
printf 'skip\n' > "$REPO/pkg/.local/share/ignored/secret"
cat > "$REPO/pkg/.stow-local-ignore" <<'EOF'
.local/share
EOF
ln -s "$REPO/pkg/.config/app/one" "$HOME_DIR/.config/app/one"

stow_init "$REPO" "$HOME_DIR"
set +e
partial="$(stow_package_status pkg)"
partial_rc=$?
set -e
assert_eq "partially linked package reports drift" "$EXIT_DRIFT" "$partial_rc"
assert_text_contains "partial status explains linked count" "1/2" "$partial"
assert_text_not_contains "ignored files are excluded from managed totals" "1/3" "$partial"

ln -s "$REPO/pkg/.config/app/two" "$HOME_DIR/.config/app/two"
current="$(stow_package_status pkg)"
assert_text_contains "fully linked package reports current" "$STATUS_CURRENT" "$current"
assert_text_contains "full status reports all managed targets" "2/2" "$current"

# Real file conflict inventory
rm -f "$HOME_DIR/.config/app/two"
printf 'real\n' > "$HOME_DIR/.config/app/two"
conflicts="$(stow_package_conflict_report pkg || true)"
assert_text_contains "conflict report names real-file blockers" "real file blocks Stow" "$conflicts"
assert_text_contains "conflict report includes relative path" ".config/app/two" "$conflicts"

cat > "$BIN/stow" <<'MOCK'
#!/usr/bin/env bash
printf 'UNLINK: noisy\n' >&2
printf 'LINK: noisy\n' >&2
printf 'WARNING: in simulation mode\n' >&2
MOCK
chmod +x "$BIN/stow"
PATH="$BIN:$PATH"
STOW_VERBOSE=false
quiet_plan="$(stow_simulate_package pkg 2>&1)"
assert_text_not_contains "default simulation hides LINK chatter" "LINK:" "$quiet_plan"
assert_text_not_contains "default simulation hides UNLINK chatter" "UNLINK:" "$quiet_plan"

STOW_VERBOSE=true
verbose_plan="$(stow_simulate_package pkg 2>&1)"
assert_text_contains "verbose simulation exposes detail" "LINK: noisy" "$verbose_plan"

finish_tests
