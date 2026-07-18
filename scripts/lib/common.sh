#!/usr/bin/env bash
# Shared constants and helpers used across all configure-host libraries.

if [[ -z "${_COMMON_SH_SOURCED:-}" ]]; then
    _COMMON_SH_SOURCED=1

    # Exit codes
    EXIT_OK=0
    EXIT_DRIFT=1
    EXIT_BLOCKED=2
    EXIT_INTERNAL=3

    # Status prefixes
    STATUS_CURRENT="CURRENT"
    STATUS_ABSENT="ABSENT"
    STATUS_DRIFT="DRIFT"
    STATUS_BLOCKED="BLOCKED"
    STATUS_CHANGED="CHANGED"
    STATUS_SKIP="SKIP"
    STATUS_INSTALL="INSTALL"
fi

# Run a command as root, escalating via sudo when not already root.
# Returns 2 if sudo is unavailable and EUID != 0.
run_as_root() {
    if [[ $EUID -eq 0 ]]; then
        "$@"
        return
    fi
    if ! command -v sudo >/dev/null 2>&1; then
        printf '%s sudo is required for: %s\n' "$STATUS_BLOCKED" "$*" >&2
        return "$EXIT_BLOCKED"
    fi
    sudo "$@"
}

# Acquire an exclusive flock on a per-user lock file.
# Usage: acquire_lock || { error "..."; return 2; }
# Release with: release_lock
_LOCK_FD=0
_LOCK_FILE=""

acquire_lock() {
    local uid runtime_dir lockfile owner
    uid="$(id -u)"
    runtime_dir="${XDG_RUNTIME_DIR:-/tmp/configure-host-$uid}"

    if [[ "$runtime_dir" == /tmp/configure-host-* ]]; then
        if [[ -e "$runtime_dir" ]]; then
            [[ -d "$runtime_dir" && ! -L "$runtime_dir" ]] || {
                printf '%s unsafe lock directory: %s\n' "$STATUS_BLOCKED" "$runtime_dir" >&2
                return "$EXIT_BLOCKED"
            }
            owner="$(stat -c '%u' "$runtime_dir" 2>/dev/null || printf unknown)"
            [[ "$owner" == "$uid" ]] || {
                printf '%s lock directory is not owned by uid %s: %s\n' \
                    "$STATUS_BLOCKED" "$uid" "$runtime_dir" >&2
                return "$EXIT_BLOCKED"
            }
        else
            (umask 077; mkdir "$runtime_dir") || return "$EXIT_BLOCKED"
        fi
        chmod 0700 "$runtime_dir" 2>/dev/null || true
    fi

    lockfile="$runtime_dir/configure-host.lock"
    if [[ -e "$lockfile" || -L "$lockfile" ]]; then
        [[ -f "$lockfile" && ! -L "$lockfile" ]] || {
            printf '%s unsafe lock file: %s\n' "$STATUS_BLOCKED" "$lockfile" >&2
            return "$EXIT_BLOCKED"
        }
    fi
    _LOCK_FILE="$lockfile"
    exec {_LOCK_FD}>"$lockfile"
    chmod 0600 "$lockfile" 2>/dev/null || true
    if ! flock -n "$_LOCK_FD"; then
        printf '%s another configure-host instance is running (lock: %s)\n' \
            "$STATUS_BLOCKED" "$lockfile" >&2
        eval "exec ${_LOCK_FD}>&-" 2>/dev/null || true
        _LOCK_FD=0
        return "$EXIT_BLOCKED"
    fi
}

release_lock() {
    [[ "$_LOCK_FD" -gt 0 ]] || return 0
    flock -u "$_LOCK_FD" 2>/dev/null || true
    eval "exec ${_LOCK_FD}>&-" 2>/dev/null || true
    _LOCK_FD=0
    _LOCK_FILE=""
}
