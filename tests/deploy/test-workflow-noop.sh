#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT/tests/deploy/testlib.sh"
source "$ROOT/scripts/lib/common.sh"
source "$ROOT/scripts/lib/workflow.sh"

TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT
CALLS="$TMPDIR/calls"
PROFILE_NAME=test
PROFILE_HOST=test
PROFILE_OS_ID=fedora
PROFILE_KNOWN=true
ALLOW_UNKNOWN_HOST=false
CONFIG_SELECTED_TOOLS=(zsh)
CONFIG_SELECTED_STOW=(zsh)
CONFIG_SELECTED_MODULES=(system:xorg-libinput)

profile_can_apply() { printf 'true\n'; }
tool_is_installed() { return 0; }
tools_missing_from() { return 0; }
tools_install() { printf 'tools\n' >> "$CALLS"; }
stow_package_status() { printf 'CURRENT zsh (2/2 linked)\n'; return 0; }
stow_apply_packages() { printf 'stow\n' >> "$CALLS"; }
module_run() {
    if [[ "$2" == status ]]; then
        printf 'CURRENT module\n'
    else
        printf 'module:%s\n' "$2" >> "$CALLS"
    fi
}

workflow_apply_selected >/dev/null
assert_eq "current selected components invoke no mutation" "" "$(cat "$CALLS" 2>/dev/null || true)"

finish_tests
