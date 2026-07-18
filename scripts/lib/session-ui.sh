#!/usr/bin/env bash
# Goal-oriented interactive session. This file renders and stages choices;
# all inspection and mutation is delegated to shared workflow/runner functions.

SESSION_CHOICE=""

session_menu_choice() {
    local header="$1"
    shift
    SESSION_CHOICE=""
    SESSION_CHOICE="$(ui_choose "$header" "$@")" || return 1
    [[ -n "$SESSION_CHOICE" ]]
}

session_count_state() {
    local records="$1" kind_filter="$2" state_filter="$3"
    awk -F '\t' -v kind="$kind_filter" -v state="$state_filter" \
        '$1 == kind && $3 == state { count += 1 } END { print count + 0 }' <<< "$records"
}

session_dashboard() {
    local records missing_prereqs prereq_total=5
    local tool_current dotfile_current module_current
    records="$(workflow_collect_records)"
    missing_prereqs="$(bootstrap_status | awk -v absent="$STATUS_ABSENT" '$1 == absent { count += 1 } END { print count + 0 }')"
    tool_current="$(session_count_state "$records" tool "$STATUS_CURRENT")"
    dotfile_current="$(session_count_state "$records" dotfile "$STATUS_CURRENT")"
    module_current="$(session_count_state "$records" module "$STATUS_CURRENT")"

    ui_footer "Host: $PROFILE_HOST  |  Profile: $PROFILE_NAME  |  $PROFILE_OS_ID $PROFILE_OS_VERSION"
    ui_footer "Prerequisites: $((prereq_total - missing_prereqs))/$prereq_total  |  Tools: ${tool_current}/${#CONFIG_SELECTED_TOOLS[@]}  |  Dotfiles: ${dotfile_current}/${#CONFIG_SELECTED_STOW[@]}  |  System/user: ${module_current}/${#CONFIG_SELECTED_MODULES[@]}"
}

session_run() {
    if ! ui_should_use_gum; then
        workflow_plan_selected
        return
    fi

    ui_session_init
    while true; do
        ui_clear
        ui_header "CONFIGURE HOST" "Detect → Select → Review → Apply → Verify"
        session_dashboard
        if ! session_menu_choice "Esc: quit  •  Enter: open" \
            "Set up this machine" \
            "Customize setup" \
            "Inspect and repair" \
            "Updates" \
            "Advanced and logs" \
            "Quit"; then
            break
        fi
        case "$SESSION_CHOICE" in
            "Set up this machine") session_set_up_machine ;;
            "Customize setup") session_customize ;;
            "Inspect and repair") session_inspect_repair ;;
            "Updates") session_updates ;;
            "Advanced and logs") session_advanced ;;
            "Quit") break ;;
        esac
    done
}

session_status_file() {
    local outfile="$1"
    {
        printf 'Kind\tComponent\tStatus\tPrivilege\tRisk\tDescription\n'
        workflow_collect_records
    } | if command -v column >/dev/null 2>&1; then
        column -t -s $'\t'
    else
        cat
    fi > "$outfile"
}

session_plan_file() {
    local outfile="$1"
    workflow_plan_selected > "$outfile" 2>&1
}

session_requires_root_changes() {
    local kind id state privilege risk label description
    while IFS=$'\t' read -r kind id state privilege risk label description; do
        [[ "$state" != "$STATUS_CURRENT" && "$state" != "$STATUS_BLOCKED" && "$privilege" == root ]] && return 0
    done < <(workflow_collect_records)
    return 1
}

session_has_blocked() {
    grep -q $'\tBLOCKED\t' < <(workflow_collect_records)
}

session_worker_apply_verify() {
    local apply_rc=0 verify_rc=0
    printf '=== APPLY ===\n'
    workflow_apply_selected || apply_rc=$?
    printf '\n=== VERIFY ===\n'
    workflow_verify_selected || verify_rc=$?
    (( apply_rc != 0 )) && return "$apply_rc"
    return "$verify_rc"
}

