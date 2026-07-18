#!/usr/bin/env bash
# Shared lifecycle dispatcher for explicit host modules.
# Module discovery is convention-based: a module ID "category:name"
# maps to scripts/modules/category/name.sh, function module_<name>.

# shellcheck source=scripts/lib/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

MODULE_ROOT=""
MODULE_SYSTEM_ROOT="/"

module_runner_init() {
    MODULE_ROOT="$1"
    MODULE_SYSTEM_ROOT="${2:-${CONFIGURE_HOST_SYSTEM_ROOT:-/}}"
}

module_target_path() {
    local absolute_target="$1"
    printf '%s%s\n' "${MODULE_SYSTEM_ROOT%/}" "$absolute_target"
}

module_manifest_record() {
    [[ -n "${CONFIGURE_HOST_ROLLBACK_MANIFEST:-}" ]] || return "$EXIT_OK"
    printf '%s' "$1" >> "$CONFIGURE_HOST_ROLLBACK_MANIFEST"
    shift
    printf '\t%s' "$@" >> "$CONFIGURE_HOST_ROLLBACK_MANIFEST"
    printf '\n' >> "$CONFIGURE_HOST_ROLLBACK_MANIFEST"
}

module_record_package_state() {
    module_manifest_record PACKAGE "$1" "${2:-ABSENT}"
}

module_record_service_state() {
    local scope="$1" unit="$2" enabled="" active=""
    local command=(systemctl)
    [[ -n "${CONFIGURE_HOST_ROLLBACK_MANIFEST:-}" ]] || return "$EXIT_OK"
    [[ "$scope" == user ]] && command+=(--user)

    enabled="$("${command[@]}" is-enabled "$unit" 2>/dev/null)" || true
    active="$("${command[@]}" is-active "$unit" 2>/dev/null)" || true
    [[ -n "$enabled" ]] || enabled=unknown
    [[ -n "$active" ]] || active=unknown
    module_manifest_record SERVICE "$scope" "$unit" "$enabled" "$active"
}

module_file_status() {
    local source="$1"
    local absolute_target="$2"
    local target

    target="$(module_target_path "$absolute_target")"

    if [[ ! -f "$source" ]]; then
        printf '%s missing source: %s\n' "$STATUS_BLOCKED" "$source"
        return "$EXIT_BLOCKED"
    fi
    if [[ -L "$target" ]]; then
        printf '%s managed target is a symlink: %s\n' "$STATUS_BLOCKED" "$target"
        return "$EXIT_BLOCKED"
    fi
    if [[ ! -e "$target" ]]; then
        printf '%s %s\n' "$STATUS_ABSENT" "$absolute_target"
        return "$EXIT_DRIFT"
    fi
    if [[ ! -r "$target" ]]; then
        printf '%s managed target is unreadable: %s\n' "$STATUS_BLOCKED" "$absolute_target"
        return "$EXIT_BLOCKED"
    fi
    if cmp -s "$source" "$target"; then
        printf '%s %s\n' "$STATUS_CURRENT" "$absolute_target"
        return "$EXIT_OK"
    fi

    printf '%s %s\n' "$STATUS_DRIFT" "$absolute_target"
    return "$EXIT_DRIFT"
}

module_install_file() {
    local source="$1"
    local absolute_target="$2"
    local mode="$3"
    local target

    target="$(module_target_path "$absolute_target")"

    if [[ "$MODULE_SYSTEM_ROOT" != / || $EUID -eq 0 ]]; then
        install -D -m "$mode" "$source" "$target"
        return
    fi

    run_as_root install -D -m "$mode" "$source" "$target"
}

module_backup_file() {
    local absolute_target="$1"
    local target backup mode uid gid

    [[ -n "${CONFIGURE_HOST_BACKUP_DIR:-}" &&
       -n "${CONFIGURE_HOST_ROLLBACK_MANIFEST:-}" ]] || return 0

    target="$(module_target_path "$absolute_target")"
    if [[ ! -e "$target" ]]; then
        printf 'FILE\t%s\tABSENT\t-\t-\t-\t-\n' "$absolute_target" \
            >> "$CONFIGURE_HOST_ROLLBACK_MANIFEST"
        return 0
    fi

    [[ ! -L "$target" ]] || {
        printf '%s refusing to back up managed symlink: %s\n' \
            "$STATUS_BLOCKED" "$absolute_target" >&2
        return "$EXIT_BLOCKED"
    }

    backup="${CONFIGURE_HOST_BACKUP_DIR}${absolute_target}"
    mode="$(stat -c '%a' "$target")"
    uid="$(stat -c '%u' "$target")"
    gid="$(stat -c '%g' "$target")"
    mkdir -p "$(dirname "$backup")"

    if [[ "$MODULE_SYSTEM_ROOT" != / || $EUID -eq 0 ]]; then
        install -m "$mode" "$target" "$backup"
    else
        run_as_root install -m "$mode" "$target" "$backup"
        run_as_root chown "$(id -u):$(id -g)" "$backup"
    fi
    chmod u+rw "$backup" 2>/dev/null || true
    printf 'FILE\t%s\tPRESENT\t%s\t%s\t%s\t%s\n' \
        "$absolute_target" "$backup" "$mode" "$uid" "$gid" \
        >> "$CONFIGURE_HOST_ROLLBACK_MANIFEST"
}

