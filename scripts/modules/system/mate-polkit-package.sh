#!/usr/bin/env bash

module_mate_polkit_package_metadata() {
    case "$1" in
        label) printf 'MATE Polkit agent\n' ;;
        description) printf 'Install the graphical authorization agent used by AwesomeWM.\n' ;;
        privilege) printf 'root\n' ;;
        risk) printf 'low\n' ;;
        impact) printf 'Installs a package; the session startup module launches it.\n' ;;
    esac
}

module_mate_polkit_package_state() {
    if ! command -v rpm >/dev/null 2>&1; then
        printf 'BLOCKED rpm is required for MATE Polkit management\n'
        return 2
    fi
    if rpm -q mate-polkit >/dev/null 2>&1; then
        printf 'CURRENT mate-polkit package\n'
        return 0
    fi

    printf 'ABSENT mate-polkit package\n'
    return 1
}

module_mate_polkit_package() {
    local action="$1"
    local state
    local rc=0

    state="$(module_mate_polkit_package_state)" || rc=$?
    case "$action" in
        describe)
            printf 'system:mate-polkit-package: MATE Polkit authentication agent package\n'
            ;;
        status|plan|verify)
            printf '%s [system:mate-polkit-package]\n' "$state"
            [[ "$rc" -ne 2 ]]
            ;;
        apply)
            if [[ "$rc" -eq 2 ]]; then
                printf '%s [system:mate-polkit-package]\n' "$state" >&2
                return 2
            fi
            if [[ "$rc" -eq 1 ]]; then
                command -v dnf >/dev/null 2>&1 || {
                    printf 'BLOCKED dnf is required to install mate-polkit on this profile\n' >&2
                    return 2
                }
                module_record_package_state mate-polkit ABSENT
                run_as_root dnf install -y mate-polkit
            fi
            module_mate_polkit_package verify
            ;;
        *)
            printf 'unknown module action: %s\n' "$action" >&2
            return 2
            ;;
    esac
}
