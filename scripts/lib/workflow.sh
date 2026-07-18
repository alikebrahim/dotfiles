#!/usr/bin/env bash
# Unified desired-state workflow. Interactive and command-line frontends call
# these functions; neither frontend performs mutations directly.

workflow_require_applyable_profile() {
    if [[ "${PROFILE_KNOWN:-false}" != true && "${ALLOW_UNKNOWN_HOST:-false}" != true ]]; then
        printf '%s unknown host %s; review the plan, then use --allow-unknown-host explicitly\n' \
            "$STATUS_BLOCKED" "${PROFILE_HOST:-unknown}" >&2
        return "$EXIT_BLOCKED"
    fi
    if [[ "${PROFILE_KNOWN:-false}" == true ]] && \
       [[ "$(profile_can_apply)" != true ]]; then
        printf '%s profile %s is not supported on %s\n' \
            "$STATUS_BLOCKED" "${PROFILE_NAME:-unknown}" "${PROFILE_OS_ID:-unknown}" >&2
        return "$EXIT_BLOCKED"
    fi
}

_workflow_manifest_record() {
    declare -F module_manifest_record >/dev/null 2>&1 || return "$EXIT_OK"
    module_manifest_record "$@"
}

workflow_apply_selected() {
    local rc=0 missing_tools="" module package output state tool
    local pending_stow=()
    local apply_ssh_overlay=false

    workflow_require_applyable_profile || return "$EXIT_BLOCKED"

    if (( ${#CONFIG_SELECTED_TOOLS[@]} > 0 )); then
        missing_tools="$(tools_missing_from "${CONFIG_SELECTED_TOOLS[*]}")"
        if [[ -n "$missing_tools" ]]; then
            for tool in $missing_tools; do
                package="$tool"
                if declare -F tool_package_for_os >/dev/null 2>&1; then
                    package="$(tool_package_for_os "$tool" "$PROFILE_OS_ID")"
                fi
                _workflow_manifest_record PACKAGE "${package:-$tool}" ABSENT
            done
            tools_install "$PROFILE_OS_ID" "$missing_tools" || rc=$?
        fi
    fi

    for package in "${CONFIG_SELECTED_STOW[@]}"; do
        output="$(workflow_dotfile_status "$package" 2>&1)" || true
        state="$(_workflow_state_from_output "$output")"
        case "$state" in
            "$STATUS_CURRENT") printf '%s %s [dotfile]\n' "$STATUS_CURRENT" "$package" ;;
            "$STATUS_BLOCKED") printf '%s\n' "$output"; rc="$EXIT_BLOCKED" ;;
            *)
                if [[ "$package" == ssh-overlay ]]; then
                    apply_ssh_overlay=true
                else
                    pending_stow+=("$package")
                fi
                ;;
        esac
    done
    if (( ${#pending_stow[@]} > 0 )); then
        for package in "${pending_stow[@]}"; do
            output="$(stow_package_status "$package" 2>&1)" || true
            _workflow_manifest_record STOW "$package" "$(_workflow_state_from_output "$output")"
        done
        stow_apply_packages "${pending_stow[@]}" || rc=$?
    fi
    if [[ "$apply_ssh_overlay" == true ]]; then
        output="$(ssh_overlay_status 2>&1)" || true
        _workflow_manifest_record STOW ssh-overlay "$(_workflow_state_from_output "$output")"
        if ssh_overlay_apply; then
            :
        else
            printf '%s SSH overlay apply failed; re-run plan/status for ssh-overlay\n' \
                "$STATUS_BLOCKED" >&2
            rc="$EXIT_BLOCKED"
        fi
    fi

    for module in "${CONFIG_SELECTED_MODULES[@]}"; do
        output="$(module_run "$module" status 2>&1)" || true
        state="$(_workflow_state_from_output "$output")"
        case "$state" in
            "$STATUS_CURRENT") printf '%s %s [module]\n' "$STATUS_CURRENT" "$module" ;;
            "$STATUS_BLOCKED") printf '%s\n' "$output"; rc="$EXIT_BLOCKED" ;;
            *) module_run "$module" apply || rc=$? ;;
        esac
    done

    return "$rc"
}

