#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=tests/deploy/testlib.sh
source "$ROOT/tests/deploy/testlib.sh"
# shellcheck source=scripts/lib/common.sh
source "$ROOT/scripts/lib/common.sh"
# shellcheck source=scripts/lib/module-runner.sh
source "$ROOT/scripts/lib/module-runner.sh"

TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

module_runner_init "$ROOT" "$TMPDIR"

# Test dynamic discovery: module_run with a convention-based ID
# should find the module file and function without a case statement.
output="$(module_run system:xorg-libinput status 2>&1)" || true
assert_text_contains "dynamic discovery finds xorg-libinput" "xorg-libinput" "$output"

# Test invalid module ID (no colon)
set +e
module_run invalid-no-colon status 2>&1
rc=$?
set -e
assert_eq "invalid module ID returns BLOCKED" "$EXIT_BLOCKED" "$rc"

# Test unknown module (valid format, no file)
set +e
module_run system:nonexistent status 2>&1
rc=$?
set -e
assert_eq "unknown module returns BLOCKED" "$EXIT_BLOCKED" "$rc"

finish_tests
