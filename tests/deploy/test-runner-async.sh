#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT/tests/deploy/testlib.sh"
source "$ROOT/scripts/lib/common.sh"
source "$ROOT/scripts/lib/runner.sh"

TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT
USER="runner-async-$$"
runner_init "$TMPDIR/state" test-profile

worker_success() {
    sleep 0.1
    printf 'completed asynchronously\n'
}

runner_start "async-probe" false worker_success
[[ "$RUNNER_PID" =~ ^[0-9]+$ ]] && pass "runner_start exposes worker PID" || fail "runner_start exposes worker PID"
[[ -d "$RUNNER_LAST_RUN_DIR" ]] && pass "runner_start prepares run directory" || fail "runner_start prepares run directory"
runner_wait
wait_rc=$?
assert_eq "runner_wait returns worker result" "0" "$wait_rc"
assert_text_contains "async output is durable" "completed asynchronously" "$(cat "$RUNNER_LAST_LOG")"
assert_text_contains "async metadata is finalized" "exit_code=0" "$(cat "$RUNNER_LAST_RUN_DIR/metadata")"

acquire_lock
lock_rc=$?
release_lock
assert_eq "async wait releases lock" "0" "$lock_rc"

finish_tests
