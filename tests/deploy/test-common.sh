#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=tests/deploy/testlib.sh
source "$ROOT/tests/deploy/testlib.sh"
# shellcheck source=scripts/lib/common.sh
source "$ROOT/scripts/lib/common.sh"

# Test exit code constants
assert_eq "EXIT_OK is 0" "0" "$EXIT_OK"
assert_eq "EXIT_DRIFT is 1" "1" "$EXIT_DRIFT"
assert_eq "EXIT_BLOCKED is 2" "2" "$EXIT_BLOCKED"
assert_eq "EXIT_INTERNAL is 3" "3" "$EXIT_INTERNAL"

# Test status constants
assert_eq "STATUS_CURRENT" "CURRENT" "$STATUS_CURRENT"
assert_eq "STATUS_ABSENT" "ABSENT" "$STATUS_ABSENT"
assert_eq "STATUS_DRIFT" "DRIFT" "$STATUS_DRIFT"
assert_eq "STATUS_BLOCKED" "BLOCKED" "$STATUS_BLOCKED"
assert_eq "STATUS_CHANGED" "CHANGED" "$STATUS_CHANGED"
assert_eq "STATUS_SKIP" "SKIP" "$STATUS_SKIP"

# Test that sourcing common.sh twice does not fail
(
    source "$ROOT/scripts/lib/common.sh"
    source "$ROOT/scripts/lib/common.sh"
) 2>/dev/null
assert_eq "double-source common.sh does not error" "0" "$?"

# Test acquire_lock / release_lock
source "$ROOT/scripts/lib/common.sh"
acquire_lock
assert_eq "acquire_lock succeeds" "0" "$?"
lock_path="$_LOCK_FILE"
set +e
(source "$ROOT/scripts/lib/common.sh"; acquire_lock) >/dev/null 2>&1
contention_rc=$?
set -e
assert_eq "concurrent acquire is blocked" "$EXIT_BLOCKED" "$contention_rc"
release_lock
assert_eq "release_lock succeeds" "0" "$?"
[[ -f "$lock_path" ]] && pass "release preserves stable lock inode" || fail "release preserves stable lock inode"
acquire_lock
reacquire_rc=$?
release_lock
assert_eq "released lock can be reacquired" "0" "$reacquire_rc"

finish_tests