session_run_job() {
    local title="$1" requires_root="$2"
    shift 2
    local rc=0

    if ! runner_start "$title" "$requires_root" "$@"; then
        [[ -n "$RUNNER_LAST_LOG" && -f "$RUNNER_LAST_LOG" ]] && ui_pager "$title — blocked" "$RUNNER_LAST_LOG"
        return "$EXIT_BLOCKED"
    fi

    if ! ui_wait_for_pid "$title" "$RUNNER_PID"; then
        runner_cancel
        ui_pager "$title — cancelled" "$RUNNER_LAST_LOG"
        return "$EXIT_BLOCKED"
    fi
    runner_wait || rc=$?
    if (( rc == 0 )); then
        ui_pager "$title — complete" "$RUNNER_LAST_LOG"
    else
        ui_pager "$title — failed (exit $rc)" "$RUNNER_LAST_LOG"
    fi
    return "$rc"
}

session_review_apply() {
    local plan_file="${SESSION_TMPDIR}/review-plan.txt"
    local validate_file="${SESSION_TMPDIR}/review-validate.txt"
    local review_file="${SESSION_TMPDIR}/review-combined.txt"
    local requires_root=false
    local validate_rc=0
    local high_risk_lines=""

    set +e
    workflow_validate_selected_plan >"$validate_file" 2>&1
    validate_rc=$?
    set -e
    session_plan_file "$plan_file"

    {
        if (( validate_rc != 0 )); then
            printf 'PLAN VALIDATION FAILED (Stow simulation / module plan)\n'
            cat "$validate_file"
            printf '\n'
        fi
        cat "$plan_file"
    } >"$review_file"

    if (( validate_rc != 0 )); then
        ui_pager "Review setup plan (validation failed)" "$review_file"
        ui_pager "Setup blocked" "Resolve Stow simulation failures, BLOCKED components, or remove them from the selection before applying."
        return
    fi

    ui_pager "Review setup plan" "$review_file"

    if session_has_blocked; then
        ui_pager "Setup blocked" "Resolve BLOCKED components or remove them from the selection before applying."
        return
    fi
    session_requires_root_changes && requires_root=true
    ui_confirm "Apply the reviewed selection for '$PROFILE_NAME'?" "Apply" "Cancel" || return

    high_risk_lines="$(workflow_high_risk_pending_lines)"
    if [[ -n "$high_risk_lines" ]]; then
        ui_pager "High-risk modules" "These may install packages or start services immediately:

$high_risk_lines

Package installs, Stow links, and service state are not auto-rolled back."
        ui_confirm "Proceed with high-risk module changes?" "Proceed" "Cancel" || return
    fi

    session_run_job "Apply and verify" "$requires_root" session_worker_apply_verify || true
}

session_set_up_machine() {
    selection_reset_recommended
    local missing=()
    mapfile -t missing < <(bootstrap_missing_packages)
    if (( ${#missing[@]} > 0 )); then
        local plan_file="${SESSION_TMPDIR}/bootstrap-plan.txt"
        bootstrap_plan_for "$PROFILE_OS_ID" "${missing[@]}" > "$plan_file" 2>&1 || true
        ui_pager "Configurator prerequisites" "$plan_file"
        ui_confirm "Install required configurator packages first?" "Install" "Cancel" || return
        session_run_job "Install prerequisites" true bootstrap_apply_for "$PROFILE_OS_ID" "${missing[@]}" || return
    fi
    session_review_apply
}

session_component_options() {
    local kind="$1" id output state label description
    case "$kind" in
        tool)
            for id in "${CONFIG_AVAILABLE_TOOLS[@]}"; do
                tool_is_installed "$id" && state="$STATUS_CURRENT" || state="$STATUS_ABSENT"
                printf '%s\t[%s] %s — %s\n' "$id" "$state" "$id" "${TOOL_DESC[$id]}"
            done
            ;;
        stow)
            for id in "${CONFIG_AVAILABLE_STOW[@]}"; do
                output="$(workflow_dotfile_status "$id" 2>&1)" || true
                state="$(_workflow_state_from_output "$output")"
                printf '%s\t[%s] %s — %s\n' "$id" "$state" \
                    "${STOW_CATALOG_LABEL[$id]}" "${STOW_CATALOG_DESC[$id]}"
            done
            ;;
        module)
            for id in "${CONFIG_AVAILABLE_MODULES[@]}"; do
                output="$(module_run "$id" status 2>&1)" || true
                state="$(_workflow_state_from_output "$output")"
                label="$(module_metadata "$id" label)"
                description="$(module_metadata "$id" description)"
                printf '%s\t[%s] %s — %s; %s risk; %s\n' "$id" "$state" "$label" \
                    "$description" "$(module_metadata "$id" risk)" "$(module_metadata "$id" impact)"
            done
            ;;
    esac
}

