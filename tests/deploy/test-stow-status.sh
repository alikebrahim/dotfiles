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
mkdir -p "$REPO/pkg/.config/app" "$REPO/pkg/.cache/ignored" \
    "$REPO/pkg/docs/nested" "$HOME_DIR/.config/app" "$BIN"
printf 'one\n' > "$REPO/pkg/.config/app/one"
printf 'two\n' > "$REPO/pkg/.config/app/two"
printf 'skip\n' > "$REPO/pkg/.cache/ignored/secret"
printf 'documentation\n' > "$REPO/pkg/docs/nested/reference.md"
cat > "$REPO/pkg/.stow-local-ignore" <<'EOF'
.cache/ignored
^/docs(/|$)
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
managed="$(stow_package_managed_files pkg)"
assert_text_not_contains "anchored ignored directory is excluded" "docs/nested/reference.md" "$managed"

ln -s "$REPO/pkg/.config/app/two" "$HOME_DIR/.config/app/two"
current="$(stow_package_status pkg)"
assert_text_contains "fully linked package reports current" "$STATUS_CURRENT" "$current"
assert_text_contains "full status reports all managed targets" "2/2" "$current"

# A source move/removal must make package-owned dangling links visible as drift
# so desired-state apply actually restows and removes them.
mv "$REPO/pkg/.config/app/one" "$REPO/pkg/.config/app/one-retired"
set +e
orphaned="$(stow_package_status pkg)"
orphaned_rc=$?
set -e
assert_eq "package-owned dangling link reports drift" "$EXIT_DRIFT" "$orphaned_rc"
assert_text_contains "orphan status reports the removed source link" "1 orphaned links" "$orphaned"
orphan_cleanup="$(stow_remove_orphaned_links pkg)"
assert_text_contains "orphan cleanup reports the exact removed link" ".config/app/one" "$orphan_cleanup"
if [[ ! -L "$HOME_DIR/.config/app/one" ]]; then
    pass "orphan cleanup removes only the dangling package link"
else
    fail "orphan cleanup removes only the dangling package link"
fi
mv "$REPO/pkg/.config/app/one-retired" "$REPO/pkg/.config/app/one"
ln -s "$REPO/pkg/.config/app/one" "$HOME_DIR/.config/app/one"

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

# A deep .local/share package path must not make orphan detection walk the
# entire shared data root, which may contain large unrelated container storage.
mkdir -p "$REPO/pkg/.local/share/icons" "$HOME_DIR/.local/share/icons"
printf 'keep\n' > "$REPO/pkg/.local/share/icons/keep.png"
printf 'retire\n' > "$REPO/pkg/.local/share/icons/retire.png"
ln -s "$REPO/pkg/.local/share/icons/keep.png" "$HOME_DIR/.local/share/icons/keep.png"
ln -s "$REPO/pkg/.local/share/icons/retire.png" "$HOME_DIR/.local/share/icons/retire.png"
mv "$REPO/pkg/.local/share/icons/retire.png" "$TMPDIR/retire.png"

SYSTEM_FIND="$(command -v find)"
export FORBIDDEN_FIND_ROOT="$HOME_DIR/.local/share"
export SYSTEM_FIND
cat > "$BIN/find" <<'MOCK'
#!/usr/bin/env bash
if [[ "${1:-}" == "$FORBIDDEN_FIND_ROOT" ]]; then
    printf 'unexpected broad scan: %s\n' "$1" >&2
    exit 96
fi
exec "$SYSTEM_FIND" "$@"
MOCK
chmod +x "$BIN/find"

deep_orphans="$(stow_package_orphaned_links pkg)"
assert_text_contains "deep orphan scan finds the retired icon" ".local/share/icons/retire.png" "$deep_orphans"

finish_tests
