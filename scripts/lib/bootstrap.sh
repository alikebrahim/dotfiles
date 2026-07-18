#!/usr/bin/env bash
# Prerequisite discovery and installation. Native package sources only.

# shellcheck source=scripts/lib/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

BOOTSTRAP_MIN_STOW="2.3.1"
BOOTSTRAP_MIN_GUM="0.17.0"

bootstrap_version_at_least() {
    local actual="$1"
    local minimum="$2"
    [[ -n "$actual" ]] || return 1
    [[ "$(printf '%s\n%s\n' "$minimum" "$actual" | sort -V | head -1)" == "$minimum" ]]
}

bootstrap_stow_version() {
    stow --version 2>/dev/null | sed -nE 's/.*version ([0-9]+(\.[0-9]+)+).*/\1/p' | head -1
}

bootstrap_gum_version() {
    gum --version 2>/dev/null | sed -nE 's/[^0-9]*([0-9]+(\.[0-9]+)+).*/\1/p' | head -1
}

bootstrap_package_for() {
    local os_id="$1" command_name="$2"
    case "$command_name" in
        stow|gum|less) printf '%s\n' "$command_name" ;;
        column|flock)
            case "$os_id" in
                fedora|ubuntu) printf 'util-linux\n' ;;
                *) printf 'util-linux\n' ;;
            esac
            ;;
    esac
}

bootstrap_status() {
    local command_name
    for command_name in stow gum less column flock; do
        if command -v "$command_name" >/dev/null 2>&1; then
            case "$command_name" in
                stow) printf '%s stow %s\n' "$STATUS_CURRENT" "$(bootstrap_stow_version)" ;;
                gum) printf '%s gum %s\n' "$STATUS_CURRENT" "$(bootstrap_gum_version)" ;;
                *) printf '%s %s\n' "$STATUS_CURRENT" "$command_name" ;;
            esac
        else
            printf '%s %s\n' "$STATUS_ABSENT" "$command_name"
        fi
    done
}

bootstrap_missing_packages() {
    local os_id="${1:-${PROFILE_OS_ID:-fedora}}"
    local packages=() command_name package candidate existing
    if ! command -v stow >/dev/null 2>&1 || ! bootstrap_version_at_least "$(bootstrap_stow_version)" "$BOOTSTRAP_MIN_STOW"; then
        packages+=("$(bootstrap_package_for "$os_id" stow)")
    fi
    if ! command -v gum >/dev/null 2>&1 || ! bootstrap_version_at_least "$(bootstrap_gum_version)" "$BOOTSTRAP_MIN_GUM"; then
        packages+=("$(bootstrap_package_for "$os_id" gum)")
    fi
    for command_name in less column flock; do
        command -v "$command_name" >/dev/null 2>&1 && continue
        package="$(bootstrap_package_for "$os_id" "$command_name")"
        existing=false
        for candidate in "${packages[@]}"; do [[ "$candidate" == "$package" ]] && existing=true; done
        "$existing" || packages+=("$package")
    done
    if (( ${#packages[@]} > 0 )); then
        printf '%s\n' "${packages[@]}"
    fi
    return "$EXIT_OK"
}

bootstrap_plan_for() {
    local os_id="$1"
    shift
    local packages=("$@")

    if (( ${#packages[@]} == 0 )); then
        printf '%s prerequisites are installed\n' "$STATUS_CURRENT"
        return "$EXIT_OK"
    fi

    case "$os_id" in
        fedora)
            printf '%s sudo dnf install -y' "$STATUS_INSTALL"
            printf ' %s' "${packages[@]}"
            printf '\n'
            ;;
        ubuntu)
            printf '%s sudo apt-get update\n' "$STATUS_INSTALL"
            printf '%s sudo apt-get install -y' "$STATUS_INSTALL"
            printf ' %s' "${packages[@]}"
            printf '\n'
            ;;
        *)
            printf '%s bootstrap supports Fedora and Ubuntu only (got: %s)\n' \
                "$STATUS_BLOCKED" "$os_id" >&2
            return "$EXIT_BLOCKED"
            ;;
    esac
}

bootstrap_apply_for() {
    local os_id="$1"
    shift
    local packages=("$@")

    if (( ${#packages[@]} == 0 )); then
        printf '%s prerequisites are installed\n' "$STATUS_CURRENT"
        return "$EXIT_OK"
    fi

    case "$os_id" in
        fedora)
            run_as_root dnf install -y "${packages[@]}"
            ;;
        ubuntu)
            run_as_root apt-get update
            run_as_root apt-get install -y "${packages[@]}"
            ;;
        *)
            printf '%s bootstrap supports Fedora and Ubuntu only (got: %s)\n' \
                "$STATUS_BLOCKED" "$os_id" >&2
            return "$EXIT_BLOCKED"
            ;;
    esac
}
