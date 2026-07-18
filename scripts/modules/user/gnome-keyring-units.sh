#!/usr/bin/env bash

module_gnome_keyring_units_metadata() {
    case "$1" in
        label) printf 'GNOME Keyring user services\n' ;;
        description) printf 'Enable and start the GNOME Keyring user service and socket.\n' ;;
        privilege) printf 'user\n' ;;
        risk) printf 'medium\n' ;;
        impact) printf 'Changes user-service state immediately; no root access.\n' ;;
    esac
}

module_gnome_keyring_units_state() {
    local unit
    local units=(gnome-keyring-daemon.service gnome-keyring-daemon.socket)

    if ! command -v systemctl >/dev/null 2>&1; then
        printf 'BLOCKED systemctl is required for GNOME Keyring management\n'
        return 2
    fi

    for unit in "${units[@]}"; do
        if ! systemctl --user is-enabled "$unit" >/dev/null 2>&1; then
            printf 'DRIFT %s is not enabled\n' "$unit"
            return 1
        fi
        if ! systemctl --user is-active "$unit" >/dev/null 2>&1; then
            printf 'DRIFT %s is not active\n' "$unit"
            return 1
        fi
    done

    printf 'CURRENT GNOME Keyring user service and socket\n'
}

module_gnome_keyring_units() {
    local action="$1"
    local state
    local rc=0

    state="$(module_gnome_keyring_units_state)" || rc=$?
    case "$action" in
        describe)
            printf 'user:gnome-keyring-units: enabled and active user service/socket\n'
            ;;
        status|plan|verify)
            printf '%s [user:gnome-keyring-units]\n' "$state"
            [[ "$rc" -ne 2 ]]
            ;;
        apply)
            if [[ "$rc" -eq 2 ]]; then
                printf '%s [user:gnome-keyring-units]\n' "$state" >&2
                return 2
            fi
            if [[ "$rc" -eq 1 ]]; then
                module_record_service_state user gnome-keyring-daemon.service
                module_record_service_state user gnome-keyring-daemon.socket
                systemctl --user enable --now gnome-keyring-daemon.service gnome-keyring-daemon.socket
            fi
            module_gnome_keyring_units verify
            ;;
        *)
            printf 'unknown module action: %s\n' "$action" >&2
            return 2
            ;;
    esac
}
