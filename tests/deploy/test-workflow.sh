#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT/tests/deploy/testlib.sh"
source "$ROOT/scripts/lib/common.sh"
source "$ROOT/scripts/lib/workflow.sh"

TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT
CALLS="$TMPDIR/calls"

CONFIG_SELECTED_TOOLS=(rg)
CONFIG_SELECTED_STOW=(zsh nvim)
CONFIG_SELECTED_MODULES=(system:xorg-libinput user:awesome-auth-startup)
PROFILE_NAME="test-host"
PROFILE_HOST="test-host"
PROFILE_OS_ID="fedora"
PROFILE_KNOWN=false
ALLOW_UNKNOWN_HOST=false

profile_can_apply() { printf 'false\n'; }
tools_missing_from() { printf 'rg\n'; }
tools_install() { printf 'tools:%s:%s\n' "$1" "$2" >> "$CALLS"; }
stow_package_status() { printf 'DRIFT %s\n' "$1"; return 1; }
stow_apply_packages() { printf 'stow:%s\n' "$*" >> "$CALLS"; }
module_run() {
    if [[ "$2" == status ]]; then
        printf 'DRIFT %s\n' "$1"
        return 1
    fi
    printf 'module:%s:%s\n' "$1" "$2" >> "$CALLS"
}

set +e
workflow_apply_selected >/dev/null 2>&1
unknown_rc=$?
set -e
assert_eq "unknown profile is blocked before apply" "$EXIT_BLOCKED" "$unknown_rc"
assert_eq "unknown profile invokes no mutation" "" "$(cat "$CALLS" 2>/dev/null || true)"

PROFILE_KNOWN=true
profile_can_apply() { printf 'true\n'; }
workflow_apply_selected >/dev/null
calls="$(cat "$CALLS")"
assert_text_contains "selected missing tools use shared apply" "tools:fedora:rg" "$calls"
assert_text_contains "selected Stow packages use shared apply" "stow:zsh nvim" "$calls"
assert_text_contains "selected system module uses shared apply" "module:system:xorg-libinput:apply" "$calls"
assert_text_contains "selected user module uses shared apply" "module:user:awesome-auth-startup:apply" "$calls"

finish_tests
