#!/usr/bin/env bash
set -uo pipefail

readonly TAG="machine-synoptic-lock"
readonly QUICKSHELL_CONFIG="${HOME:?HOME is not set}/.config/quickshell"
readonly IPC_TARGET="machineSynoptic"
readonly READY_TIMEOUT_SECONDS=5
readonly COMMAND_TIMEOUT_SECONDS=2
readonly COMMAND_KILL_AFTER_SECONDS=0.5
readonly READY_INTERVAL=0.1
readonly MONITOR_INTERVAL=0.5
readonly MONITOR_FAILURE_LIMIT=4
readonly PROCESS_STOP_ATTEMPTS=20
readonly PROCESS_STOP_INTERVAL=0.05
readonly I3LOCK_COLOR="1e1e2e"

sleep_lock_fd="${XSS_SLEEP_LOCK_FD:-}"
lock_token=""
lock_window_tag=""
synoptic_open=false
xtrlock_pid=""
xtrlock_group=""
xtrlock_locker_pid=""
xtrlock_state_file=""
xtrlock_ready_file=""
i3lock_pid=""
xtrlock_status=125
runtime_dir="${XDG_RUNTIME_DIR:-/run/user/$UID}"
recovery_file="$runtime_dir/machine-synoptic-lock.recovery"

close_sleep_fd_copy() {
    [[ -z "$sleep_lock_fd" ]] && return 0
    [[ "$sleep_lock_fd" =~ ^[0-9]+$ ]] || return 1
    [[ -e "/proc/$BASHPID/fd/$sleep_lock_fd" ]] || return 1

    local descriptor="$sleep_lock_fd"
    exec {descriptor}>&-
    [[ ! -e "/proc/$BASHPID/fd/$sleep_lock_fd" ]]
}

run_without_sleep_fd() (
    close_sleep_fd_copy || exit 125
    unset XSS_SLEEP_LOCK_FD
    exec "$@"
)

log_message() {
    local message="$*"
    printf '%s: %s\n' "$TAG" "$message" >&2
    if command -v logger >/dev/null 2>&1; then
        run_without_sleep_fd timeout --foreground --signal=TERM \
            --kill-after="${COMMAND_KILL_AFTER_SECONDS}s" \
            "${COMMAND_TIMEOUT_SECONDS}s" logger -t "$TAG" -- "$message" \
            >/dev/null 2>&1 || true
    fi
}

release_sleep_lock() {
    if ! close_sleep_fd_copy; then
        log_message "critical: could not close the suspend-delay descriptor"
        return 1
    fi
    sleep_lock_fd=""
    unset XSS_SLEEP_LOCK_FD
    return 0
}

ipc_call() {
    run_without_sleep_fd timeout --foreground --signal=TERM \
        --kill-after="${COMMAND_KILL_AFTER_SECONDS}s" \
        "${COMMAND_TIMEOUT_SECONDS}s" quickshell --path "$QUICKSHELL_CONFIG" \
        ipc call "$IPC_TARGET" "$@"
}

ipc_call_retry() {
    local deadline=$((SECONDS + READY_TIMEOUT_SECONDS))
    local response status
    while ((SECONDS <= deadline)); do
        response="$(ipc_call "$@" 2>/dev/null)"
        status=$?
        if [[ $status -eq 0 ]]; then
            printf '%s\n' "$response"
            return 0
        fi
        sleep "$READY_INTERVAL"
    done
    return 1
}

set_synoptic_state() {
    [[ "$synoptic_open" == true && -n "$lock_token" ]] || return 0
    local response
    response="$(ipc_call setLockState "$lock_token" "$1" 2>/dev/null)" || return 1
    [[ "$response" == "updated" ]]
}

persist_synoptic_recovery() {
    local temporary="$recovery_file.${BASHPID}.tmp"
    (
        umask 077
        printf '%s %s\n' "$lock_token" "$lock_window_tag" > "$temporary"
    ) || return 1
    run_without_sleep_fd mv -f -- "$temporary" "$recovery_file"
}

