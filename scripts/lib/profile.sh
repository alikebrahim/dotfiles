#!/usr/bin/env bash
# Shared host profile resolution for deployment scripts.

PROFILE_ROOT=""
PROFILE_DIR=""
PROFILE_KNOWN=false
PROFILE_NAME=""
PROFILE_HOST=""
PROFILE_USER=""
PROFILE_OS_ID=""
PROFILE_OS_VERSION=""
PROFILE_TMUX_OVERLAY=""
PROFILE_SSH_OVERLAY=""
PROFILE_UI_THEME="plain"
PROFILE_STOW_PACKAGES=()
PROFILE_MODULES=()
PROFILE_ALLOWED_OS=()
PROFILE_COMMON_STOW_PACKAGES=()
PROFILE_EXTRA_STOW_PACKAGES=()
PROFILE_TOOL_SET=""

profile_init() {
    PROFILE_ROOT="$1"
    PROFILE_DIR="${PROFILE_ROOT}/scripts/profiles"
}

profile_reset() {
    PROFILE_KNOWN=false
    PROFILE_NAME="unknown"
    PROFILE_HOST=""
    PROFILE_USER=""
    PROFILE_OS_ID=""
    PROFILE_OS_VERSION=""
    PROFILE_TMUX_OVERLAY=""
    PROFILE_SSH_OVERLAY=""
    PROFILE_UI_THEME="plain"
    PROFILE_STOW_PACKAGES=()
    PROFILE_MODULES=()
    PROFILE_ALLOWED_OS=()
    PROFILE_COMMON_STOW_PACKAGES=()
    PROFILE_EXTRA_STOW_PACKAGES=()
    PROFILE_TOOL_SET=""
}

profile_host_name_is_safe() {
    [[ "$1" =~ ^[A-Za-z0-9][A-Za-z0-9_-]*$ ]]
}

profile_resolve() {
    local host="$1"
    local user="$2"
    local os_id="${3:-unknown}"
    local os_version="${4:-unknown}"
    local profile_file

    [[ -n "$PROFILE_DIR" ]] || {
        printf 'profile_init must be called before profile_resolve\n' >&2
        return 2
    }

    profile_reset
    PROFILE_HOST="$host"
    PROFILE_USER="$user"
    PROFILE_OS_ID="$os_id"
    PROFILE_OS_VERSION="$os_version"

    # shellcheck source=scripts/profiles/common.conf
    source "${PROFILE_DIR}/common.conf"

    profile_file="${PROFILE_DIR}/${host}.conf"
    if profile_host_name_is_safe "$host" && [[ -f "$profile_file" ]]; then
        # Profile files are repository-controlled declarative data.
        # shellcheck disable=SC1090
        source "$profile_file"
        PROFILE_KNOWN=true
        PROFILE_NAME="$host"
    fi

    PROFILE_STOW_PACKAGES=("${PROFILE_COMMON_STOW_PACKAGES[@]}")
    [[ -n "$PROFILE_TMUX_OVERLAY" ]] && PROFILE_STOW_PACKAGES+=("$PROFILE_TMUX_OVERLAY")
    PROFILE_STOW_PACKAGES+=("${PROFILE_EXTRA_STOW_PACKAGES[@]}")
}

profile_can_apply() {
    local supported_os

    [[ "$PROFILE_KNOWN" == true ]] || {
        printf 'false\n'
        return 0
    }

    if (( ${#PROFILE_ALLOWED_OS[@]} == 0 )); then
        printf 'true\n'
        return 0
    fi

    for supported_os in "${PROFILE_ALLOWED_OS[@]}"; do
        if [[ "$supported_os" == "$PROFILE_OS_ID" ]]; then
            printf 'true\n'
            return 0
        fi
    done

    printf 'false\n'
}

profile_known_hosts() {
    local profile_file
    local host

    [[ -n "$PROFILE_DIR" ]] || return 2
    for profile_file in "${PROFILE_DIR}"/*.conf; do
        [[ -f "$profile_file" ]] || continue
        host="$(basename "$profile_file" .conf)"
        [[ "$host" == common ]] || printf '%s\n' "$host"
    done
}

profile_has_module() {
    local wanted="$1"
    local module

    for module in "${PROFILE_MODULES[@]}"; do
        [[ "$module" == "$wanted" ]] && return 0
    done
    return 1
}
