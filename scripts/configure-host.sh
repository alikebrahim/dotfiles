#!/usr/bin/env bash
set -euo pipefail

# configure-host.sh — host-aware desired-state configuration.
# Exit codes: 0=ok, 1=drift/absent, 2=blocked/invalid, 3=internal.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES="${DOTFILES:-$(cd "${SCRIPT_DIR}/.." && pwd)}"
PROGRAM="$(basename "$0")"
VERSION="3.1.0"

for library in common log profile stow ssh-overlay module-runner bootstrap tools ui-gum selection workflow runner rollback doctor session-ui; do
    # shellcheck disable=SC1090
    source "${SCRIPT_DIR}/lib/${library}.sh"
done

COMMAND=""
COMMAND_ARG=""
HOST_OVERRIDE=""
ALLOW_UNKNOWN_HOST=false
ASSUME_YES=false
VERBOSE=false
QUIET=false
SYSTEM_ROOT="${CONFIGURE_HOST_SYSTEM_ROOT:-/}"
STATE_ROOT="${CONFIGURE_HOST_STATE_ROOT:-${XDG_STATE_HOME:-$HOME/.local/state}/configure-host}"
THEME_OVERRIDE=""
NO_UI=false
NON_INTERACTIVE=false
SCOPE="all"
OUTPUT_FORMAT="text"
CLI_TOOLS=()
CLI_STOW=()
CLI_MODULES=()
EXCLUDE_SSH_OVERLAY=false

usage() {
    cat <<EOF
configure-host v${VERSION} — safe host configuration

Usage:
  ${PROGRAM} [command] [options]
  ${PROGRAM}                         Interactive dashboard in a TTY

Read-only commands:
  list                              List known profiles
  check                             Check prerequisites, safety, and selected state
  status                            Report selected component state
  plan                              Show concise proposed changes
  diff                              Show technical Stow/module details
  doctor                            Catalog, fold, Syncthing, and new-package health
  history                           List durable operation history

Mutating commands:
  apply                             Apply and verify the reviewed selection
  bootstrap                         Install configurator prerequisites
  rollback RUN_ID                   Restore backed-up system files from a run
  tools install                     Install selected/profile tools
  update tmux-plugins               Explicitly update tmux plugin checkouts
  prune                             Unstow explicitly listed packages only

Tool inspection:
  tools list                        List the complete tool catalog
  tools check                       Check selected/profile tools

Selection:
  --scope NAME                      all, stow, system, or user
  --tool ID                         Select a tool; repeatable
  --stow-package ID                 Select a registered dotfile package; repeatable
  --module ID                       Select a profile module; repeatable
  --no-ssh-overlay                  Exclude the profile SSH component

General options:
  --host HOST                       Resolve another host profile
  --allow-unknown-host              Permit reviewed common setup on an unknown host
  --yes                             Confirm a mutating noninteractive action
  --theme NAME                      orange-gas-plasma, amber-crt, green-phosphor, auto
  --no-ui                           Disable Gum rendering
  --non-interactive                 Refuse prompts; implies --no-ui
  --format text|tsv                 Status/history output format
  --verbose                         Include technical plan details
  --quiet                           Print only the final summary for mutations/plans
  --dry-run                         Alias for plan
  --version                         Print version
  -h, --help                        Show help

Safety:
  Read-only commands never mutate files, packages, services, or plugins.
  Every mutation uses the same profile guard, per-user lock, durable log,
  and result verification. System-file changes are backed up for rollback.
  Stow uses simulate-then-restow; --adopt is never supported.
  prune requires explicit --stow-package IDs (never profile defaults alone).
EOF
}

error() { log_error "$*"; }

detect_host() {
    if [[ -n "$HOST_OVERRIDE" ]]; then
        printf '%s\n' "$HOST_OVERRIDE"
    elif command -v hostnamectl >/dev/null 2>&1; then
        hostnamectl hostname 2>/dev/null || hostname
    else
        hostname
    fi
}

detect_os() {
    local release_file="${CONFIGURE_HOST_OS_RELEASE:-/etc/os-release}"
    if [[ -r "$release_file" ]]; then
        # shellcheck disable=SC1090
        . "$release_file"
        printf '%s|%s\n' "${ID:-unknown}" "${VERSION_ID:-unknown}"
    else
        printf 'unknown|unknown\n'
    fi
}

