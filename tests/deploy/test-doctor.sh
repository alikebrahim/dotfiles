#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT/tests/deploy/testlib.sh"
source "$ROOT/scripts/lib/common.sh"
source "$ROOT/scripts/lib/stow.sh"
source "$ROOT/scripts/lib/stow-catalog.sh"
source "$ROOT/scripts/lib/doctor.sh"

TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT
HOME_DIR="$TMPDIR/home"
mkdir -p "$HOME_DIR/.local/state" "$HOME_DIR/.local/share" "$HOME_DIR/.tmux"

STOW_HOME="$HOME_DIR"
PROFILE_NAME=test
PROFILE_STOW_PACKAGES=(zsh)

fold="$(doctor_fold_status "$HOME_DIR")"
assert_text_contains "fold status reports real .local" "real directory: $HOME_DIR/.local" "$fold"

set +e
audit="$(doctor_catalog_audit "$ROOT")"
audit_rc=$?
set -e
assert_eq "catalog audit succeeds for this repo" "0" "$audit_rc"
assert_text_contains "catalog audit confirms zsh" "catalog package present: zsh" "$audit"
assert_text_contains "catalog audit accepts profile package" "profile package registered: zsh" "$audit"

plugins="$(doctor_tmux_plugins_status)"
assert_text_contains "tmux plugin status notes apply exclusion" "not applied by configure-host apply" "$plugins"

checklist="$(doctor_new_package_checklist)"
assert_text_contains "checklist requires catalog registration" "stow-catalog.sh" "$checklist"

finish_tests