clear_synoptic_tracking() {
    if [[ -n "$recovery_file" ]]; then
        run_without_sleep_fd rm -f -- "$recovery_file" >/dev/null 2>&1 || true
    fi
    synoptic_open=false
    lock_token=""
    lock_window_tag=""
}

synoptic_expected_count() {
    local status
    status="$(ipc_call status 2>/dev/null)" || return 1
    printf '%s' "$status" | run_without_sleep_fd timeout --foreground --signal=KILL \
        "${COMMAND_TIMEOUT_SECONDS}s" python3 -c '
import json
import sys

try:
    state = json.load(sys.stdin)
except Exception:
    raise SystemExit(1)

roles = state.get("roles")
expected = state.get("expectedSurfaceCount")
ready = (
    state.get("open") is True
    and state.get("lockMode") is True
    and state.get("mode") == "lock"
    and state.get("lockWindowTag") == sys.argv[1]
    and isinstance(roles, list)
    and isinstance(expected, int)
    and expected > 0
    and expected == len(roles)
)
if not ready:
    raise SystemExit(1)
print(expected)
' "$lock_window_tag"
}

mapped_synoptic_count() {
    if [[ -z "$lock_window_tag" ]]; then
        printf '0\n'
        return 0
    fi

    local tree
    tree="$(run_without_sleep_fd timeout --foreground --signal=KILL \
        "${COMMAND_TIMEOUT_SECONDS}s" xwininfo -root -tree 2>/dev/null)" || return 1
    printf '%s' "$tree" | run_without_sleep_fd timeout --foreground --signal=KILL \
        "${COMMAND_TIMEOUT_SECONDS}s" python3 -c '
import re
import subprocess
import sys

window_tree = sys.stdin.read()
window_tag = sys.argv[1]
window_ids = re.findall(
    r"^\s*(0x[0-9a-f]+)\s+\"quickshell-machine-synoptic-(?:primary|auxiliary)-"
        + re.escape(window_tag) + r"\"",
    window_tree,
    re.IGNORECASE | re.MULTILINE,
)
visible = 0
for window_id in dict.fromkeys(window_ids):
    try:
        result = subprocess.run(
            ["xwininfo", "-id", window_id],
            capture_output=True,
            check=False,
            text=True,
            timeout=0.5,
        )
    except subprocess.TimeoutExpired:
        raise SystemExit(1)
    if result.returncode == 0 and "Map State: IsViewable" in result.stdout:
        visible += 1
print(visible)
' "$lock_window_tag"
}

synoptic_ready_once() {
    local expected mapped
    expected="$(synoptic_expected_count 2>/dev/null)" || expected=0
    mapped="$(mapped_synoptic_count 2>/dev/null)" || mapped=-1
    [[ "$expected" =~ ^[1-9][0-9]*$ \
        && "$mapped" =~ ^[0-9]+$ \
        && "$mapped" -eq "$expected" ]]
}

wait_for_synoptic() {
    local deadline=$((SECONDS + READY_TIMEOUT_SECONDS))
    while ((SECONDS <= deadline)); do
        synoptic_ready_once && return 0
        sleep "$READY_INTERVAL"
    done
    return 1
}

synoptic_tracking_inactive() {
    local status
    status="$(ipc_call status 2>/dev/null)" || return 1
    printf '%s' "$status" | run_without_sleep_fd timeout --foreground --signal=KILL \
        "${COMMAND_TIMEOUT_SECONDS}s" python3 -c '
import json
import sys

try:
    state = json.load(sys.stdin)
except Exception:
    raise SystemExit(1)

same_lock = (
    state.get("open") is True
    and state.get("lockMode") is True
    and state.get("mode") == "lock"
    and state.get("lockWindowTag") == sys.argv[1]
)
raise SystemExit(1 if same_lock else 0)
' "$lock_window_tag"
}

