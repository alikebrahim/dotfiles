#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT/tests/deploy/testlib.sh"
source "$ROOT/scripts/lib/common.sh"

set +e
plan="$(bash "$ROOT/scripts/stow-host.sh" --dry-run --host servalws --no-ssh --dotfiles "$ROOT" 2>&1)"
plan_rc=$?
set -e
assert_eq "legacy dry-run delegates successfully" "0" "$plan_rc"
assert_text_contains "legacy wrapper announces migration" "compatibility wrapper" "$plan"
assert_text_contains "legacy dry-run uses v3 plan" "CONFIGURE-HOST PLAN" "$plan"
assert_text_not_contains "legacy --no-ssh excludes SSH component" "SSH configuration" "$plan"

set +e
unsafe="$(bash "$ROOT/scripts/stow-host.sh" --adopt 2>&1)"
unsafe_rc=$?
set -e
assert_eq "legacy adopt is rejected" "$EXIT_BLOCKED" "$unsafe_rc"
assert_text_contains "adopt refusal explains safety" "not supported" "$unsafe"

finish_tests
