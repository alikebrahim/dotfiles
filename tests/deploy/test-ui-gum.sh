#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=tests/deploy/testlib.sh
source "$ROOT/tests/deploy/testlib.sh"
# shellcheck source=scripts/lib/ui-gum.sh
source "$ROOT/scripts/lib/ui-gum.sh"

ui_init "$ROOT" "orange-gas-plasma"
assert_eq "orange gas plasma uses the tmux background" "#262626" "$UI_BG"
assert_eq "orange gas plasma uses the active tmux orange" "#FC531D" "$UI_ACTIVE"
assert_eq "orange gas plasma uses the tmux foreground" "#FFCB83" "$UI_FG"

if ui_should_use_gum; then
    fail "non-TTY test execution never launches Gum"
else
    pass "non-TTY test execution never launches Gum"
fi

ui_init "$ROOT" "unknown-theme"
assert_eq "unknown themes fall back to orange gas plasma" "orange-gas-plasma" "$UI_THEME"

finish_tests