close_synoptic_once() {
    if [[ "$synoptic_open" != true || -z "$lock_token" ]]; then
        return 0
    fi

    local response
    response="$(ipc_call closeLock "$lock_token" 2>/dev/null)" || response=""
    if [[ "$response" == "closed" ]]; then
        clear_synoptic_tracking
        return 0
    fi

    if synoptic_tracking_inactive; then
        clear_synoptic_tracking
        return 0
    fi
    return 1
}

close_synoptic() {
    local deadline=$((SECONDS + READY_TIMEOUT_SECONDS))
    while ((SECONDS <= deadline)); do
        close_synoptic_once && return 0
        sleep "$READY_INTERVAL"
    done
    return 1
}

close_synoptic_after_authentication() {
    if close_synoptic; then
        return 0
    fi

    log_message "authenticated locker exited, but Synoptic remains visible; retaining recovery state"
    while ! close_synoptic_once; do
        sleep 1
    done
    return 0
}

recover_previous_synoptic() {
    [[ -r "$recovery_file" ]] || return 0

    local recovered_token recovered_tag extra
    recovered_token=""
    recovered_tag=""
    extra=""
    IFS=' ' read -r recovered_token recovered_tag extra < "$recovery_file" || true
    if [[ ! "$recovered_token" =~ ^[0-9a-fA-F-]{16,64}$ \
        || ! "$recovered_tag" =~ ^[0-9a-fA-F-]{16,64}$ \
        || -n "$extra" ]]; then
        log_message "discarding malformed Synoptic recovery state"
        run_without_sleep_fd rm -f -- "$recovery_file" >/dev/null 2>&1 || true
        return 0
    fi

    lock_token="$recovered_token"
    lock_window_tag="$recovered_tag"
    synoptic_open=true
    if close_synoptic; then
        log_message "recovered a stale Synoptic lock surface"
        return 0
    fi
    log_message "could not recover the prior Synoptic lock surface"
    return 1
}

probe_grabs() {
    local expected_state="$1"
    run_without_sleep_fd timeout --foreground --signal=KILL \
        "${COMMAND_TIMEOUT_SECONDS}s" python3 - "$expected_state" <<'PY'
import ctypes
import sys

EXPECTED = sys.argv[1]
GRAB_SUCCESS = 0
ALREADY_GRABBED = 1
GRAB_MODE_ASYNC = 1
CURRENT_TIME = 0

x11 = ctypes.CDLL("libX11.so.6")
x11.XOpenDisplay.argtypes = [ctypes.c_char_p]
x11.XOpenDisplay.restype = ctypes.c_void_p
x11.XDefaultRootWindow.argtypes = [ctypes.c_void_p]
x11.XDefaultRootWindow.restype = ctypes.c_ulong
x11.XGrabKeyboard.argtypes = [
    ctypes.c_void_p,
    ctypes.c_ulong,
    ctypes.c_int,
    ctypes.c_int,
    ctypes.c_int,
    ctypes.c_ulong,
]
x11.XGrabKeyboard.restype = ctypes.c_int
x11.XUngrabKeyboard.argtypes = [ctypes.c_void_p, ctypes.c_ulong]
x11.XGrabPointer.argtypes = [
    ctypes.c_void_p,
    ctypes.c_ulong,
    ctypes.c_int,
    ctypes.c_uint,
    ctypes.c_int,
    ctypes.c_int,
    ctypes.c_ulong,
    ctypes.c_ulong,
    ctypes.c_ulong,
]
x11.XGrabPointer.restype = ctypes.c_int
x11.XUngrabPointer.argtypes = [ctypes.c_void_p, ctypes.c_ulong]
x11.XSync.argtypes = [ctypes.c_void_p, ctypes.c_int]
x11.XCloseDisplay.argtypes = [ctypes.c_void_p]

display = x11.XOpenDisplay(None)
if not display:
    raise SystemExit(2)

root = x11.XDefaultRootWindow(display)
keyboard = x11.XGrabKeyboard(
    display,
    root,
    1,
    GRAB_MODE_ASYNC,
    GRAB_MODE_ASYNC,
    CURRENT_TIME,
)
if keyboard == GRAB_SUCCESS:
    x11.XUngrabKeyboard(display, CURRENT_TIME)

pointer = x11.XGrabPointer(
    display,
    root,
    1,
    0,
    GRAB_MODE_ASYNC,
    GRAB_MODE_ASYNC,
    0,
    0,
    CURRENT_TIME,
)
if pointer == GRAB_SUCCESS:
    x11.XUngrabPointer(display, CURRENT_TIME)

x11.XSync(display, 0)
x11.XCloseDisplay(display)

if EXPECTED == "available":
    ok = keyboard == GRAB_SUCCESS and pointer == GRAB_SUCCESS
elif EXPECTED == "held":
    ok = keyboard == ALREADY_GRABBED and pointer == ALREADY_GRABBED
else:
    raise SystemExit(2)
raise SystemExit(0 if ok else 1)
PY
}

