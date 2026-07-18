#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=tests/deploy/testlib.sh
source "$ROOT/tests/deploy/testlib.sh"
# shellcheck source=scripts/lib/profile.sh
source "$ROOT/scripts/lib/profile.sh"

profile_init "$ROOT"

profile_resolve netmaster alikebrahim fedora 44
assert_eq "netmaster defines developer tools" "developer" "$PROFILE_TOOL_SET"
assert_eq "netmaster is a known profile" "true" "$PROFILE_KNOWN"
assert_eq "netmaster selects its tmux overlay" "tmux-remote-netmaster" "$PROFILE_TMUX_OVERLAY"
assert_eq "netmaster selects its SSH overlay" "netmaster" "$PROFILE_SSH_OVERLAY"
assert_contains "netmaster includes common zsh package" "zsh" "${PROFILE_STOW_PACKAGES[@]}"
assert_contains "netmaster includes its tmux package" "tmux-remote-netmaster" "${PROFILE_STOW_PACKAGES[@]}"
assert_not_contains "netmaster excludes desktop-only Awesome package" "awesome" "${PROFILE_STOW_PACKAGES[@]}"

profile_resolve servalws alikebrahim fedora 44
assert_eq "servalws defines full desktop tools" "desktop-full" "$PROFILE_TOOL_SET"
assert_eq "servalws is a known profile" "true" "$PROFILE_KNOWN"
assert_eq "servalws selects orange gas plasma UI" "orange-gas-plasma" "$PROFILE_UI_THEME"
assert_eq "servalws selects its tmux overlay" "tmux-remote-servalws" "$PROFILE_TMUX_OVERLAY"
assert_contains "servalws includes Awesome" "awesome" "${PROFILE_STOW_PACKAGES[@]}"
assert_contains "servalws includes 1Password" "1Password" "${PROFILE_STOW_PACKAGES[@]}"
assert_contains "servalws enables Ly system module" "system:ly-display-manager" "${PROFILE_MODULES[@]}"
assert_contains "servalws enables keyring user module" "user:gnome-keyring-units" "${PROFILE_MODULES[@]}"

profile_resolve zotac-box tima fedora 44
assert_eq "zotac defines minimal tools" "minimal" "$PROFILE_TOOL_SET"
assert_contains "zotac-box tima gets apps" "apps" "${PROFILE_STOW_PACKAGES[@]}"
assert_eq "zotac-box tima gets user overlay" "zotac-box/tima_zotac-box" "$PROFILE_SSH_OVERLAY"

profile_resolve zotac-box alikebrahim fedora 44
assert_not_contains "zotac-box alikebrahim excludes apps" "apps" "${PROFILE_STOW_PACKAGES[@]}"
assert_eq "zotac-box alikebrahim gets user overlay" "zotac-box/alikebrahim_zotac-box" "$PROFILE_SSH_OVERLAY"

profile_resolve honor u0_a290 termux 0
assert_eq "honor is a known profile" "true" "$PROFILE_KNOWN"
assert_eq "honor selects its tmux overlay" "tmux-remote-honor" "$PROFILE_TMUX_OVERLAY"
assert_eq "honor has no system modules" "0" "${#PROFILE_MODULES[@]}"

profile_resolve unknown alikebrahim fedora 44
assert_eq "unknown host is marked unknown" "false" "$PROFILE_KNOWN"
assert_eq "unknown host cannot apply by default" "false" "$(profile_can_apply)"
assert_contains "unknown host retains common packages for inspection" "zsh" "${PROFILE_STOW_PACKAGES[@]}"

profile_resolve "../profiles/common" alikebrahim fedora 44
assert_eq "path-like host names are never sourced as profiles" "false" "$PROFILE_KNOWN"

finish_tests