module_manage_file() {
    local action="$1"
    local label="$2"
    local source="$3"
    local absolute_target="$4"
    local mode="$5"
    local status
    local rc=0

    case "$action" in
        describe)
            printf '%s: %s -> %s\n' "$label" "$source" "$absolute_target"
            ;;
        status|plan|verify)
            status="$(module_file_status "$source" "$absolute_target")" || rc=$?
            printf '%s [%s]\n' "$status" "$label"
            if [[ "$action" == plan && "$rc" -eq "$EXIT_DRIFT" ]]; then
                local target
                target="$(module_target_path "$absolute_target")"
                if [[ -r "$target" ]]; then
                    diff -u "$target" "$source" 2>/dev/null || true
                fi
            fi
            [[ "$rc" -ne "$EXIT_BLOCKED" ]]
            ;;
        apply)
            status="$(module_file_status "$source" "$absolute_target")" || rc=$?
            case "$rc" in
                "$EXIT_OK")
                    printf '%s [%s]\n' "$status" "$label"
                    ;;
                "$EXIT_DRIFT")
                    module_backup_file "$absolute_target"
                    module_install_file "$source" "$absolute_target" "$mode"
                    # Verify after install
                    if cmp -s "$source" "$(module_target_path "$absolute_target")"; then
                        printf '%s %s [%s]\n' "$STATUS_CHANGED" "$absolute_target" "$label"
                    else
                        printf '%s install verification failed: %s [%s]\n' \
                            "$STATUS_BLOCKED" "$absolute_target" "$label" >&2
                        return "$EXIT_BLOCKED"
                    fi
                    ;;
                *)
                    printf '%s [%s]\n' "$status" "$label" >&2
                    return "$EXIT_BLOCKED"
                    ;;
            esac
            ;;
        *)
            printf 'unknown module action: %s\n' "$action" >&2
            return "$EXIT_INTERNAL"
            ;;
    esac
}

module_run() {
    local module_id="$1"
    local action="$2"
    local category="${module_id%%:*}"
    local name="${module_id#*:}"
    local module_file
    local module_function

    [[ -n "$MODULE_ROOT" ]] || {
        printf 'module_runner_init must be called before module_run\n' >&2
        return "$EXIT_INTERNAL"
    }

    [[ "$category" == "$module_id" || -z "$name" ]] && {
        printf '%s invalid module ID (expected category:name): %s\n' \
            "$STATUS_BLOCKED" "$module_id" >&2
        return "$EXIT_BLOCKED"
    }

    module_file="${MODULE_ROOT}/scripts/modules/${category}/${name}.sh"
    module_function="module_${name//-/_}"

    if [[ ! -f "$module_file" ]]; then
        printf '%s unknown module: %s\n' "$STATUS_BLOCKED" "$module_id" >&2
        return "$EXIT_BLOCKED"
    fi

    # Module sources are repository-controlled.
    # shellcheck disable=SC1090
    source "$module_file"

    if ! declare -f "$module_function" >/dev/null 2>&1; then
        printf '%s module function not found: %s in %s\n' \
            "$STATUS_BLOCKED" "$module_function" "$module_file" >&2
        return "$EXIT_BLOCKED"
    fi

    "$module_function" "$action"
}

module_metadata() {
    local module_id="$1" field="$2"
    local category="${module_id%%:*}" name="${module_id#*:}"
    local module_file="${MODULE_ROOT}/scripts/modules/${category}/${name}.sh"
    local metadata_function="module_${name//-/_}_metadata"

    [[ -f "$module_file" ]] || return "$EXIT_BLOCKED"
    # shellcheck disable=SC1090
    source "$module_file"
    declare -f "$metadata_function" >/dev/null 2>&1 || return "$EXIT_BLOCKED"
    "$metadata_function" "$field"
}
