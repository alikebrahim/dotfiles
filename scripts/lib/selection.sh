#!/usr/bin/env bash
# Session-scoped desired-state selection shared by CLI and interactive UI.

source "$(dirname "${BASH_SOURCE[0]}")/stow-catalog.sh"

CONFIG_AVAILABLE_TOOLS=()
CONFIG_AVAILABLE_STOW=()
CONFIG_AVAILABLE_MODULES=()
CONFIG_SELECTED_TOOLS=()
CONFIG_SELECTED_STOW=()
CONFIG_SELECTED_MODULES=()

_selection_contains() {
    local wanted="$1"
    shift
    local item
    for item in "$@"; do
        [[ "$item" == "$wanted" ]] && return 0
    done
    return 1
}

_selection_remove() {
    local array_name="$1" unwanted="$2" item
    local kept=()
    eval 'local current=("${'"$array_name"'[@]}")'
    for item in "${current[@]}"; do
        [[ "$item" == "$unwanted" ]] || kept+=("$item")
    done
    eval "$array_name=(\"\${kept[@]}\")"
}

selection_init_from_profile() {
    local root="$1" item members
    stow_catalog_init "$root"

    CONFIG_AVAILABLE_TOOLS=("${TOOLS_REGISTERED[@]}")
    CONFIG_AVAILABLE_STOW=()
    mapfile -t CONFIG_AVAILABLE_STOW < <(stow_catalog_list)
    if declare -F ssh_overlay_exists >/dev/null 2>&1 && ssh_overlay_exists; then
        CONFIG_AVAILABLE_STOW+=(ssh-overlay)
        STOW_CATALOG_LABEL[ssh-overlay]="SSH configuration"
        STOW_CATALOG_DESC[ssh-overlay]="Host-specific managed SSH client configuration"
        STOW_CATALOG_CATEGORY[ssh-overlay]="security"
    fi
    CONFIG_AVAILABLE_MODULES=("${PROFILE_MODULES[@]}")

    CONFIG_SELECTED_TOOLS=()
    members="$(tools_set_members "${PROFILE_TOOL_SET:-}")"
    for item in $members; do
        [[ -v TOOL_DESC["$item"] ]] && CONFIG_SELECTED_TOOLS+=("$item")
    done

    CONFIG_SELECTED_STOW=()
    for item in "${PROFILE_STOW_PACKAGES[@]}"; do
        stow_catalog_has "$item" && CONFIG_SELECTED_STOW+=("$item")
    done
    if declare -F ssh_overlay_exists >/dev/null 2>&1 && ssh_overlay_exists; then
        CONFIG_SELECTED_STOW+=(ssh-overlay)
    fi

    CONFIG_SELECTED_MODULES=("${PROFILE_MODULES[@]}")
}

# Restore the profile-recommended selection without dropping catalog availability.
# Used by the interactive dashboard "recommended setup" paths.
selection_reset_recommended() {
    local root="${1:-${DOTFILES:-${STOW_ROOT:-${STOW_CATALOG_ROOT:-}}}}"
    if [[ -z "$root" ]]; then
        printf '%s selection_reset_recommended needs a dotfiles root\n' "$STATUS_BLOCKED" >&2
        return "$EXIT_INTERNAL"
    fi
    selection_init_from_profile "$root"
}

selection_toggle() {
    local kind="$1" item="$2" array_name
    case "$kind" in
        tool|tools) array_name=CONFIG_SELECTED_TOOLS ;;
        stow) array_name=CONFIG_SELECTED_STOW ;;
        module|modules) array_name=CONFIG_SELECTED_MODULES ;;
        *) return "$EXIT_BLOCKED" ;;
    esac

    eval 'local current=("${'"$array_name"'[@]}")'
    if _selection_contains "$item" "${current[@]}"; then
        _selection_remove "$array_name" "$item"
    else
        eval "$array_name+=(\"\$item\")"
    fi
}

selection_set() {
    local kind="$1" array_name
    shift
    case "$kind" in
        tool|tools) array_name=CONFIG_SELECTED_TOOLS ;;
        stow) array_name=CONFIG_SELECTED_STOW ;;
        module|modules) array_name=CONFIG_SELECTED_MODULES ;;
        *) return "$EXIT_BLOCKED" ;;
    esac
    eval "$array_name=(\"\$@\")"
}

selection_is_selected() {
    local kind="$1" item="$2" array_name
    case "$kind" in
        tool|tools) array_name=CONFIG_SELECTED_TOOLS ;;
        stow) array_name=CONFIG_SELECTED_STOW ;;
        module|modules) array_name=CONFIG_SELECTED_MODULES ;;
        *) return 1 ;;
    esac
    eval 'local current=("${'"$array_name"'[@]}")'
    _selection_contains "$item" "${current[@]}"
}
