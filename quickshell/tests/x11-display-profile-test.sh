#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BACKEND="$ROOT/awesome_wm_scripts/.config/scripts/x11-display-profile.sh"
TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

FAKE_BIN="$TMPDIR/bin"
STATE_FILE="$TMPDIR/state"
COMMAND_LOG="$TMPDIR/commands"
mkdir -p "$FAKE_BIN" "$TMPDIR/home"
: >"$COMMAND_LOG"

cat >"$FAKE_BIN/xrandr" <<'FAKE_XRANDR'
#!/usr/bin/env bash
set -euo pipefail

render_state() {
    case "${XRANDR_SCENARIO:-ready}" in
        missing-external)
            cat <<'EOF'
eDP-1-1 connected primary 1920x1080+0+0
   1920x1080     60.00*
HDMI-0 disconnected
EOF
            return
            ;;
        missing-mode)
            cat <<'EOF'
eDP-1-1 connected 1920x1080+0+0
   1920x1080     60.00*
HDMI-0 connected primary 2560x1440+1920+0
   2560x1440     60.00*
EOF
            return
            ;;
    esac

    case "$(cat "$XRANDR_STATE_FILE" 2>/dev/null || printf 'dual')" in
        dual)
            cat <<'EOF'
eDP-1-1 connected 1920x1080+0+0
   1920x1080     60.00*
HDMI-0 connected primary 1920x1080+1920+0
   1920x1080     60.00*
EOF
            ;;
        external)
            cat <<'EOF'
eDP-1-1 connected
   1920x1080     60.00
HDMI-0 connected primary 1920x1080+0+0
   1920x1080     60.00*
EOF
            ;;
        laptop)
            cat <<'EOF'
eDP-1-1 connected primary 1920x1080+0+0
   1920x1080     60.00*
HDMI-0 connected
   1920x1080     60.00
EOF
            ;;
        mirror)
            cat <<'EOF'
eDP-1-1 connected 1920x1080+0+0
   1920x1080     60.00*
HDMI-0 connected primary 1920x1080+0+0
   1920x1080     60.00*
EOF
            ;;
    esac
}

if [[ "${1:-}" == "--query" ]]; then
    render_state
    exit 0
fi

printf '%q ' "$@" >>"$XRANDR_COMMAND_LOG"
printf '\n' >>"$XRANDR_COMMAND_LOG"

if [[ "${XRANDR_NO_CONVERGE:-0}" == "1" ]]; then
    exit 0
fi

args=" $* "
if [[ "$args" == *" --output eDP-1-1 --mode 1920x1080 --pos 0x0 --output HDMI-0 --mode 1920x1080 --pos 1920x0 --primary "* ]]; then
    printf 'dual\n' >"$XRANDR_STATE_FILE"
elif [[ "$args" == *" --output HDMI-0 --mode 1920x1080 --pos 0x0 --primary --output eDP-1-1 --off "* ]]; then
    printf 'external\n' >"$XRANDR_STATE_FILE"
elif [[ "$args" == *" --output eDP-1-1 --mode 1920x1080 --pos 0x0 --primary --output HDMI-0 --off "* ]]; then
    printf 'laptop\n' >"$XRANDR_STATE_FILE"
elif [[ "$args" == *" --output HDMI-0 --mode 1920x1080 --pos 0x0 --primary --output eDP-1-1 --mode 1920x1080 --same-as HDMI-0 "* ]]; then
    printf 'mirror\n' >"$XRANDR_STATE_FILE"
else
    printf 'unexpected xrandr argv: %s\n' "$*" >&2
    exit 9
fi
FAKE_XRANDR
chmod +x "$FAKE_BIN/xrandr"

export PATH="$FAKE_BIN:/usr/bin:/bin"
export HOME="$TMPDIR/home"
export XRANDR_STATE_FILE="$STATE_FILE"
export XRANDR_COMMAND_LOG="$COMMAND_LOG"

pass_count=0
fail_count=0

pass() {
    printf 'ok - %s\n' "$1"
    pass_count=$((pass_count + 1))
}

fail() {
    printf 'not ok - %s\n' "$1" >&2
    fail_count=$((fail_count + 1))
}

expect_success() {
    local profile="$1"
    local output
    printf 'dual\n' >"$STATE_FILE"
    : >"$COMMAND_LOG"
    if output="$($BACKEND --apply "$profile" 2>&1)" \
        && [[ "$output" == "applied:$profile" ]] \
        && [[ "$(cat "$STATE_FILE")" == "$profile" ]] \
        && [[ -s "$COMMAND_LOG" ]]; then
        pass "$profile profile applies and verifies"
    else
        fail "$profile profile applies and verifies: $output"
    fi
}

expect_failure_without_mutation() {
    local label="$1"
    local expected_rc="$2"
    shift 2
    local output rc
    : >"$COMMAND_LOG"
    set +e
    output="$("$@" 2>&1)"
    rc=$?
    set -e
    if [[ "$rc" -eq "$expected_rc" && ! -s "$COMMAND_LOG" ]]; then
        pass "$label"
    else
        fail "$label: rc=$rc output=$output"
    fi
}

for profile in dual external laptop mirror; do
    expect_success "$profile"
done

expect_failure_without_mutation "missing arguments are rejected before xrandr" 2 \
    "$BACKEND"
expect_failure_without_mutation "unknown profile is rejected before xrandr" 2 \
    "$BACKEND" --apply arbitrary

export XRANDR_SCENARIO=missing-external
expect_failure_without_mutation "missing required output blocks mutation" 1 \
    "$BACKEND" --apply dual
export XRANDR_SCENARIO=missing-mode
expect_failure_without_mutation "missing required mode blocks mutation" 1 \
    "$BACKEND" --apply dual
unset XRANDR_SCENARIO

printf 'dual\n' >"$STATE_FILE"
: >"$COMMAND_LOG"
export XRANDR_NO_CONVERGE=1
set +e
verification_output="$($BACKEND --apply external 2>&1)"
verification_rc=$?
set -e
unset XRANDR_NO_CONVERGE
if [[ "$verification_rc" -eq 1 \
    && "$verification_output" == *"did not reach its expected RandR geometry"* \
    && -s "$COMMAND_LOG" ]]; then
    pass "post-apply geometry mismatch is reported"
else
    fail "post-apply geometry mismatch is reported: rc=$verification_rc output=$verification_output"
fi

printf '%d passed, %d failed\n' "$pass_count" "$fail_count"
[[ "$fail_count" -eq 0 ]]