workflow_verify_selected() {
    local rc=0 tool module

    for tool in "${CONFIG_SELECTED_TOOLS[@]}"; do
        if tool_is_installed "$tool"; then
            printf '%s %s [tool]\n' "$STATUS_CURRENT" "$tool"
        else
            printf '%s %s [tool]\n' "$STATUS_ABSENT" "$tool"
            rc="$EXIT_DRIFT"
        fi
    done

    local package
    for package in "${CONFIG_SELECTED_STOW[@]}"; do
        workflow_dotfile_status "$package" || rc="$EXIT_DRIFT"
    done

    for module in "${CONFIG_SELECTED_MODULES[@]}"; do
        module_run "$module" verify || rc="$EXIT_DRIFT"
    done

    return "$rc"
}

_workflow_state_from_output() {
    local output="$1"
    if grep -q '^BLOCKED' <<< "$output"; then
        printf '%s' "$STATUS_BLOCKED"
    elif grep -Eq '^(ABSENT|DRIFT)' <<< "$output"; then
        grep -Eo '^(ABSENT|DRIFT)' <<< "$output" | head -1
    else
        printf '%s' "$STATUS_CURRENT"
    fi
}

_workflow_one_line() {
    tr '\n\t' '  ' <<< "$1" | sed -E 's/[[:space:]]+$//'
}

workflow_validate_selected_plan() {
    local package module output rc=0
    for package in "${CONFIG_SELECTED_STOW[@]}"; do
        if [[ "$package" == ssh-overlay ]]; then
            if ! output="$(ssh_overlay_plan 2>&1)"; then
                printf '%s plan validation failed for ssh-overlay: %s\n' \
                    "$STATUS_BLOCKED" "$(_workflow_one_line "$output")" >&2
                rc="$EXIT_BLOCKED"
            fi
        else
            if ! output="$(stow_simulate_package "$package" 2>&1)"; then
                printf '%s plan validation failed for Stow package %s\n' \
                    "$STATUS_BLOCKED" "$package" >&2
                printf '%s\n' "$output" >&2
                stow_package_conflict_report "$package" 2>&1 || true
                rc="$EXIT_BLOCKED"
            fi
        fi
    done
    for module in "${CONFIG_SELECTED_MODULES[@]}"; do
        output="$(module_run "$module" plan 2>&1)" || true
        if [[ "$(_workflow_state_from_output "$output")" == "$STATUS_BLOCKED" ]]; then
            printf '%s plan validation failed for %s: %s\n' \
                "$STATUS_BLOCKED" "$module" "$(_workflow_one_line "$output")" >&2
            rc="$EXIT_BLOCKED"
        fi
    done
    return "$rc"
}

workflow_dotfile_status() {
    local package="$1"
    if [[ "$package" == ssh-overlay ]]; then
        ssh_overlay_status
    else
        stow_package_status "$package"
    fi
}

workflow_collect_records() {
    local tool package module output state label description privilege risk

    for tool in "${CONFIG_SELECTED_TOOLS[@]}"; do
        if tool_is_installed "$tool"; then state="$STATUS_CURRENT"; else state="$STATUS_ABSENT"; fi
        printf 'tool\t%s\t%s\troot\tlow\t%s\t%s\n' \
            "$tool" "$state" "$tool" "${TOOL_DESC[$tool]:-Tool package}"
    done

    for package in "${CONFIG_SELECTED_STOW[@]}"; do
        output="$(workflow_dotfile_status "$package" 2>&1)" || true
        state="$(_workflow_state_from_output "$output")"
        description="${STOW_CATALOG_DESC[$package]:-Dotfile package}"
        [[ "$state" == "$STATUS_CURRENT" ]] || description+="; $(_workflow_one_line "$output")"
        if [[ "$package" != ssh-overlay && "$state" == "$STATUS_DRIFT" ]] && \
           declare -F stow_package_conflict_report >/dev/null 2>&1; then
            local conflict_lines
            conflict_lines="$(stow_package_conflict_report "$package" 2>/dev/null | head -5 | tr '\n' '; ')"
            [[ -n "$conflict_lines" ]] && description+="; ${conflict_lines}"
        fi
        printf 'dotfile\t%s\t%s\tuser\tlow\t%s\t%s\n' \
            "$package" "$state" \
            "${STOW_CATALOG_LABEL[$package]:-$package}" \
            "$description"
    done

    for module in "${CONFIG_SELECTED_MODULES[@]}"; do
        output="$(module_run "$module" status 2>&1)" || true
        state="$(_workflow_state_from_output "$output")"
        label="$(module_metadata "$module" label)"
        description="$(module_metadata "$module" description)"
        privilege="$(module_metadata "$module" privilege)"
        risk="$(module_metadata "$module" risk)"
        [[ "$state" == "$STATUS_CURRENT" ]] || description+="; $(_workflow_one_line "$output")"
        printf 'module\t%s\t%s\t%s\t%s\t%s\t%s\n' \
            "$module" "$state" "$privilege" "$risk" "$label" "$description"
    done
}