set_command() {
    [[ -z "$COMMAND" ]] || { error "only one command may be selected"; exit "$EXIT_BLOCKED"; }
    COMMAND="$1"
}

parse_args() {
    while (( $# > 0 )); do
        case "$1" in
            list|check|status|plan|apply|diff|bootstrap|history|doctor)
                set_command "$1"; shift ;;
            prune)
                set_command prune; shift ;;
            rollback)
                set_command rollback
                [[ -n "${2:-}" && "${2:-}" != -* ]] || { error "rollback requires a run ID"; exit "$EXIT_BLOCKED"; }
                COMMAND_ARG="$2"; shift 2 ;;
            tools)
                [[ "${2:-}" =~ ^(list|check|install)$ ]] || { error "tools requires: list, check, or install"; exit "$EXIT_BLOCKED"; }
                set_command "tools-${2}"; shift 2 ;;
            update)
                [[ "${2:-}" == tmux-plugins ]] || { error "update supports only: tmux-plugins"; exit "$EXIT_BLOCKED"; }
                set_command update-tmux-plugins; shift 2 ;;
            --host) [[ $# -ge 2 ]] || exit "$EXIT_BLOCKED"; HOST_OVERRIDE="$2"; shift 2 ;;
            --allow-unknown-host) ALLOW_UNKNOWN_HOST=true; shift ;;
            --yes) ASSUME_YES=true; shift ;;
            --theme) [[ $# -ge 2 ]] || exit "$EXIT_BLOCKED"; THEME_OVERRIDE="$2"; shift 2 ;;
            --no-ui) NO_UI=true; shift ;;
            --non-interactive) NON_INTERACTIVE=true; NO_UI=true; shift ;;
            --scope)
                [[ "${2:-}" =~ ^(all|stow|system|user)$ ]] || { error "invalid --scope"; exit "$EXIT_BLOCKED"; }
                SCOPE="$2"; shift 2 ;;
            --tool) [[ $# -ge 2 ]] || exit "$EXIT_BLOCKED"; CLI_TOOLS+=("$2"); shift 2 ;;
            --stow-package) [[ $# -ge 2 ]] || exit "$EXIT_BLOCKED"; CLI_STOW+=("$2"); shift 2 ;;
            --module) [[ $# -ge 2 ]] || exit "$EXIT_BLOCKED"; CLI_MODULES+=("$2"); shift 2 ;;
            --no-ssh-overlay) EXCLUDE_SSH_OVERLAY=true; shift ;;
            --format)
                [[ "${2:-}" =~ ^(text|tsv)$ ]] || { error "--format must be text or tsv"; exit "$EXIT_BLOCKED"; }
                OUTPUT_FORMAT="$2"; shift 2 ;;
            --verbose|-v) VERBOSE=true; shift ;;
            --quiet|-q) QUIET=true; shift ;;
            --dry-run) set_command plan; shift ;;
            --version) printf 'configure-host v%s\n' "$VERSION"; exit "$EXIT_OK" ;;
            --help|-h) usage; exit "$EXIT_OK" ;;
            *) error "unknown argument: $1"; usage >&2; exit "$EXIT_BLOCKED" ;;
        esac
    done
    COMMAND="${COMMAND:-menu}"
}

