#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT/tests/deploy/testlib.sh"
source "$ROOT/scripts/lib/session-ui.sh"

TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT
CALLS="$TMPDIR/calls"
CONFIG_SELECTED_TOOLS=()
CONFIG_SELECTED_STOW=()
CONFIG_SELECTED_MODULES=()
ui_should_use_gum() { return 0; }
ui_session_init() { :; }
ui_clear() { :; }
ui_header() { :; }
ui_footer() { :; }
session_dashboard() { :; }
ui_choose() { printf 'choose\n' >> "$CALLS"; return 1; }

session_run
assert_eq "Esc from main menu quits instead of redrawing" "1" "$(wc -l < "$CALLS")"

: > "$CALLS"
session_customize
assert_eq "Esc from nested window returns to parent" "1" "$(wc -l < "$CALLS")"

finish_tests
