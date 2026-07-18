#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT/tests/deploy/testlib.sh"
source "$ROOT/scripts/lib/common.sh"
source "$ROOT/scripts/lib/runner.sh"

TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT
STATE="$TMPDIR/state"
USER="runner-test-$$"

runner_init "$STATE" "test-profile"
[[ ! -e "$STATE" ]] && pass "runner initialization is read-only" || fail "runner initialization is read-only"
worker_failure() {
    printf 'normal output\n'
    printf 'diagnostic output\n' >&2
    return 7
}

set +e
runner_run "failure-probe" false worker_failure
run_rc=$?
set -e

assert_eq "runner preserves worker exit code" "7" "$run_rc"
assert_file_exists "runner creates a durable log" "$RUNNER_LAST_LOG"
log_output="$(cat "$RUNNER_LAST_LOG")"
assert_text_contains "runner captures stdout" "normal output" "$log_output"
assert_text_contains "runner captures stderr" "diagnostic output" "$log_output"
assert_file_exists "runner records metadata" "$RUNNER_LAST_RUN_DIR/metadata"
metadata="$(cat "$RUNNER_LAST_RUN_DIR/metadata")"
assert_text_contains "metadata records failure result" "exit_code=7" "$metadata"

# A failed worker must not leave the process lock held.
acquire_lock
lock_rc=$?
release_lock
assert_eq "runner always releases lock" "0" "$lock_rc"

finish_tests