process_running() {
    local pid="$1" process_pid process_name process_state remainder
    [[ "$pid" =~ ^[1-9][0-9]*$ && -r "/proc/$pid/stat" ]] || return 1
    IFS=' ' read -r process_pid process_name process_state remainder < "/proc/$pid/stat" || return 1
    [[ "$process_pid" == "$pid" && "$process_state" != "Z" ]]
}

wait_for_process_exit() {
    local pid="$1" attempt
    for ((attempt = 0; attempt < PROCESS_STOP_ATTEMPTS; attempt++)); do
        process_running "$pid" || return 0
        sleep "$PROCESS_STOP_INTERVAL"
    done
    return 1
}

xtrlock_locker_running() {
    local process_pid process_name process_state parent_pid process_group remainder
    [[ "$xtrlock_locker_pid" =~ ^[1-9][0-9]*$ \
        && "$xtrlock_group" =~ ^[1-9][0-9]*$ \
        && "$xtrlock_pid" =~ ^[1-9][0-9]*$ \
        && -r "/proc/$xtrlock_locker_pid/stat" ]] || return 1
    IFS=' ' read -r process_pid process_name process_state parent_pid process_group remainder \
        < "/proc/$xtrlock_locker_pid/stat" || return 1
    [[ "$process_pid" == "$xtrlock_locker_pid" \
        && "$process_name" == "(xtrlock)" \
        && "$process_state" != "Z" \
        && "$parent_pid" == "$xtrlock_pid" \
        && "$process_group" == "$xtrlock_group" ]]
}

cleanup_xtrlock_files() {
    [[ -n "$xtrlock_state_file" ]] \
        && run_without_sleep_fd rm -f -- "$xtrlock_state_file" >/dev/null 2>&1 || true
    [[ -n "$xtrlock_ready_file" ]] \
        && run_without_sleep_fd rm -f -- "$xtrlock_ready_file" >/dev/null 2>&1 || true
    xtrlock_state_file=""
    xtrlock_ready_file=""
    xtrlock_group=""
    xtrlock_locker_pid=""
}

refresh_xtrlock_group() {
    local candidate=""
    if [[ -n "$xtrlock_state_file" && -r "$xtrlock_state_file" ]]; then
        IFS= read -r candidate < "$xtrlock_state_file" || candidate=""
    fi
    if [[ "$candidate" =~ ^[1-9][0-9]*$ && "$candidate" -gt 1 ]]; then
        xtrlock_group="$candidate"
        return 0
    fi
    return 1
}

