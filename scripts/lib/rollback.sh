#!/usr/bin/env bash
# Restore system files recorded by a configure-host run. Package installs,
# Stow operations, and service changes are reported but never auto-reversed.

rollback_apply_manifest() {
    local manifest="$1" system_root="${2:-/}"
    local kind target state backup mode uid gid resolved_target run_root backup_root backup_real root_real rc=0

    [[ -r "$manifest" ]] || {
        printf '%s rollback manifest is not readable: %s\n' "$STATUS_BLOCKED" "$manifest" >&2
        return "$EXIT_BLOCKED"
    }

    run_root="$(cd "$(dirname "$manifest")" && pwd)"
    backup_root="$(realpath -m "$run_root/backup")"
    root_real="$(realpath -m "$system_root")"
    while IFS=$'\t' read -r kind target state backup mode uid gid; do
        [[ "$kind" == FILE ]] || continue
        [[ "$target" == /* && "/${target#/}/" != *'/../'* ]] || {
            printf '%s unsafe rollback target: %s\n' "$STATUS_BLOCKED" "$target" >&2
            rc="$EXIT_BLOCKED"
            continue
        }
        resolved_target="$(realpath -m "${root_real%/}${target}")"
        if [[ "$root_real" != / && "$resolved_target" != "$root_real"/* ]]; then
            printf '%s rollback target escapes system root: %s\n' "$STATUS_BLOCKED" "$target" >&2
            rc="$EXIT_BLOCKED"
            continue
        fi

        case "$state" in
            PRESENT)
                backup_real="$(realpath -e "$backup" 2>/dev/null)" || backup_real=""
                [[ "$backup_real" == "$backup_root"/* && -f "$backup_real" ]] || {
                    printf '%s invalid rollback backup for %s\n' "$STATUS_BLOCKED" "$target" >&2
                    rc="$EXIT_BLOCKED"
                    continue
                }
                [[ "$mode" =~ ^[0-7]{3,4}$ && "$uid" =~ ^[0-9]+$ && "$gid" =~ ^[0-9]+$ ]] || {
                    printf '%s invalid rollback metadata for %s\n' "$STATUS_BLOCKED" "$target" >&2
                    rc="$EXIT_BLOCKED"
                    continue
                }
                if [[ "$system_root" != / || $EUID -eq 0 ]]; then
                    install -D -m "$mode" "$backup_real" "$resolved_target"
                    [[ "$system_root" != / ]] || chown "$uid:$gid" "$resolved_target"
                else
                    run_as_root install -D -m "$mode" "$backup_real" "$resolved_target"
                    run_as_root chown "$uid:$gid" "$resolved_target"
                fi
                printf '%s restored %s\n' "$STATUS_CHANGED" "$target"
                ;;
            ABSENT)
                if [[ "$system_root" != / || $EUID -eq 0 ]]; then
                    rm -f "$resolved_target"
                else
                    run_as_root rm -f "$resolved_target"
                fi
                printf '%s removed newly created %s\n' "$STATUS_CHANGED" "$target"
                ;;
            *)
                printf '%s unknown rollback state for %s: %s\n' \
                    "$STATUS_BLOCKED" "$target" "$state" >&2
                rc="$EXIT_BLOCKED"
                ;;
        esac
    done < "$manifest"

    return "$rc"
}

rollback_manifest_has_files() {
    local manifest="$1"
    [[ -r "$manifest" ]] || return 1
    grep -q $'^FILE\t' "$manifest"
}

rollback_describe_manifest() {
    local manifest="$1" kind target state backup mode uid gid
    [[ -r "$manifest" ]] || return "$EXIT_BLOCKED"
    while IFS=$'\t' read -r kind target state backup mode uid gid; do
        case "$kind" in
            FILE)
                case "$state" in
                    PRESENT) printf 'RESTORE %s from backup\n' "$target" ;;
                    ABSENT) printf 'REMOVE newly created %s\n' "$target" ;;
                esac
                ;;
            PACKAGE) printf 'REVIEW installed package %s (previously %s; retained)\n' "$target" "$state" ;;
            STOW) printf 'REVIEW Stow package %s (previously %s; links not auto-reversed)\n' "$target" "$state" ;;
            SERVICE) printf 'REVIEW %s service %s was %s/%s (not auto-restored)\n' "$target" "$state" "$backup" "$mode" ;;
        esac
    done < "$manifest"
    printf 'NOTE package installs, Stow links, and service state are not automatically reversed.\n'
    printf 'NOTE rollback restores only FILE entries backed up before system-file replacement.\n'
    printf 'NOTE to undo Stow links use: configure-host prune --stow-package NAME (explicit, double-confirm).\n'
    printf 'NOTE to undo packages/services, reverse them manually (dnf/systemctl) after review.\n'
}
