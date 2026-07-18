#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT/tests/deploy/testlib.sh"
source "$ROOT/scripts/lib/ui-gum.sh"

TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT
mkdir -p "$TMPDIR/bin"
printf '#!/usr/bin/env bash\nexit 0\n' > "$TMPDIR/bin/gum"
printf '#!/usr/bin/env bash\nexit 0\n' > "$TMPDIR/bin/less"
chmod +x "$TMPDIR/bin/gum" "$TMPDIR/bin/less"
PATH="$TMPDIR/bin:$PATH"

ui_has_tty() { return 0; }
NO_COLOR=1
UI_DISABLED=false
if ui_should_use_gum; then
    pass "NO_COLOR preserves the interactive UI"
else
    fail "NO_COLOR preserves the interactive UI"
fi
if ui_colors_enabled; then
    fail "NO_COLOR disables only color styling"
else
    pass "NO_COLOR disables only color styling"
fi
unset NO_COLOR

COLUMNS=40 LINES=20
assert_eq "small terminal content width is responsive" "36" "$(ui_content_width)"
assert_eq "small terminal list height is responsive" "12" "$(ui_list_height 100)"
assert_eq "less is selected for man-style pager keys" "less" "$(ui_pager_backend)"

ui_init "$ROOT" orange-gas-plasma
assert_eq "orange muted text is readable" "#A98762" "$UI_MUTED"
ui_init "$ROOT" amber-crt
assert_eq "amber muted text is readable" "#A88758" "$UI_MUTED"
ui_init "$ROOT" green-phosphor
assert_eq "green muted text is readable" "#65946F" "$UI_MUTED"

finish_tests
