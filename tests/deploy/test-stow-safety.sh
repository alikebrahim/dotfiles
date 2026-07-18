#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=tests/deploy/testlib.sh
source "$ROOT/tests/deploy/testlib.sh"
# shellcheck source=scripts/lib/common.sh
source "$ROOT/scripts/lib/common.sh"
# shellcheck source=scripts/lib/stow.sh
source "$ROOT/scripts/lib/stow.sh"

TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT
mkdir -p "$TMPDIR/repo/pkg-a/.config/pkg-a" "$TMPDIR/home/.local/state" "$TMPDIR/home/.local/share" "$TMPDIR/home/.tmux" "$TMPDIR/bin"
CALL_LOG="$TMPDIR/calls.log"
: > "$CALL_LOG"

cat > "$TMPDIR/bin/stow" <<'MOCK'
#!/usr/bin/env bash
printf 'stow' >> "$CALL_LOG"
printf ' %q' "$@" >> "$CALL_LOG"
printf '\n' >> "$CALL_LOG"
if [[ " $* " == *" --simulate "* ]]; then
    printf 'NOISY SIMULATION DETAIL\n'
fi
MOCK
chmod +x "$TMPDIR/bin/stow"

PATH="$TMPDIR/bin:$PATH"
export CALL_LOG
stow_init "$TMPDIR/repo" "$TMPDIR/home"

plan_output="$(stow_plan_packages pkg-a)"
assert_text_contains "Stow plan names the selected package" "pkg-a" "$plan_output"
assert_text_not_contains "Stow plan suppresses simulated link churn by default" "NOISY SIMULATION DETAIL" "$plan_output"
assert_text_not_contains "Stow plan never prunes" "-D" "$(<"$CALL_LOG")"
assert_text_contains "Stow plan simulates a restow" "--simulate" "$(<"$CALL_LOG")"
assert_text_contains "Stow plan uses restow" "-R" "$(<"$CALL_LOG")"

: > "$CALL_LOG"
stow_apply_packages pkg-a >/dev/null
assert_text_contains "normal Stow apply uses restow" "-R" "$(<"$CALL_LOG")"
assert_text_not_contains "normal Stow apply never unstows packages" "-D" "$(<"$CALL_LOG")"
assert_text_contains "Stow commands use an explicit target" "--target" "$(<"$CALL_LOG")"

: > "$CALL_LOG"
stow_prune_packages pkg-a >/dev/null
assert_text_contains "explicit prune is the only operation that unstows" "-D" "$(<"$CALL_LOG")"

finish_tests
