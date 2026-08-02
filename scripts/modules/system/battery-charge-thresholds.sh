#!/usr/bin/env bash

BATTERY_THRESHOLDS_UNIT="battery-charge-thresholds.service"
BATTERY_THRESHOLDS_SOURCE="${MODULE_ROOT}/scripts/system/battery-charge-thresholds/${BATTERY_THRESHOLDS_UNIT}"
BATTERY_THRESHOLDS_UNIT_TARGET="/etc/systemd/system/${BATTERY_THRESHOLDS_UNIT}"
BATTERY_THRESHOLDS_START_TARGET="/sys/class/power_supply/BAT0/charge_control_start_threshold"
BATTERY_THRESHOLDS_END_TARGET="/sys/class/power_supply/BAT0/charge_control_end_threshold"
BATTERY_THRESHOLDS_START=50
BATTERY_THRESHOLDS_END=60

module_battery_charge_thresholds_metadata() {
    case "$1" in
        label) printf 'Serval WS battery charge thresholds\n' ;;
        description) printf 'Install and enable the BAT0 50-60 percent charge-threshold boot service.\n' ;;
        privilege) printf 'root\n' ;;
        risk) printf 'high\n' ;;
        impact) printf 'Enables a boot-time system service and immediately changes live BAT0 charging behavior to 50-60 percent.\n' ;;
    esac
}

battery_charge_thresholds_sysfs_path() {
    module_target_path "$1"
}

battery_charge_thresholds_state() {
    local file_state file_rc=0 start_path end_path start end

    file_state="$(module_file_status "$BATTERY_THRESHOLDS_SOURCE" "$BATTERY_THRESHOLDS_UNIT_TARGET")" || file_rc=$?
    if [[ "$file_rc" -eq "$EXIT_BLOCKED" ]]; then
        printf '%s service unit: %s\n' "$STATUS_BLOCKED" "$file_state"
        return "$EXIT_BLOCKED"
    fi
    if [[ "$file_rc" -eq "$EXIT_DRIFT" ]]; then
        printf '%s service unit: %s\n' "$STATUS_DRIFT" "$file_state"
        return "$EXIT_DRIFT"
    fi

    if ! command -v systemctl >/dev/null 2>&1; then
        printf '%s systemctl is required to manage %s\n' "$STATUS_BLOCKED" "$BATTERY_THRESHOLDS_UNIT"
        return "$EXIT_BLOCKED"
    fi
    if ! systemctl is-enabled --quiet "$BATTERY_THRESHOLDS_UNIT" 2>/dev/null; then
        printf '%s %s is not enabled\n' "$STATUS_DRIFT" "$BATTERY_THRESHOLDS_UNIT"
        return "$EXIT_DRIFT"
    fi

    start_path="$(battery_charge_thresholds_sysfs_path "$BATTERY_THRESHOLDS_START_TARGET")"
    end_path="$(battery_charge_thresholds_sysfs_path "$BATTERY_THRESHOLDS_END_TARGET")"
    if [[ ! -r "$start_path" || ! -r "$end_path" ]]; then
        printf '%s BAT0 charge-threshold controls are unavailable\n' "$STATUS_BLOCKED"
        return "$EXIT_BLOCKED"
    fi

    start="$(<"$start_path")"
    end="$(<"$end_path")"
    if [[ "$start" != "$BATTERY_THRESHOLDS_START" || "$end" != "$BATTERY_THRESHOLDS_END" ]]; then
        printf '%s BAT0 thresholds are %s-%s, expected %s-%s\n' \
            "$STATUS_DRIFT" "$start" "$end" \
            "$BATTERY_THRESHOLDS_START" "$BATTERY_THRESHOLDS_END"
        return "$EXIT_DRIFT"
    fi

    printf '%s %s enabled; BAT0 thresholds are %s-%s\n' \
        "$STATUS_CURRENT" "$BATTERY_THRESHOLDS_UNIT" "$start" "$end"
}

battery_charge_thresholds_systemctl() {
    if [[ "$MODULE_SYSTEM_ROOT" == / ]]; then
        run_as_root systemctl "$@"
    else
        systemctl "$@"
    fi
}

module_battery_charge_thresholds() {
    local action="$1" state rc=0

    state="$(battery_charge_thresholds_state)" || rc=$?
    case "$action" in
        describe)
            printf 'system:battery-charge-thresholds: %s -> %s; BAT0 %s-%s\n' \
                "$BATTERY_THRESHOLDS_SOURCE" "$BATTERY_THRESHOLDS_UNIT_TARGET" \
                "$BATTERY_THRESHOLDS_START" "$BATTERY_THRESHOLDS_END"
            ;;
        status|verify)
            printf '%s [system:battery-charge-thresholds]\n' "$state"
            [[ "$rc" -ne "$EXIT_BLOCKED" ]]
            ;;
        plan)
            printf '%s [system:battery-charge-thresholds]\n' "$state"
            if [[ "$rc" -eq "$EXIT_DRIFT" ]]; then
                module_manage_file plan \
                    system:battery-charge-thresholds \
                    "$BATTERY_THRESHOLDS_SOURCE" \
                    "$BATTERY_THRESHOLDS_UNIT_TARGET" \
                    0644 || true
                printf 'PLAN systemctl daemon-reload; systemctl enable --now %s\n' "$BATTERY_THRESHOLDS_UNIT"
            fi
            [[ "$rc" -ne "$EXIT_BLOCKED" ]]
            ;;
        apply)
            if [[ "$rc" -eq "$EXIT_BLOCKED" ]]; then
                printf '%s [system:battery-charge-thresholds]\n' "$state" >&2
                return "$EXIT_BLOCKED"
            fi
            module_manage_file apply \
                system:battery-charge-thresholds \
                "$BATTERY_THRESHOLDS_SOURCE" \
                "$BATTERY_THRESHOLDS_UNIT_TARGET" \
                0644
            module_record_service_state system "$BATTERY_THRESHOLDS_UNIT"
            if ! battery_charge_thresholds_systemctl daemon-reload; then
                printf '%s failed to reload systemd units\n' "$STATUS_BLOCKED" >&2
                return "$EXIT_BLOCKED"
            fi
            if ! battery_charge_thresholds_systemctl enable --now "$BATTERY_THRESHOLDS_UNIT"; then
                printf '%s failed to enable and start %s\n' \
                    "$STATUS_BLOCKED" "$BATTERY_THRESHOLDS_UNIT" >&2
                return "$EXIT_BLOCKED"
            fi
            module_battery_charge_thresholds verify
            ;;
        *)
            printf 'unknown module action: %s\n' "$action" >&2
            return "$EXIT_BLOCKED"
            ;;
    esac
}
