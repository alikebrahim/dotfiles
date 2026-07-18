#!/usr/bin/env bash
# Durable, failure-safe execution wrapper for mutating operations.

RUNNER_STATE_ROOT=""
RUNNER_PROFILE=""
RUNNER_LAST_RUN_DIR=""
RUNNER_LAST_LOG=""
RUNNER_LAST_RC=0
RUNNER_PID=""
RUNNER_ACTIVE_LABEL=""
RUNNER_STARTED=""
CONFIGURE_HOST_BACKUP_DIR=""
CONFIGURE_HOST_ROLLBACK_MANIFEST=""

runner_init() {
    RUNNER_STATE_ROOT="$1"
    RUNNER_PROFILE="${2:-unknown}"
}

_runner_safe_label() {
    printf '%s' "$1" | tr -cs 'A-Za-z0-9._-' '-'
}

_runner_write_metadata() {
    local label="$1" started="$2" finished="$3" rc="$4"
    cat > "$RUNNER_LAST_RUN_DIR/metadata" <<EOF
label=$label
profile=$RUNNER_PROFILE
started=$started
finished=$finished
exit_code=$rc
log=$RUNNER_LAST_LOG
backup_dir=$CONFIGURE_HOST_BACKUP_DIR
rollback_manifest=$CONFIGURE_HOST_ROLLBACK_MANIFEST
EOF
    chmod 0600 "$RUNNER_LAST_RUN_DIR/metadata"
}

_runner_prepare() {
    local label="$1" requires_root="$2"
    local run_id safe_label

    [[ -n "$RUNNER_STATE_ROOT" ]] || {
        printf '%s runner_init must be called before starting a job\n' "$STATUS_BLOCKED" >&2
        return "$EXIT_INTERNAL"
    }

    RUNNER_STARTED="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    RUNNER_ACTIVE_LABEL="$label"
    safe_label="$(_runner_safe_label "$label")"
    run_id="$(date -u +%Y%m%dT%H%M%SZ)-${safe_label}-$$-${RANDOM}"
    RUNNER_LAST_RUN_DIR="$RUNNER_STATE_ROOT/runs/$run_id"
    RUNNER_LAST_LOG="$RUNNER_LAST_RUN_DIR/output.log"
    CONFIGURE_HOST_BACKUP_DIR="$RUNNER_LAST_RUN_DIR/backup"
    CONFIGURE_HOST_ROLLBACK_MANIFEST="$RUNNER_LAST_RUN_DIR/rollback.tsv"

    umask 077
    mkdir -p "$RUNNER_STATE_ROOT/runs"
    chmod 0700 "$RUNNER_STATE_ROOT" "$RUNNER_STATE_ROOT/runs" 2>/dev/null || true
    mkdir -p "$RUNNER_LAST_RUN_DIR" "$CONFIGURE_HOST_BACKUP_DIR"
    chmod 0700 "$RUNNER_LAST_RUN_DIR" "$CONFIGURE_HOST_BACKUP_DIR"
    : > "$RUNNER_LAST_LOG"
    : > "$CONFIGURE_HOST_ROLLBACK_MANIFEST"
    chmod 0600 "$RUNNER_LAST_LOG" "$CONFIGURE_HOST_ROLLBACK_MANIFEST"

    if ! acquire_lock; then
        RUNNER_LAST_RC="$EXIT_BLOCKED"
        printf '%s another configure-host operation is running\n' "$STATUS_BLOCKED" > "$RUNNER_LAST_LOG"
        _runner_write_metadata "$label" "$RUNNER_STARTED" \
            "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$RUNNER_LAST_RC"
        return "$EXIT_BLOCKED"
    elif [[ "$requires_root" == true ]] && ! run_as_root true >> "$RUNNER_LAST_LOG" 2>&1; then
        RUNNER_LAST_RC="$EXIT_BLOCKED"
        printf '%s root authorization was not granted\n' "$STATUS_BLOCKED" >> "$RUNNER_LAST_LOG"
        release_lock
        _runner_write_metadata "$label" "$RUNNER_STARTED" \
            "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$RUNNER_LAST_RC"
        return "$EXIT_BLOCKED"
    fi
}

runner_start() {
    local label="$1" requires_root="$2"
    shift 2
    _runner_prepare "$label" "$requires_root" || return $?
    "$@" > "$RUNNER_LAST_LOG" 2>&1 &
    RUNNER_PID=$!
}

runner_wait() {
    local rc=0 had_errexit=false finished
    [[ "$RUNNER_PID" =~ ^[0-9]+$ ]] || return "$EXIT_INTERNAL"

    [[ $- == *e* ]] && had_errexit=true
    set +e
    wait "$RUNNER_PID"
    rc=$?
    $had_errexit && set -e
    RUNNER_PID=""
    release_lock

    RUNNER_LAST_RC="$rc"
    finished="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    _runner_write_metadata "$RUNNER_ACTIVE_LABEL" "$RUNNER_STARTED" "$finished" "$rc"
    return "$rc"
}

runner_cancel() {
    if [[ "$RUNNER_PID" =~ ^[0-9]+$ ]]; then
        kill "$RUNNER_PID" 2>/dev/null || true
        runner_wait >/dev/null 2>&1 || true
    else
        release_lock
    fi
}

runner_run() {
    local label="$1" requires_root="$2"
    shift 2
    runner_start "$label" "$requires_root" "$@" || return $?
    runner_wait
}

runner_list_runs() {
    [[ -d "$RUNNER_STATE_ROOT/runs" ]] || return 0
    local run_dir metadata label profile started rc
    for run_dir in "$RUNNER_STATE_ROOT"/runs/*; do
        [[ -d "$run_dir" && -r "$run_dir/metadata" ]] || continue
        metadata="$run_dir/metadata"
        label="$(sed -n 's/^label=//p' "$metadata")"
        profile="$(sed -n 's/^profile=//p' "$metadata")"
        started="$(sed -n 's/^started=//p' "$metadata")"
        rc="$(sed -n 's/^exit_code=//p' "$metadata")"
        printf '%s\t%s\t%s\t%s\t%s\n' "$(basename "$run_dir")" "$started" "$profile" "$label" "$rc"
    done | sort -r
}