selection_filter_scope() {
    local item filtered=()
    (( ${#CLI_TOOLS[@]} == 0 )) || selection_set tool "${CLI_TOOLS[@]}"
    (( ${#CLI_STOW[@]} == 0 )) || selection_set stow "${CLI_STOW[@]}"
    (( ${#CLI_MODULES[@]} == 0 )) || selection_set module "${CLI_MODULES[@]}"
    if [[ "$EXCLUDE_SSH_OVERLAY" == true ]]; then
        _selection_remove CONFIG_SELECTED_STOW ssh-overlay
    fi

    case "$SCOPE" in
        stow) CONFIG_SELECTED_TOOLS=(); CONFIG_SELECTED_MODULES=() ;;
        system)
            CONFIG_SELECTED_TOOLS=(); CONFIG_SELECTED_STOW=(); filtered=()
            for item in "${CONFIG_SELECTED_MODULES[@]}"; do [[ "$item" == system:* ]] && filtered+=("$item"); done
            CONFIG_SELECTED_MODULES=("${filtered[@]}")
            ;;
        user)
            CONFIG_SELECTED_TOOLS=(); CONFIG_SELECTED_STOW=(); filtered=()
            for item in "${CONFIG_SELECTED_MODULES[@]}"; do [[ "$item" == user:* ]] && filtered+=("$item"); done
            CONFIG_SELECTED_MODULES=("${filtered[@]}")
            ;;
    esac
}

validate_selection() {
    local item
    for item in "${CONFIG_SELECTED_TOOLS[@]}"; do
        [[ -v TOOL_DESC[$item] ]] || { error "unknown tool: $item"; return "$EXIT_BLOCKED"; }
    done
    for item in "${CONFIG_SELECTED_STOW[@]}"; do
        [[ "$item" == ssh-overlay ]] || stow_catalog_has "$item" || {
            error "unregistered Stow package: $item"
            return "$EXIT_BLOCKED"
        }
    done
    for item in "${CONFIG_SELECTED_MODULES[@]}"; do
        _selection_contains "$item" "${CONFIG_AVAILABLE_MODULES[@]}" || {
            error "module '$item' is not enabled by profile '$PROFILE_NAME'"
            return "$EXIT_BLOCKED"
        }
    done
}

resolve_current_profile() {
    local os_data
    os_data="$(detect_os)"
    profile_init "$DOTFILES"
    profile_resolve "$(detect_host)" "$(id -un)" "${os_data%%|*}" "${os_data#*|}"
    stow_init "$DOTFILES" "$HOME"
    ssh_overlay_init "$DOTFILES" "$HOME" "${PROFILE_SSH_OVERLAY:-}"
    STOW_VERBOSE="$VERBOSE"
    module_runner_init "$DOTFILES" "$SYSTEM_ROOT"
    selection_init_from_profile "$DOTFILES"
    selection_filter_scope
    validate_selection
    runner_init "$STATE_ROOT" "$PROFILE_NAME"
    ui_init "$DOTFILES" "${THEME_OVERRIDE:-$PROFILE_UI_THEME}"
    UI_DISABLED="$NO_UI"
    log_set_verbose "$VERBOSE"
}

print_profile() {
    printf 'Profile: %s\nHost: %s\nUser: %s\nOS: %s %s\nTheme: %s\n' \
        "$PROFILE_NAME" "$PROFILE_HOST" "$PROFILE_USER" "$PROFILE_OS_ID" "$PROFILE_OS_VERSION" "$UI_THEME"
    printf 'Tool set: %s\nSSH overlay: %s\n' "${PROFILE_TOOL_SET:-none}" "${PROFILE_SSH_OVERLAY:-none}"
    printf 'Selected: %d tools, %d dotfiles, %d system/user components\n' \
        "${#CONFIG_SELECTED_TOOLS[@]}" "${#CONFIG_SELECTED_STOW[@]}" "${#CONFIG_SELECTED_MODULES[@]}"
}

format_table() {
    if [[ "$OUTPUT_FORMAT" == tsv ]]; then cat; elif command -v column >/dev/null 2>&1; then column -t -s $'\t'; else cat; fi
}

run_status() {
    print_profile
    printf '\n'
    {
        printf 'Kind\tID\tStatus\tPrivilege\tRisk\tLabel\tDescription\n'
        workflow_collect_records
    } | format_table
}

run_plan() {
    local plan
    workflow_validate_selected_plan
    plan="$(workflow_plan_selected)"
    if "$QUIET"; then
        grep -E '^(Current:|Requires root:)' <<< "$plan"
    else
        printf '%s\n' "$plan"
    fi
    if [[ "$VERBOSE" == true ]]; then
        run_diff
    fi
}

run_diff() {
    local package module
    printf 'TECHNICAL DETAILS (read-only)\n'
    for package in "${CONFIG_SELECTED_STOW[@]}"; do
        printf '\n-- Stow: %s --\n' "$package"
        if [[ "$package" == ssh-overlay ]]; then
            SSH_OVERLAY_VERBOSE=true ssh_overlay_plan || true
        else
            STOW_VERBOSE=true stow_simulate_package "$package" || true
            stow_package_conflict_report "$package" || true
        fi
    done
    for module in "${CONFIG_SELECTED_MODULES[@]}"; do
        printf '\n-- Module: %s --\n' "$module"
        module_run "$module" plan || true
    done
}

run_check() {
    local package
    printf 'CONFIGURE-HOST CHECK\n'
    print_profile
    printf '\nPREREQUISITES\n'
    bootstrap_status
    printf '\nSYNCTHING / FOLD SAFETY\n'
    doctor_syncthing_notes "$DOTFILES"
    doctor_fold_status "$HOME"
    if (( ${#CONFIG_SELECTED_STOW[@]} > 0 )); then
        printf '\nSTOW SAFETY\n'
        stow_safety_plan
        for package in "${CONFIG_SELECTED_STOW[@]}"; do
            if [[ "$package" == ssh-overlay ]]; then
                ssh_overlay_plan || true
            else
                stow_simulate_package "$package" || true
                stow_package_conflict_report "$package" || true
            fi
        done
    fi
    printf '\n'
    doctor_tmux_plugins_status
    printf '\nSELECTED STATE\n'
    run_status
}

run_doctor() {
    doctor_run "$DOTFILES" "$HOME"
}

confirm_mutation() {
    local prompt="$1"
    if [[ "$ASSUME_YES" == true ]]; then return 0; fi
    if [[ "$NON_INTERACTIVE" == true || ! -t 0 ]]; then
        error "non-interactive mutation requires --yes"
        return "$EXIT_BLOCKED"
    fi
    ui_confirm "$prompt" "Continue" "Cancel"
}

confirm_high_risk_modules() {
    local lines
    lines="$(workflow_high_risk_pending_lines)"
    [[ -n "$lines" ]] || return 0
    printf 'HIGH-RISK MODULES PENDING:\n%s\n' "$lines"
    confirm_mutation "Proceed with high-risk module changes (services/packages may start immediately)?"
}

workflow_requires_root_changes() {
    local kind id state privilege risk label description
    while IFS=$'\t' read -r kind id state privilege risk label description; do
        [[ "$state" != "$STATUS_CURRENT" && "$state" != "$STATUS_BLOCKED" && "$privilege" == root ]] && return 0
    done < <(workflow_collect_records)
    return 1
}

workflow_has_blocked() {
    grep -q $'\tBLOCKED\t' < <(workflow_collect_records)
}

worker_apply_verify() {
    local apply_rc=0 verify_rc=0
    printf '=== APPLY ===\n'
    workflow_apply_selected || apply_rc=$?
    printf '\n=== VERIFY ===\n'
    workflow_verify_selected || verify_rc=$?
    (( apply_rc != 0 )) && return "$apply_rc"
    return "$verify_rc"
}

print_run_result() {
    local action="$1" rc="$2"
    if [[ "$QUIET" != true && -f "$RUNNER_LAST_LOG" ]]; then cat "$RUNNER_LAST_LOG"; fi
    printf '%s: exit %s; log: %s\n' "$action" "$rc" "$RUNNER_LAST_LOG"
}

run_apply() {
    local requires_root=false rc=0
    workflow_require_applyable_profile
    workflow_has_blocked && { run_plan; error "selection contains BLOCKED components"; return "$EXIT_BLOCKED"; }
    run_plan
    confirm_mutation "Apply and verify the reviewed selection for '$PROFILE_NAME'?" || { printf 'Apply cancelled.\n'; return 0; }
    confirm_high_risk_modules || { printf 'Apply cancelled (high-risk modules).\n'; return 0; }
    workflow_requires_root_changes && requires_root=true
    runner_run apply-and-verify "$requires_root" worker_apply_verify || rc=$?
    print_run_result apply "$rc"
    return "$rc"
}

run_bootstrap() {
    local missing=() rc=0
    mapfile -t missing < <(bootstrap_missing_packages)
    bootstrap_plan_for "$PROFILE_OS_ID" "${missing[@]}"
    (( ${#missing[@]} > 0 )) || return 0
    confirm_mutation "Install configurator prerequisites: ${missing[*]}?" || { printf 'Bootstrap cancelled.\n'; return 0; }
    runner_run bootstrap true bootstrap_apply_for "$PROFILE_OS_ID" "${missing[@]}" || rc=$?
    print_run_result bootstrap "$rc"
    return "$rc"
}

run_tools_list() { tools_check_all "$PROFILE_OS_ID" | format_table; }
run_tools_check() { tools_check_profile "${CONFIG_SELECTED_TOOLS[*]}" | format_table; }

run_tools_install() {
    local missing rc=0
    workflow_require_applyable_profile
    missing="$(tools_missing_from "${CONFIG_SELECTED_TOOLS[*]}")"
    [[ -n "$missing" ]] || { printf '%s selected tools are installed\n' "$STATUS_CURRENT"; return 0; }
    printf 'Missing tools:\n%s\n' "$missing"
    confirm_mutation "Install the selected missing tools?" || { printf 'Tool installation cancelled.\n'; return 0; }
    runner_run tools-install true tools_install "$PROFILE_OS_ID" "$missing" || rc=$?
    print_run_result tools-install "$rc"
    return "$rc"
}

run_update_plugins() {
    local rc=0
    workflow_require_applyable_profile
    confirm_mutation "Fast-forward managed tmux plugin checkouts?" || { printf 'Update cancelled.\n'; return 0; }
    runner_run update-tmux-plugins false bash "$DOTFILES/scripts/install-tmux-plugins.sh" --update || rc=$?
    print_run_result update-tmux-plugins "$rc"
    return "$rc"
}

run_history() {
    if [[ "$OUTPUT_FORMAT" == tsv ]]; then
        printf 'Run ID\tStarted\tProfile\tAction\tExit\n'
        runner_list_runs
    else
        { printf 'Run ID\tStarted (UTC)\tProfile\tAction\tExit\n'; runner_list_runs; } | format_table
    fi
}

run_rollback() {
    local run_id="$COMMAND_ARG" run_dir manifest rc=0
    [[ "$run_id" != */* && "$run_id" != *..* ]] || { error "unsafe run ID"; return "$EXIT_BLOCKED"; }
    run_dir="$STATE_ROOT/runs/$run_id"
    manifest="$run_dir/rollback.tsv"
    rollback_manifest_has_files "$manifest" || { error "run has no system-file rollback entries: $run_id"; return "$EXIT_BLOCKED"; }
    rollback_describe_manifest "$manifest"
    confirm_mutation "Restore the listed system files from '$run_id'?" || { printf 'Rollback cancelled.\n'; return 0; }
    runner_run "rollback-$run_id" true rollback_apply_manifest "$manifest" "$SYSTEM_ROOT" || rc=$?
    print_run_result rollback "$rc"
    return "$rc"
}

# Prune only packages explicitly requested via --stow-package (never profile defaults alone).
run_prune() {
    local package rc=0 packages=()
    workflow_require_applyable_profile

    if (( ${#CLI_STOW[@]} == 0 )); then
        error "prune requires explicit --stow-package ID (repeatable); refuses profile defaults"
        return "$EXIT_BLOCKED"
    fi

    for package in "${CLI_STOW[@]}"; do
        [[ "$package" != ssh-overlay ]] || {
            error "prune does not support ssh-overlay; clear overlay selection separately"
            return "$EXIT_BLOCKED"
        }
        stow_catalog_has "$package" || {
            error "unregistered Stow package: $package"
            return "$EXIT_BLOCKED"
        }
        packages+=("$package")
    done

    printf 'PRUNE PLAN (unstow only; not reversible by rollback)\n'
    for package in "${packages[@]}"; do
        stow_package_status "$package" || true
        STOW_VERBOSE=true stow_command --simulate -v -D "$package" 2>&1 || true
    done

    confirm_mutation "Permanently unstow packages: ${packages[*]}?" || { printf 'Prune cancelled.\n'; return 0; }
    # Second confirmation — destructive and not covered by system-file rollback.
    confirm_mutation "Second confirmation: unstow ${packages[*]} from $HOME?" || {
        printf 'Prune cancelled.\n'
        return 0
    }

    runner_run prune-stow false stow_prune_packages "${packages[@]}" || rc=$?
    print_run_result prune "$rc"
    return "$rc"
}

main() {
    parse_args "$@"
    if [[ "$COMMAND" == list ]]; then
        profile_init "$DOTFILES"
        profile_known_hosts
        return
    fi

    resolve_current_profile
    case "$COMMAND" in
        menu) session_run ;;
        check) run_check ;;
        status) run_status ;;
        plan) run_plan ;;
        apply) run_apply ;;
        diff) run_diff ;;
        doctor) run_doctor ;;
        bootstrap) run_bootstrap ;;
        tools-list) run_tools_list ;;
        tools-check) run_tools_check ;;
        tools-install) run_tools_install ;;
        update-tmux-plugins) run_update_plugins ;;
        history) run_history ;;
        rollback) run_rollback ;;
        prune) run_prune ;;
        *) error "unsupported command: $COMMAND"; return "$EXIT_INTERNAL" ;;
    esac
}

main "$@"
