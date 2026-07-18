#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT/tests/deploy/testlib.sh"
source "$ROOT/scripts/lib/common.sh"
source "$ROOT/scripts/lib/tools.sh"
source "$ROOT/scripts/lib/selection.sh"

PROFILE_TOOL_SET="developer"
PROFILE_STOW_PACKAGES=(zsh nvim docs)
PROFILE_MODULES=(system:xorg-libinput user:awesome-auth-startup)

# Simulate profile validation removing an invalid/non-Stow directory.
selection_init_from_profile "$ROOT"

assert_text_contains "profile tool defaults are selected" "rg" "${CONFIG_SELECTED_TOOLS[*]}"
assert_text_contains "declared Stow package is selected" "zsh" "${CONFIG_SELECTED_STOW[*]}"
assert_text_contains "declared module is selected" "system:xorg-libinput" "${CONFIG_SELECTED_MODULES[*]}"
assert_text_not_contains "non-Stow docs directory is excluded" "docs" "${CONFIG_AVAILABLE_STOW[*]}"
if _selection_contains scripts "${CONFIG_AVAILABLE_STOW[@]}"; then
    fail "scripts directory is never inferred"
else
    pass "scripts directory is never inferred"
fi

selection_toggle tools rg
assert_text_not_contains "toggle removes selected tool" "rg" "${CONFIG_SELECTED_TOOLS[*]}"
selection_toggle tools rg
assert_text_contains "toggle re-adds selected tool" "rg" "${CONFIG_SELECTED_TOOLS[*]}"

selection_set stow nvim
assert_eq "explicit Stow selection replaces defaults" "nvim" "${CONFIG_SELECTED_STOW[*]}"

# Mutate selection then restore recommended defaults.
CONFIG_SELECTED_TOOLS=(rg)
CONFIG_SELECTED_STOW=(nvim)
CONFIG_SELECTED_MODULES=()
selection_reset_recommended "$ROOT"
assert_text_contains "reset restores profile tools" "rg" "${CONFIG_SELECTED_TOOLS[*]}"
assert_text_contains "reset restores profile Stow" "zsh" "${CONFIG_SELECTED_STOW[*]}"
assert_text_contains "reset restores profile modules" "system:xorg-libinput" "${CONFIG_SELECTED_MODULES[*]}"

finish_tests
