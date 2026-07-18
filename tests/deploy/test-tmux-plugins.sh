#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=tests/deploy/testlib.sh
source "$ROOT/tests/deploy/testlib.sh"

TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT
mkdir -p "$TMPDIR/bin" "$TMPDIR/home/.tmux/plugins/tpm/.git"
CALL_LOG="$TMPDIR/calls.log"
: > "$CALL_LOG"

cat > "$TMPDIR/bin/git" <<'MOCK'
#!/usr/bin/env bash
printf 'git' >> "$CALL_LOG"
printf ' %q' "$@" >> "$CALL_LOG"
printf '\n' >> "$CALL_LOG"
MOCK
chmod +x "$TMPDIR/bin/git"

PATH="$TMPDIR/bin:$PATH" HOME="$TMPDIR/home" CALL_LOG="$CALL_LOG" \
    bash "$ROOT/scripts/install-tmux-plugins.sh" --ensure >/dev/null
assert_text_not_contains "ensure does not pull existing plugin versions" "pull" "$(<"$CALL_LOG")"
assert_text_contains "ensure clones missing plugins" "clone" "$(<"$CALL_LOG")"

: > "$CALL_LOG"
PATH="$TMPDIR/bin:$PATH" HOME="$TMPDIR/home" CALL_LOG="$CALL_LOG" \
    bash "$ROOT/scripts/install-tmux-plugins.sh" --update >/dev/null
assert_text_contains "update explicitly pulls existing plugin versions" "pull" "$(<"$CALL_LOG")"

finish_tests