session_select_components() {
    local kind="$1" title="$2"
    local options=() preselected=() selected="" line id current
    mapfile -t options < <(session_component_options "$kind")
    case "$kind" in
        tool) current=("${CONFIG_SELECTED_TOOLS[@]}") ;;
        stow) current=("${CONFIG_SELECTED_STOW[@]}") ;;
        module) current=("${CONFIG_SELECTED_MODULES[@]}") ;;
    esac

    for line in "${options[@]}"; do
        id="${line%%$'\t'*}"
        _selection_contains "$id" "${current[@]}" && preselected+=("$line")
    done

    selected="$(ui_choose_multi_preselected "$title — Space: toggle; Enter: save; Esc: cancel" \
        preselected options)" || return
    local selected_ids=()
    while IFS= read -r line; do
        [[ -n "$line" ]] || continue
        selected_ids+=("${line%%$'\t'*}")
    done <<< "$selected"
    selection_set "$kind" "${selected_ids[@]}"
}

session_customize() {
    while true; do
        ui_clear
        ui_header "CUSTOMIZE SETUP" "Selections are staged until Review and apply"
        ui_footer "Selected: ${#CONFIG_SELECTED_TOOLS[@]} tools  |  ${#CONFIG_SELECTED_STOW[@]} dotfiles  |  ${#CONFIG_SELECTED_MODULES[@]} system/user components"
        if ! session_menu_choice "Esc: back" \
            "Select tools and applications" \
            "Select dotfile packages" \
            "Select system and user configuration" \
            "Review and apply" \
            "Reset to recommended setup" \
            "Clear all selections" \
            "Back"; then
            return
        fi
        case "$SESSION_CHOICE" in
            "Select tools and applications") session_select_components tool "Tools and applications" ;;
            "Select dotfile packages") session_select_components stow "Dotfile packages" ;;
            "Select system and user configuration") session_select_components module "System and user configuration" ;;
            "Review and apply") session_review_apply ;;
            "Reset to recommended setup") selection_reset_recommended ;;
            "Clear all selections") CONFIG_SELECTED_TOOLS=(); CONFIG_SELECTED_STOW=(); CONFIG_SELECTED_MODULES=() ;;
            "Back") return ;;
        esac
    done
}

session_inspect_repair() {
    while true; do
        ui_clear
        ui_header "INSPECT AND REPAIR" "Read-only inspection unless Repair is confirmed"
        if ! session_menu_choice "Esc: back" \
            "View full component status" \
            "Preview recommended repairs" \
            "Repair recommended setup" \
            "Verify current selection" \
            "Back"; then
            return
        fi
        case "$SESSION_CHOICE" in
            "View full component status")
                session_status_file "${SESSION_TMPDIR}/status.txt"
                ui_pager "Component status" "${SESSION_TMPDIR}/status.txt"
                ;;
            "Preview recommended repairs")
                selection_reset_recommended
                session_plan_file "${SESSION_TMPDIR}/repair-plan.txt"
                ui_pager "Recommended repairs" "${SESSION_TMPDIR}/repair-plan.txt"
                ;;
            "Repair recommended setup") selection_reset_recommended; session_review_apply ;;
            "Verify current selection") ui_run_to_pager "Verification" workflow_verify_selected ;;
            "Back") return ;;
        esac
    done
}