start_xtrlock_supervisor() {
    [[ -d "$runtime_dir" && -w "$runtime_dir" ]] || return 1

    xtrlock_state_file="$runtime_dir/machine-synoptic-lock-${BASHPID}.state"
    xtrlock_ready_file="$runtime_dir/machine-synoptic-lock-${BASHPID}.ready"
    run_without_sleep_fd rm -f -- "$xtrlock_state_file" "$xtrlock_ready_file" \
        >/dev/null 2>&1 || true

    (
        close_sleep_fd_copy || exit 125
        unset XSS_SLEEP_LOCK_FD
        exec python3 - "$xtrlock_state_file" "$xtrlock_ready_file"
    ) <<'PY' &
import ctypes
import os
from pathlib import Path
import signal
import subprocess
import sys
import time

PR_SET_CHILD_SUBREAPER = 36
state_path = Path(sys.argv[1])
ready_path = Path(sys.argv[2])
locker_group = None
pending_signal = None


def write_state(path, value):
    descriptor = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    try:
        os.write(descriptor, (str(value) + "\n").encode())
    finally:
        os.close(descriptor)


def forward_signal(signum, _frame):
    global pending_signal
    pending_signal = signum
    if locker_group is not None:
        try:
            os.killpg(locker_group, signum)
        except ProcessLookupError:
            pass


for forwarded in (signal.SIGHUP, signal.SIGINT, signal.SIGTERM):
    signal.signal(forwarded, forward_signal)

libc = ctypes.CDLL(None, use_errno=True)
if libc.prctl(PR_SET_CHILD_SUBREAPER, 1, 0, 0, 0) != 0:
    raise SystemExit(125)

launcher = subprocess.Popen(["xtrlock", "-f"], start_new_session=True)
locker_group = launcher.pid
write_state(state_path, locker_group)
if pending_signal is not None:
    forward_signal(pending_signal, None)

startup_status = launcher.wait()
if startup_status != 0:
    raise SystemExit(startup_status if startup_status > 0 else 128 - startup_status)

def exit_from_wait_status(status):
    if os.WIFEXITED(status):
        raise SystemExit(os.WEXITSTATUS(status))
    if os.WIFSIGNALED(status):
        raise SystemExit(128 + os.WTERMSIG(status))
    raise SystemExit(125)


def adopted_xtrlock_pid():
    for entry in Path("/proc").iterdir():
        if not entry.name.isdigit():
            continue
        try:
            raw = (entry / "stat").read_text()
            close_paren = raw.rfind(")")
            fields = raw[close_paren + 2:].split()
            state = fields[0]
            parent_pid = int(fields[1])
            process_group = int(fields[2])
            command_name = raw[raw.find("(") + 1:close_paren]
        except (FileNotFoundError, PermissionError, ValueError, IndexError):
            continue
        if (
            parent_pid == os.getpid()
            and process_group == locker_group
            and command_name == "xtrlock"
            and state != "Z"
        ):
            return int(entry.name)
    return None


locker_pid = None
adoption_deadline = time.monotonic() + 5
while time.monotonic() < adoption_deadline:
    try:
        reaped_pid, reaped_status = os.waitpid(-1, os.WNOHANG)
    except ChildProcessError:
        reaped_pid = 0
        reaped_status = 0
    if reaped_pid:
        exit_from_wait_status(reaped_status)
    locker_pid = adopted_xtrlock_pid()
    if locker_pid is not None:
        break
    time.sleep(0.01)
if locker_pid is None:
    raise SystemExit(125)

# xtrlock -f returns success only after its forked locker acquired both grabs.
# Publish the adopted child identity only after its parent/group relationship is proven.
write_state(ready_path, f"{locker_group} {locker_pid}")

try:
    _child_pid, child_status = os.waitpid(locker_pid, 0)
except ChildProcessError:
    raise SystemExit(125)

exit_from_wait_status(child_status)
PY
    xtrlock_pid=$!
}

