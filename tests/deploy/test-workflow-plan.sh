#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT/tests/deploy/testlib.sh"
source "$ROOT/scripts/lib/common.sh"
source "$ROOT/scripts/lib/workflow.sh"

PROFILE_NAME="test-host"
PROFILE_HOST="test-host"
PROFILE_OS_ID="fedora"
PROFILE_OS_VERSION="44"
CONFIG_SELECTED_TOOLS=(rg)
CONFIG_SELECTED_STOW=(zsh)
CONFIG_SELECTED_MODULES=(system:xorg-libinput)
declare -A TOOL_DESC STOW_CATALOG_LABEL STOW_CATALOG_DESC
TOOL_DESC[rg]="Fast recursive search"
STOW_CATALOG_LABEL[zsh]="Zsh"
STOW_CATALOG_DESC[zsh]="Shell configuration"

tool_is_installed() { return 1; }
stow_package_status() { printf 'CURRENT zsh (2/2 linked)\n'; return 0; }
module_run() { printf 'DRIFT /etc/example [%s]\n' "$1"; return 0; }
module_metadata() {
    case "$2" in
        label) printf 'Natural scrolling\n' ;;
        description) printf 'Install pointer scrolling policy.\n' ;;
        privilege) printf 'root\n' ;;
        risk) printf 'low\n' ;;
        impact) printf 'New X11 sessions.\n' ;;
    esac
}

plan="$(workflow_plan_selected)"
assert_text_contains "plan identifies profile" "test-host" "$plan"
assert_text_contains "plan counts one current component" "Current: 1" "$plan"
assert_text_contains "plan counts two proposed changes" "Changes: 2" "$plan"
assert_text_contains "plan shows missing tool" "[TOOL] rg" "$plan"
assert_text_contains "plan shows drifted system module" "[SYSTEM] Natural scrolling" "$plan"
assert_text_contains "plan warns that root is required" "Requires root: yes" "$plan"
proposed="$(printf '%s\n' "$plan" | sed -n '/PROPOSED CHANGES/,$p')"
assert_text_not_contains "current dotfile is omitted from proposed changes" "[DOTFILE] Zsh" "$proposed"

finish_tests
