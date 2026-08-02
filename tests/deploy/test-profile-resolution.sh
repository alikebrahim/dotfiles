#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=tests/deploy/testlib.sh
source "$ROOT/tests/deploy/testlib.sh"
# shellcheck source=scripts/lib/profile.sh
source "$ROOT/scripts/lib/profile.sh"
# shellcheck source=scripts/lib/stow-catalog.sh
source "$ROOT/scripts/lib/stow-catalog.sh"

profile_init "$ROOT"
stow_catalog_init "$ROOT"

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
assert_contains "servalws includes Quickshell" "quickshell" "${PROFILE_STOW_PACKAGES[@]}"
assert_contains "servalws includes Flameshot" "flameshot" "${PROFILE_STOW_PACKAGES[@]}"
assert_not_contains "servalws excludes retired Rofi" "rofi" "${PROFILE_STOW_PACKAGES[@]}"
assert_not_contains "servalws excludes retired Polybar" "polybar" "${PROFILE_STOW_PACKAGES[@]}"
assert_not_contains "servalws excludes retired Dunst" "dunst" "${PROFILE_STOW_PACKAGES[@]}"
assert_contains "servalws includes 1Password" "1Password" "${PROFILE_STOW_PACKAGES[@]}"
assert_contains "servalws enables Ly system module" "system:ly-display-manager" "${PROFILE_MODULES[@]}"
assert_contains "servalws enables battery threshold module" "system:battery-charge-thresholds" "${PROFILE_MODULES[@]}"
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

if stow_catalog_has quickshell; then
    pass "Stow catalog registers the Quickshell package"
else
    fail "Stow catalog registers the Quickshell package"
fi

if stow_catalog_has flameshot; then
    pass "Stow catalog registers the Flameshot package"
else
    fail "Stow catalog registers the Flameshot package"
fi

for retired_package in rofi polybar dunst; do
    if stow_catalog_has "$retired_package"; then
        fail "Stow catalog excludes retired package $retired_package"
    else
        pass "Stow catalog excludes retired package $retired_package"
    fi
    assert_file_exists "Retired package $retired_package has an archive record" \
        "$ROOT/${retired_package}-archived/README.md"
done
assert_file_exists "Retired mixed Awesome helpers have an archive record" \
    "$ROOT/awesome_wm_scripts-archived/README.md"
assert_file_exists "Retired Awesome Pillbar has an archive record" \
    "$ROOT/awesome-pillbar-archived/README.md"

assert_file_exists "Quickshell package defines Stow exclusions" "$ROOT/quickshell/.stow-local-ignore"
quickshell_ignore=""
if [[ -r "$ROOT/quickshell/.stow-local-ignore" ]]; then
    quickshell_ignore="$(<"$ROOT/quickshell/.stow-local-ignore")"
fi
assert_text_contains "Quickshell Stow exclusions keep tests out of HOME" "^/tests" "$quickshell_ignore"
assert_text_contains "Quickshell Stow exclusions keep docs out of HOME" "^/docs" "$quickshell_ignore"

awesome_rc="$(<"$ROOT/awesome/.config/awesome/rc.lua")"
awesome_keys="$(<"$ROOT/awesome/.config/awesome/keys.lua")"
awesome_control="$(<"$ROOT/awesome/.config/awesome/lib/quickshell_control.lua")"
assert_text_contains "Awesome starts the Quickshell bridge lifecycle" "quickshell_bridge.start" "$awesome_rc"
assert_text_contains "Awesome loads the centralized Quickshell controller safely" 'pcall(require, "lib.quickshell_control")' "$awesome_rc"
assert_text_contains "Awesome ensures the selected shell only after bridge startup" 'quickshell_controller:ensure_started()' "$awesome_rc"
assert_text_contains "Awesome registers one complete Quickshell action set" 'keys.configure_shell_actions(quickshell_controller.actions)' "$awesome_rc"
assert_text_contains "Production startup defaults native mutations on" 'not quickshell_marker_exists(quickshell_safe_mode_marker)' "$awesome_rc"
assert_text_contains "Production startup supports one canonical safe-mode marker" 'quickshell-awesome/safe-mode' "$awesome_rc"
assert_text_not_contains "Retired opt-in mutation marker is absent" 'quickshell-awesome/mutations-enabled' "$awesome_rc"
assert_text_contains "Controller recovery inspects the selected config as JSON" '"list", "--json"' "$awesome_control"
assert_text_contains "Controller recovery starts the selected config explicitly" 'append(start_command, config_dir)' "$awesome_control"
assert_text_contains "Controller uses the canonical X11 identity" 'RESOURCE_NAME=quickshell-shell' "$awesome_control"
assert_text_contains "Controller routes native control popouts through Quickshell" 'method = "openBluetooth"' "$awesome_control"
assert_text_contains "Keybindings use the injected audio action" 'shell_actions.audio_controls()' "$awesome_keys"
assert_text_not_contains "Active Awesome startup has no Rofi fallback" "rofi" "$awesome_rc"
assert_text_not_contains "Active Awesome keybindings have no Rofi fallback" "rofi" "$awesome_keys"

profile_resolve "../profiles/common" alikebrahim fedora 44
assert_eq "path-like host names are never sourced as profiles" "false" "$PROFILE_KNOWN"

finish_tests