wait_for_xtrlock_ready() {
    local deadline=$((SECONDS + READY_TIMEOUT_SECONDS))
    local ready_group="" ready_locker_pid="" extra=""
    while ((SECONDS <= deadline)); do
        process_running "$xtrlock_pid" || return 1
        refresh_xtrlock_group || true
        if [[ -n "$xtrlock_ready_file" && -r "$xtrlock_ready_file" ]]; then
            ready_group=""
            ready_locker_pid=""
            extra=""
            IFS=' ' read -r ready_group ready_locker_pid extra \
                < "$xtrlock_ready_file" || ready_group=""
            if [[ -n "$xtrlock_group" \
                && "$ready_group" == "$xtrlock_group" \
                && "$ready_group" =~ ^[1-9][0-9]*$ \
                && "$ready_locker_pid" =~ ^[1-9][0-9]*$ \
                && -z "$extra" ]]; then
                xtrlock_locker_pid="$ready_locker_pid"
            else
                xtrlock_locker_pid=""
            fi
            if [[ -n "$xtrlock_locker_pid" ]] \
                && xtrlock_locker_running \
                && probe_grabs held >/dev/null 2>&1 \
                && synoptic_ready_once \
                && process_running "$xtrlock_pid" \
                && xtrlock_locker_running; then
                return 0
            fi
        fi
        sleep "$READY_INTERVAL"
    done
    return 1
}

stop_xtrlock() {
    if [[ -z "$xtrlock_pid" ]]; then
        cleanup_xtrlock_files
        return 0
    fi

    refresh_xtrlock_group || true
    if [[ -n "$xtrlock_group" ]]; then
        kill -TERM -- "-$xtrlock_group" 2>/dev/null || true
    fi
    kill -TERM "$xtrlock_pid" 2>/dev/null || true

    if wait_for_process_exit "$xtrlock_pid"; then
        wait "$xtrlock_pid" 2>/dev/null || true
        xtrlock_pid=""
        cleanup_xtrlock_files
        return 0
    fi

    if [[ -n "$xtrlock_group" ]]; then
        kill -KILL -- "-$xtrlock_group" 2>/dev/null || true
    fi
    kill -KILL "$xtrlock_pid" 2>/dev/null || true
    if wait_for_process_exit "$xtrlock_pid"; then
        wait "$xtrlock_pid" 2>/dev/null || true
        xtrlock_pid=""
        cleanup_xtrlock_files
        return 0
    fi

    log_message "critical: owned xtrlock supervisor did not exit after TERM/KILL"
    return 1
}

monitor_xtrlock() {
    local surface_failures=0
    xtrlock_status=125

    while process_running "$xtrlock_pid" && xtrlock_locker_running; do
        if synoptic_ready_once; then
            surface_failures=0
        else
            surface_failures=$((surface_failures + 1))
            if ((surface_failures >= MONITOR_FAILURE_LIMIT)); then
                return 2
            fi
        fi
        sleep "$MONITOR_INTERVAL"
    done

    if process_running "$xtrlock_pid"; then
        wait_for_process_exit "$xtrlock_pid" || true
    fi
    if process_running "$xtrlock_pid"; then
        log_message "critical: xtrlock supervisor remained alive after its adopted locker disappeared"
        stop_xtrlock || true
        xtrlock_status=125
        return 0
    fi

    wait "$xtrlock_pid"
    xtrlock_status=$?
    xtrlock_pid=""
    cleanup_xtrlock_files
    return 0
}

publish_synoptic_state() {
    local state="$1"
    if set_synoptic_state "$state"; then
        return 0
    fi
    if [[ "$synoptic_open" == true ]]; then
        log_message "could not publish Synoptic lock state: $state"
    fi
    return 1
}

wait_for_grabs_available() {
    local deadline=$((SECONDS + READY_TIMEOUT_SECONDS))
    while ((SECONDS <= deadline)); do
        probe_grabs available >/dev/null 2>&1 && return 0
        sleep "$READY_INTERVAL"
    done
    return 1
}