session_updates() {
    while true; do
        ui_clear
        ui_header "UPDATES" "Explicitly refresh mutable third-party state"
        if ! session_menu_choice "Esc: back" \
            "Check profile tools" \
            "Update tmux plugins" \
            "Back"; then
            return
        fi
        case "$SESSION_CHOICE" in
            "Check profile tools") ui_run_to_pager "Profile tools" tools_check_profile "${CONFIG_SELECTED_TOOLS[*]}" ;;
            "Update tmux plugins")
                workflow_require_applyable_profile || { ui_pager "Update blocked" "This profile cannot be changed."; continue; }
                ui_confirm "Fast-forward managed tmux plugin checkouts?" "Update" "Cancel" || continue
                session_run_job "Update tmux plugins" false bash "${DOTFILES}/scripts/install-tmux-plugins.sh" --update || true
                ;;
            "Back") return ;;
        esac
    done
}

session_profile_report() {
    printf 'Profile: %s\nHost: %s\nUser: %s\nOS: %s %s\nTheme: %s\nTool set: %s\nSSH overlay: %s\n' \
        "$PROFILE_NAME" "$PROFILE_HOST" "$PROFILE_USER" "$PROFILE_OS_ID" "$PROFILE_OS_VERSION" \
        "$UI_THEME" "${PROFILE_TOOL_SET:-none}" "${PROFILE_SSH_OVERLAY:-none}"
    printf 'Recommended dotfiles: %s\n' "${PROFILE_STOW_PACKAGES[*]:-none}"
    printf 'Recommended modules: %s\n' "${PROFILE_MODULES[*]:-none}"
}

session_history_file() {
    local outfile="$1"
    {
        printf 'Run ID\tStarted (UTC)\tProfile\tAction\tExit\n'
        runner_list_runs
    } | if command -v column >/dev/null 2>&1; then column -t -s $'\t'; else cat; fi > "$outfile"
}

session_latest_run_log() {
    local row run_id
    row="$(runner_list_runs | head -1)"
    [[ -n "$row" ]] || { ui_pager "Run history" "No completed runs have been recorded."; return; }
    run_id="${row%%$'\t'*}"
    ui_pager "Latest run: $run_id" "$RUNNER_STATE_ROOT/runs/$run_id/output.log"
}

