#!/usr/bin/env bash

module_1password_unlock_polkit_metadata() {
    case "$1" in
        label) printf '1Password desktop unlock\n' ;;
        description) printf 'Authorize only the scoped 1Password desktop-unlock Polkit action.\n' ;;
        privilege) printf 'root\n' ;;
        risk) printf 'medium\n' ;;
        impact) printf 'Changes desktop unlock authorization; CLI and SSH-agent authorization remain unchanged.\n' ;;
    esac
}

module_1password_unlock_polkit() {
    local action="$1"
    module_manage_file \
        "$action" \
        "system:1password-unlock-polkit" \
        "${MODULE_ROOT}/scripts/system/polkit/49-1password-unlock.rules" \
        "/etc/polkit-1/rules.d/49-1password-unlock.rules" \
        0644
}