wait_for_i3lock_ready() {
    local deadline=$((SECONDS + READY_TIMEOUT_SECONDS))
    while ((SECONDS <= deadline)); do
        process_running "$i3lock_pid" || return 1
        if probe_grabs held >/dev/null 2>&1 && process_running "$i3lock_pid"; then
            return 0
        fi
        sleep "$READY_INTERVAL"
    done
    return 1
}

stop_i3lock() {
    i3lock_status=125
    [[ -n "$i3lock_pid" ]] || return 0

    if ! process_running "$i3lock_pid"; then
        wait "$i3lock_pid" 2>/dev/null
        i3lock_status=$?
        i3lock_pid=""
        return 0
    fi

    kill -TERM "$i3lock_pid" 2>/dev/null || true
    if wait_for_process_exit "$i3lock_pid"; then
        wait "$i3lock_pid" 2>/dev/null
        i3lock_status=$?
        i3lock_pid=""
        return 0
    fi

    kill -KILL "$i3lock_pid" 2>/dev/null || true
    if wait_for_process_exit "$i3lock_pid"; then
        wait "$i3lock_pid" 2>/dev/null
        i3lock_status=$?
        i3lock_pid=""
        return 0
    fi

    log_message "critical: owned i3lock did not exit after TERM/KILL"
    return 1
}

retain_sleep_lock_on_failure() {
    if [[ -z "$sleep_lock_fd" ]]; then
        return 1
    fi
    if [[ ! "$sleep_lock_fd" =~ ^[0-9]+$ \
        || ! -e "/proc/$BASHPID/fd/$sleep_lock_fd" ]]; then
        log_message "critical: no valid suspend-delay descriptor remains to retain"
        return 1
    fi

    log_message "critical: retaining the suspend-delay descriptor to prevent an unlocked suspend"
    while true; do
        run_without_sleep_fd sleep 1 || true
    done
}

run_i3lock_fallback() {
    local reason="$1"
    log_message "using i3lock fallback: $reason"
    publish_synoptic_state fallback || true

    if ! command -v i3lock >/dev/null 2>&1; then
        publish_synoptic_state failure || true
        log_message "critical: i3lock fallback is unavailable"
        retain_sleep_lock_on_failure || true
        return 127
    fi

    if ! wait_for_grabs_available; then
        publish_synoptic_state failure || true
        log_message "critical: input grabs were not available before i3lock startup"
        retain_sleep_lock_on_failure || true
        return 125
    fi

    (
        close_sleep_fd_copy || exit 125
        unset XSS_SLEEP_LOCK_FD
        exec i3lock --nofork -c "$I3LOCK_COLOR"
    ) &
    i3lock_pid=$!
    if ! wait_for_i3lock_ready; then
        local startup_status=125
        if ! process_running "$i3lock_pid"; then
            wait "$i3lock_pid" 2>/dev/null
            startup_status=$?
            i3lock_pid=""
        else
            stop_i3lock || true
            startup_status=$i3lock_status
        fi
        publish_synoptic_state failure || true
        log_message "critical: i3lock fallback did not establish input capture (status $startup_status)"
        retain_sleep_lock_on_failure || true
        return "$startup_status"
    fi

    publish_synoptic_state captured || true
    if ! release_sleep_lock; then
        publish_synoptic_state failure || true
        log_message "critical: i3lock started, but the wrapper retained the suspend-delay descriptor"
        stop_i3lock || true
        retain_sleep_lock_on_failure || true
        return 125
    fi

    local status
    wait "$i3lock_pid"
    status=$?
    i3lock_pid=""
    if [[ $status -eq 0 ]]; then
        close_synoptic_after_authentication
        return 0
    fi

    publish_synoptic_state failure || true
    log_message "critical: i3lock fallback exited with status $status; Synoptic remains visible"
    return "$status"
}