session_rollback() {
    local choices=() row run_id run_dir manifest selected plan_file
    while IFS= read -r row; do
        [[ -n "$row" ]] || continue
        run_id="${row%%$'\t'*}"
        run_dir="$RUNNER_STATE_ROOT/runs/$run_id"
        rollback_manifest_has_files "$run_dir/rollback.tsv" && choices+=("$row")
    done < <(runner_list_runs)
    (( ${#choices[@]} > 0 )) || { ui_pager "Rollback" "No run contains restorable system-file backups."; return; }
    selected="$(ui_choose "Select a run to inspect; Esc: back" "${choices[@]}")" || return
    run_id="${selected%%$'\t'*}"
    run_dir="$RUNNER_STATE_ROOT/runs/$run_id"
    manifest="$run_dir/rollback.tsv"
    plan_file="${SESSION_TMPDIR}/rollback-plan.txt"
    rollback_describe_manifest "$manifest" > "$plan_file"
    ui_pager "Rollback plan: $run_id" "$plan_file"
    ui_confirm "Restore the listed system files?" "Restore" "Cancel" || return
    session_run_job "Rollback $run_id" true rollback_apply_manifest "$manifest" "$SYSTEM_ROOT" || true
}

session_technical_plan() {
    local package module
    workflow_plan_selected
    printf '\nTECHNICAL DETAILS\n'
    for package in "${CONFIG_SELECTED_STOW[@]}"; do
        printf '\n-- Stow: %s --\n' "$package"
        if [[ "$package" == ssh-overlay ]]; then
            SSH_OVERLAY_VERBOSE=true ssh_overlay_plan || true
        else
            STOW_VERBOSE=true stow_simulate_package "$package" || true
        fi
    done
    for module in "${CONFIG_SELECTED_MODULES[@]}"; do
        printf '\n-- Module: %s --\n' "$module"
        module_run "$module" plan || true
    done
}

session_prune() {
    local options=() preselected=() selected="" line id selected_ids=()
    local package rc=0

    workflow_require_applyable_profile || {
        ui_pager "Prune blocked" "This profile cannot be changed."
        return
    }

    for id in "${CONFIG_AVAILABLE_STOW[@]}"; do
        [[ "$id" != ssh-overlay ]] || continue
        stow_catalog_has "$id" || continue
        options+=("$id"$'	'"${STOW_CATALOG_LABEL[$id]:-$id} — unstow links for this package")
    done
    (( ${#options[@]} > 0 )) || {
        ui_pager "Prune" "No catalogued Stow packages are available."
        return
    }

    selected="$(ui_choose_multi_preselected "Prune packages — Space: toggle; Enter: continue; Esc: cancel" \
        preselected options)" || return
    while IFS= read -r line; do
        [[ -n "$line" ]] || continue
        selected_ids+=("${line%%$'\t'*}")
    done <<< "$selected"
    (( ${#selected_ids[@]} > 0 )) || {
        ui_pager "Prune" "No packages selected."
        return
    }

    {
        printf 'PRUNE PLAN (unstow only; not covered by system-file rollback)\n\n'
        for package in "${selected_ids[@]}"; do
            printf '-- %s --\n' "$package"
            stow_package_status "$package" || true
            stow_command --simulate -v -D "$package" 2>&1 || true
            printf '\n'
        done
    } >"${SESSION_TMPDIR}/prune-plan.txt"
    ui_pager "Prune plan" "${SESSION_TMPDIR}/prune-plan.txt"
    ui_confirm "Permanently unstow: ${selected_ids[*]}?" "Unstow" "Cancel" || return
    ui_confirm "Second confirmation: remove Stow links for ${selected_ids[*]}?" "Unstow" "Cancel" || return
    session_run_job "Prune Stow packages" false stow_prune_packages "${selected_ids[@]}" || true
}

session_advanced() {
    while true; do
        ui_clear
        ui_header "ADVANCED AND LOGS" "Technical details and controlled recovery"
        if ! session_menu_choice "Esc: back" \
            "Run doctor (catalog, fold, Syncthing)" \
            "View resolved profile" \
            "View run history" \
            "View latest run log" \
            "Rollback system files from a previous run" \
            "Prune Stow packages (explicit unstow)" \
            "View technical plan" \
            "About configure-host" \
            "Back"; then
            return
        fi
        case "$SESSION_CHOICE" in
            "Run doctor (catalog, fold, Syncthing)")
                doctor_run "$DOTFILES" "$HOME" >"${SESSION_TMPDIR}/doctor.txt" 2>&1 || true
                ui_pager "Doctor" "${SESSION_TMPDIR}/doctor.txt"
                ;;
            "View resolved profile") ui_run_to_pager "Resolved profile" session_profile_report ;;
            "View run history") session_history_file "${SESSION_TMPDIR}/history.txt"; ui_pager "Run history" "${SESSION_TMPDIR}/history.txt" ;;
            "View latest run log") session_latest_run_log ;;
            "Rollback system files from a previous run") session_rollback ;;
            "Prune Stow packages (explicit unstow)") session_prune ;;
            "View technical plan") ui_run_to_pager "Technical plan" session_technical_plan ;;
            "About configure-host") ui_pager "About" "configure-host v${VERSION}
Shared desired-state workflow with guarded apply, verification, durable logs, and system-file rollback.
Stow uses simulate-then-restow; --adopt is refused. Rollback restores system files only." ;;
            "Back") return ;;
        esac
    done
}
