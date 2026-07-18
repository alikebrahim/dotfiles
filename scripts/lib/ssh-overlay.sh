#!/usr/bin/env bash
# Per-host SSH configuration as a constrained Stow component. Operational
# authorized_keys and known_hosts remain ignored and are never inspected here.

SSH_OVERLAY_ROOT=""
SSH_OVERLAY_HOME=""
SSH_OVERLAY_ID=""
SSH_OVERLAY_DIR=""
SSH_OVERLAY_PACKAGE=""
SSH_OVERLAY_VERBOSE=false

ssh_overlay_init() {
    SSH_OVERLAY_ROOT="$1"
    SSH_OVERLAY_HOME="$2"
    SSH_OVERLAY_ID="$3"
    SSH_OVERLAY_DIR=""
    SSH_OVERLAY_PACKAGE=""

    [[ -n "$SSH_OVERLAY_ID" && "$SSH_OVERLAY_ID" != /* && "$SSH_OVERLAY_ID" != *..* ]] || return 0
    if [[ "$SSH_OVERLAY_ID" == */* ]]; then
        SSH_OVERLAY_DIR="$SSH_OVERLAY_ROOT/ssh/${SSH_OVERLAY_ID%%/*}"
        SSH_OVERLAY_PACKAGE="${SSH_OVERLAY_ID#*/}"
    else
        SSH_OVERLAY_DIR="$SSH_OVERLAY_ROOT/ssh"
        SSH_OVERLAY_PACKAGE="$SSH_OVERLAY_ID"
    fi
}

ssh_overlay_exists() {
    [[ -n "$SSH_OVERLAY_PACKAGE" && -d "$SSH_OVERLAY_DIR/$SSH_OVERLAY_PACKAGE" ]]
}

ssh_overlay_status() {
    local source_dir source rel target
    local total=0 linked=0 missing=0 conflicts=0
    ssh_overlay_exists || {
        printf '%s SSH overlay %s is missing from the repository\n' "$STATUS_BLOCKED" "${SSH_OVERLAY_ID:-none}"
        return "$EXIT_BLOCKED"
    }
    source_dir="$SSH_OVERLAY_DIR/$SSH_OVERLAY_PACKAGE"
    while IFS= read -r -d '' source; do
        rel="${source#${source_dir}/}"
        target="$SSH_OVERLAY_HOME/$rel"
        ((total += 1))
        if [[ ! -e "$target" && ! -L "$target" ]]; then
            ((missing += 1))
            continue
        fi
        if [[ "$source" -ef "$target" ]]; then
            ((linked += 1))
        else
            ((conflicts += 1))
        fi
    done < <(find "$source_dir" \( -type f -o -type l \) -print0 2>/dev/null)

    if (( total == 0 )); then
        printf '%s SSH overlay %s has no managed files\n' "$STATUS_BLOCKED" "$SSH_OVERLAY_ID"
        return "$EXIT_BLOCKED"
    elif (( linked == total )); then
        printf '%s SSH overlay %s (%d/%d linked)\n' "$STATUS_CURRENT" "$SSH_OVERLAY_ID" "$linked" "$total"
        return 0
    elif (( linked == 0 && conflicts == 0 )); then
        printf '%s SSH overlay %s (0/%d linked)\n' "$STATUS_ABSENT" "$SSH_OVERLAY_ID" "$total"
    else
        printf '%s SSH overlay %s (%d/%d linked, %d missing, %d conflicts)\n' \
            "$STATUS_DRIFT" "$SSH_OVERLAY_ID" "$linked" "$total" "$missing" "$conflicts"
    fi
    return "$EXIT_DRIFT"
}

ssh_overlay_plan() {
    local output
    ssh_overlay_exists || return "$EXIT_BLOCKED"
    output="$(stow --simulate -v -R --dir="$SSH_OVERLAY_DIR" \
        --target="$SSH_OVERLAY_HOME" "$SSH_OVERLAY_PACKAGE" 2>&1)" || {
        printf '%s SSH overlay simulation failed: %s\n' "$STATUS_BLOCKED" "$SSH_OVERLAY_ID" >&2
        printf '%s\n' "$output" >&2
        return "$EXIT_BLOCKED"
    }
    printf '%s SSH overlay %s\n' "$STATUS_CURRENT" "$SSH_OVERLAY_ID"
    [[ "$SSH_OVERLAY_VERBOSE" == true && -n "$output" ]] && printf '%s\n' "$output"
    return "$EXIT_OK"
}

ssh_overlay_apply() {
    ssh_overlay_exists || return "$EXIT_BLOCKED"
    stow -R --dir="$SSH_OVERLAY_DIR" --target="$SSH_OVERLAY_HOME" "$SSH_OVERLAY_PACKAGE"
    printf '%s SSH overlay %s\n' "$STATUS_CHANGED" "$SSH_OVERLAY_ID"
}
