#!/usr/bin/env bash

module_awesome_auth_startup_metadata() {
    case "$1" in
        label) printf 'AwesomeWM authentication startup\n' ;;
        description) printf 'Verify that AwesomeWM starts MATE Polkit and 1Password idempotently.\n' ;;
        privilege) printf 'user\n' ;;
        risk) printf 'low\n' ;;
        impact) printf 'Verification-only here; configuration changes come from the AwesomeWM dotfiles package.\n' ;;
    esac
}

module_awesome_auth_startup_state() {
    local rc_file="${MODULE_ROOT}/awesome/.config/awesome/rc.lua"

    if [[ ! -r "$rc_file" ]]; then
        printf 'BLOCKED AwesomeWM configuration is missing: %s\n' "$rc_file"
        return 2
    fi
    if ! grep -Fq '/usr/libexec/polkit-mate-authentication-agent-1' "$rc_file"; then
        printf 'DRIFT AwesomeWM does not start the MATE Polkit agent\n'
        return 1
    fi
    if ! grep -Fq '"/opt/1Password/1password", "--silent"' "$rc_file"; then
        printf 'DRIFT AwesomeWM does not start 1Password silently\n'
        return 1
    fi

    printf 'CURRENT AwesomeWM starts Polkit and 1Password idempotently\n'
}

module_awesome_auth_startup() {
    local action="$1"
    local state
    local rc=0

    state="$(module_awesome_auth_startup_state)" || rc=$?
    case "$action" in
        describe)
            printf 'user:awesome-auth-startup: Stow-managed Polkit and 1Password session startup\n'
            ;;
        status|plan|verify)
            printf '%s [user:awesome-auth-startup]\n' "$state"
            [[ "$rc" -ne 2 ]]
            ;;
        apply)
            printf '%s [user:awesome-auth-startup]\n' "$state"
            if [[ "$rc" -eq 1 ]]; then
                printf 'BLOCKED restow the Awesome package before this module can become current\n' >&2
                return 2
            fi
            return "$rc"
            ;;
        *)
            printf 'unknown module action: %s\n' "$action" >&2
            return 2
            ;;
    esac
}
