#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT/tests/deploy/testlib.sh"
source "$ROOT/scripts/lib/module-runner.sh"

TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT
SYSTEM_ROOT="$TMPDIR/system-root"
CALLS="$TMPDIR/calls"
mkdir -p "$TMPDIR/bin" \
    "$SYSTEM_ROOT/sys/class/power_supply/BAT0" \
    "$SYSTEM_ROOT/etc/systemd/system"
printf '%s\n' 90 > "$SYSTEM_ROOT/sys/class/power_supply/BAT0/charge_control_start_threshold"
printf '%s\n' 100 > "$SYSTEM_ROOT/sys/class/power_supply/BAT0/charge_control_end_threshold"

cat > "$TMPDIR/bin/systemctl" <<'MOCK'
#!/usr/bin/env bash
case "$1" in
    is-enabled)
        [[ -f "$SYSTEM_ROOT/state/enabled" ]]
        ;;
    daemon-reload)
        printf 'systemctl %s\n' "$*" >> "$CALLS"
        ;;
    enable)
        if [[ "${FAIL_ENABLE:-false}" == true ]]; then
            printf 'simulated enable failure\n' >&2
            exit 1
        fi
        mkdir -p "$SYSTEM_ROOT/state"
        touch "$SYSTEM_ROOT/state/enabled"
        printf '%s\n' 50 > "$SYSTEM_ROOT/sys/class/power_supply/BAT0/charge_control_start_threshold"
        printf '%s\n' 60 > "$SYSTEM_ROOT/sys/class/power_supply/BAT0/charge_control_end_threshold"
        printf 'systemctl %s\n' "$*" >> "$CALLS"
        ;;
    *)
        printf 'unexpected systemctl %s\n' "$*" >&2
        exit 1
        ;;
esac
MOCK
chmod +x "$TMPDIR/bin/systemctl"

export SYSTEM_ROOT CALLS
PATH="$TMPDIR/bin:$PATH"
module_runner_init "$ROOT" "$SYSTEM_ROOT"

plan_before="$(module_run system:battery-charge-thresholds plan)"
assert_text_contains "battery threshold plan reports absent service" "ABSENT" "$plan_before"
assert_text_contains "battery threshold plan declares enable action" "enable --now battery-charge-thresholds.service" "$plan_before"

unit_source="$(<"$ROOT/scripts/system/battery-charge-thresholds/battery-charge-thresholds.service")"
assert_text_not_contains "battery threshold unit has no unescaped systemd specifier" "%" "$unit_source"

module_run system:battery-charge-thresholds apply >/dev/null
assert_file_exists "battery threshold unit is installed in temporary root" \
    "$SYSTEM_ROOT/etc/systemd/system/battery-charge-thresholds.service"
assert_eq "battery threshold start is applied" "50" \
    "$(<"$SYSTEM_ROOT/sys/class/power_supply/BAT0/charge_control_start_threshold")"
assert_eq "battery threshold end is applied" "60" \
    "$(<"$SYSTEM_ROOT/sys/class/power_supply/BAT0/charge_control_end_threshold")"

calls="$(<"$CALLS")"
assert_text_contains "battery threshold unit reload was requested" "systemctl daemon-reload" "$calls"
assert_text_contains "battery threshold unit enable was requested" \
    "systemctl enable --now battery-charge-thresholds.service" "$calls"

status_after="$(module_run system:battery-charge-thresholds status)"
assert_text_contains "battery threshold module becomes current" "CURRENT" "$status_after"
assert_text_contains "battery threshold status reports applied range" "50-60" "$status_after"

printf '%s\n' 90 > "$SYSTEM_ROOT/sys/class/power_supply/BAT0/charge_control_start_threshold"
printf '%s\n' 100 > "$SYSTEM_ROOT/sys/class/power_supply/BAT0/charge_control_end_threshold"
FAIL_ENABLE=true
export FAIL_ENABLE
set +e
module_run system:battery-charge-thresholds apply >/dev/null 2>&1
failed_apply_rc=$?
set -e
unset FAIL_ENABLE
assert_eq "battery threshold apply propagates a service-enable failure" "$EXIT_BLOCKED" "$failed_apply_rc"

finish_tests
