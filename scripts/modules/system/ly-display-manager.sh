#!/usr/bin/env bash

module_ly_display_manager_metadata() {
    case "$1" in
        label) printf 'Ly display manager\n' ;;
        description) printf 'Install Ly and enable its tty2 system service.\n' ;;
        privilege) printf 'root\n' ;;
        risk) printf 'high\n' ;;
        impact) printf 'May install a package and start or enable the login service immediately.\n' ;;
    esac
}

module_ly_display_manager_state() {
    if ! command -v rpm >/dev/null 2>&1 || ! command -v systemctl >/dev/null 2>&1; then
        printf 'BLOCKED rpm and systemctl are required for Ly management\n'
        return 2
    fi
    if ! rpm -q ly >/dev/null 2>&1; then
        printf 'ABSENT Ly package\n'
        return 1
    fi
    if ! systemctl is-enabled ly@tty2.service >/dev/null 2>&1; then
        printf 'DRIFT ly@tty2.service is not enabled\n'
        return 1
    fi
    if ! systemctl is-active ly@tty2.service >/dev/null 2>&1; then
        printf 'DRIFT ly@tty2.service is not active\n'
        return 1
    fi

    printf 'CURRENT Ly package and ly@tty2.service\n'
}

module_ly_display_manager() {
    local action="$1"
    local state
    local rc=0

    state="$(module_ly_display_manager_state)" || rc=$?
    case "$action" in
        describe)
            printf 'system:ly-display-manager: Ly package + ly@tty2.service\n'
            ;;
        status|plan|verify)
            printf '%s [system:ly-display-manager]\n' "$state"
            [[ "$rc" -ne 2 ]]
            ;;
        apply)
            if [[ "$rc" -eq 2 ]]; then
                printf '%s [system:ly-display-manager]\n' "$state" >&2
                return 2
            fi
            if [[ "$state" == "ABSENT Ly package" ]]; then
                command -v dnf >/dev/null 2>&1 || {
                    printf 'BLOCKED dnf is required to install Ly on this profile\n' >&2
                    return 2
                }
                module_record_package_state ly ABSENT
                run_as_root dnf install -y ly
            fi
            module_record_service_state system ly@tty2.service
            run_as_root systemctl enable --now ly@tty2.service
            module_ly_display_manager verify
            ;;
        *)
            printf 'unknown module action: %s\n' "$action" >&2
            return 2
            ;;
    esac
}