workflow_plan_selected() {
    local records kind id state privilege risk label description display_kind
    local current=0 changes=0 blocked=0 requires_root=no
    local change_lines=()
    local conflict_block="" package

    records="$(workflow_collect_records)"
    while IFS=$'\t' read -r kind id state privilege risk label description; do
        [[ -n "$kind" ]] || continue
        case "$state" in
            "$STATUS_CURRENT") ((current += 1)) ;;
            "$STATUS_BLOCKED") ((blocked += 1)) ;;
            *) ((changes += 1)) ;;
        esac
        [[ "$state" == "$STATUS_CURRENT" ]] && continue
        [[ "$privilege" == root ]] && requires_root=yes
        case "$kind" in
            tool) display_kind=TOOL ;;
            dotfile) display_kind=DOTFILE ;;
            module)
                [[ "$id" == system:* ]] && display_kind=SYSTEM || display_kind=USER
                ;;
        esac
        change_lines+=("[$display_kind] $label — $description [$state; risk=$risk]")
    done <<< "$records"

    for package in "${CONFIG_SELECTED_STOW[@]}"; do
        [[ "$package" == ssh-overlay ]] && continue
        declare -F stow_package_conflict_report >/dev/null 2>&1 || continue
        while IFS= read -r line; do
            [[ -n "$line" ]] || continue
            conflict_block+="$line"$'\n'
        done < <(stow_package_conflict_report "$package" 2>/dev/null || true)
    done

    printf 'CONFIGURE-HOST PLAN\n'
    printf 'Profile: %s  Host: %s  OS: %s %s\n' \
        "${PROFILE_NAME:-unknown}" "${PROFILE_HOST:-unknown}" \
        "${PROFILE_OS_ID:-unknown}" "${PROFILE_OS_VERSION:-unknown}"
    printf 'Selected: %d tools | %d dotfiles | %d system/user components\n' \
        "${#CONFIG_SELECTED_TOOLS[@]}" "${#CONFIG_SELECTED_STOW[@]}" \
        "${#CONFIG_SELECTED_MODULES[@]}"
    printf 'Current: %d | Changes: %d | Blocked: %d\n' "$current" "$changes" "$blocked"
    printf 'Requires root: %s\n' "$requires_root"
    printf '\nPROPOSED CHANGES\n'
    if (( ${#change_lines[@]} == 0 )); then
        printf 'No changes are required.\n'
    else
        printf '%s\n' "${change_lines[@]}"
    fi
    if [[ -n "$conflict_block" ]]; then
        printf '\nSTOW CONFLICTS (real targets that block restow; --adopt is refused)\n'
        printf '%s' "$conflict_block"
    fi
    printf '\nNo changes are made by plan mode.\n'
    printf 'NOTE: package installs, Stow links, and service state are not auto-rolled back.\n'
    printf 'NOTE: tmux plugins are not applied here; use: update tmux-plugins\n'
    printf 'NOTE: wait for Syncthing sync before applying on other hosts.\n'
}

# Print high-risk modules that would mutate (not CURRENT/BLOCKED).
workflow_high_risk_pending_lines() {
    local kind id state privilege risk label description
    while IFS=$'\t' read -r kind id state privilege risk label description; do
        [[ "$kind" == module ]] || continue
        [[ "$risk" == high ]] || continue
        [[ "$state" != "$STATUS_CURRENT" && "$state" != "$STATUS_BLOCKED" ]] || continue
        printf '%s (%s) — %s\n' "$id" "$label" "$description"
    done < <(workflow_collect_records)
}

workflow_has_high_risk_pending() {
    [[ -n "$(workflow_high_risk_pending_lines)" ]]
}