handle_signal() {
    local signal_name="$1" signal_number="$2"
    log_message "received $signal_name; terminating owned locker"

    if [[ -n "$xtrlock_pid" ]]; then
        stop_xtrlock
    fi
    if [[ -n "$i3lock_pid" ]]; then
        stop_i3lock || true
    fi
    close_synoptic || true
    exit $((128 + signal_number))
}

trap 'handle_signal HUP 1' HUP
trap 'handle_signal INT 2' INT
trap 'handle_signal TERM 15' TERM

for dependency in quickshell python3 timeout xwininfo xtrlock; do
    if ! command -v "$dependency" >/dev/null 2>&1; then
        run_i3lock_fallback "missing dependency: $dependency"
        exit $?
    fi
done

if ! command -v i3lock >/dev/null 2>&1; then
    run_i3lock_fallback "i3lock fallback is unavailable"
    exit $?
fi

if [[ ! -d "$runtime_dir" || ! -w "$runtime_dir" ]]; then
    run_i3lock_fallback "runtime directory is unavailable: $runtime_dir"
    exit $?
fi

if ! recover_previous_synoptic; then
    run_i3lock_fallback "prior Synoptic lock state could not be recovered"
    exit $?
fi

if ! probe_grabs available >/dev/null 2>&1; then
    log_message "critical: keyboard or pointer was already grabbed before lock startup"
    retain_sleep_lock_on_failure || true
    exit 125
fi

IFS= read -r lock_token < /proc/sys/kernel/random/uuid
IFS= read -r lock_window_tag < /proc/sys/kernel/random/uuid
if [[ -z "$lock_token" || -z "$lock_window_tag" || "$lock_token" == "$lock_window_tag" ]]; then
    clear_synoptic_tracking
    run_i3lock_fallback "could not allocate unique lock identifiers"
    exit $?
fi

open_response="$(ipc_call_retry openLock "$lock_token" "$lock_window_tag")"
open_status=$?
if [[ $open_status -ne 0 ]]; then
    log_message "Machine Synoptic openLock IPC failed with status $open_status"
    open_response=""
elif [[ -z "$open_response" ]]; then
    log_message "Machine Synoptic openLock IPC returned an empty response"
fi
if [[ "$open_response" != "locked" ]]; then
    lock_token=""
    lock_window_tag=""
    run_i3lock_fallback "Machine Synoptic lock mode was unavailable"
    exit $?
fi
synoptic_open=true

if ! persist_synoptic_recovery; then
    close_synoptic || true
    run_i3lock_fallback "could not persist Synoptic recovery state"
    exit $?
fi

if ! wait_for_synoptic; then
    run_i3lock_fallback "Machine Synoptic surfaces did not become viewable"
    exit $?
fi

if ! start_xtrlock_supervisor; then
    run_i3lock_fallback "xtrlock supervisor could not start"
    exit $?
fi

if ! wait_for_xtrlock_ready; then
    stop_xtrlock
    run_i3lock_fallback "xtrlock did not report successful input capture"
    exit $?
fi

if ! set_synoptic_state captured \
    || ! synoptic_ready_once \
    || ! process_running "$xtrlock_pid" \
    || ! xtrlock_locker_running \
    || ! probe_grabs held >/dev/null 2>&1 \
    || ! process_running "$xtrlock_pid" \
    || ! xtrlock_locker_running; then
    stop_xtrlock
    run_i3lock_fallback "final lock readiness recheck failed"
    exit $?
fi

if ! release_sleep_lock; then
    stop_xtrlock
    run_i3lock_fallback "suspend-delay descriptor release failed"
    exit $?
fi
log_message "Machine Synoptic is visible and xtrlock reported successful input capture"

if ! monitor_xtrlock; then
    stop_xtrlock
    run_i3lock_fallback "Machine Synoptic lost required surfaces while xtrlock was active"
    exit $?
fi

if [[ $xtrlock_status -eq 0 ]]; then
    close_synoptic_after_authentication
    exit 0
fi

run_i3lock_fallback "xtrlock exited with status $xtrlock_status"
exit $?
