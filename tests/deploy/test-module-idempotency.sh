#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=tests/deploy/testlib.sh
source "$ROOT/tests/deploy/testlib.sh"
# shellcheck source=scripts/lib/module-runner.sh
source "$ROOT/scripts/lib/module-runner.sh"

TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT
SYSTEM_ROOT="$TMPDIR/system-root"

module_runner_init "$ROOT" "$SYSTEM_ROOT"

assert_file_exists "Ly configuration source is versioned" "$ROOT/scripts/system/ly/config.ini"
assert_file_exists "Ly palette startup script is versioned" "$ROOT/scripts/system/ly/startup.sh"
assert_file_exists "Ly custom DUR animation is versioned" "$ROOT/scripts/system/ly/animations/cosmic-gravity-monitor-16c-240x67.dur"
assert_file_exists "new Xorg source is versioned" "$ROOT/scripts/system/xorg-libinput/40-libinput-natural-scrolling.conf"
assert_file_exists "new Polkit source is versioned" "$ROOT/scripts/system/polkit/49-1password-unlock.rules"

ly_plan_before="$(module_run system:ly-screen plan)"
assert_text_contains "Ly plan reports absent target before apply" "ABSENT" "$ly_plan_before"
assert_text_contains "Ly plan labels its managed results" "[system:ly-screen]" "$ly_plan_before"
module_run system:ly-screen apply >/dev/null
assert_file_exists "Ly configuration is installed into the temporary root" "$SYSTEM_ROOT/etc/ly/config.ini"
assert_file_exists "Ly startup palette is installed into the temporary root" "$SYSTEM_ROOT/etc/ly/startup.sh"
assert_file_exists "Ly animation is installed into the temporary root" "$SYSTEM_ROOT/etc/ly/animations/cosmic-gravity-monitor-16c-240x67.dur"

if cmp -s "$ROOT/scripts/system/ly/config.ini" "$SYSTEM_ROOT/etc/ly/config.ini"; then
    pass "Ly configuration is byte-identical after apply"
else
    fail "Ly configuration is byte-identical after apply"
fi
if cmp -s "$ROOT/scripts/system/ly/animations/cosmic-gravity-monitor-16c-240x67.dur" "$SYSTEM_ROOT/etc/ly/animations/cosmic-gravity-monitor-16c-240x67.dur"; then
    pass "Ly animation is byte-identical after apply"
else
    fail "Ly animation is byte-identical after apply"
fi

ly_plan_after="$(module_run system:ly-screen plan)"
assert_text_contains "Ly second plan is current" "CURRENT" "$ly_plan_after"

module_run system:xorg-libinput apply >/dev/null
xorg_plan_after="$(module_run system:xorg-libinput plan)"
assert_text_contains "Xorg second plan is current" "CURRENT" "$xorg_plan_after"

module_run system:1password-unlock-polkit apply >/dev/null
polkit_plan_after="$(module_run system:1password-unlock-polkit plan)"
assert_text_contains "Polkit second plan is current" "CURRENT" "$polkit_plan_after"

finish_tests
