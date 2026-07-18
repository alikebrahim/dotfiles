#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=tests/deploy/testlib.sh
source "$ROOT/tests/deploy/testlib.sh"

TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT
mkdir -p "$TMPDIR/bin" "$TMPDIR/home" "$TMPDIR/system-root"
CALL_LOG="$TMPDIR/calls.log"
: > "$CALL_LOG"

write_mock() {
    local name="$1"
    cat > "$TMPDIR/bin/$name"
    chmod +x "$TMPDIR/bin/$name"
}

write_mock stow <<'MOCK'
#!/usr/bin/env bash
if [[ "${1:-}" == --version ]]; then
    printf 'stow (GNU Stow) version 2.4.1\n'
    exit 0
fi
printf 'stow' >> "$CALL_LOG"
printf ' %q' "$@" >> "$CALL_LOG"
printf '\n' >> "$CALL_LOG"
MOCK

for command in sudo dnf apt-get git curl; do
    write_mock "$command" <<'MOCK'
#!/usr/bin/env bash
printf '%s' "$(basename "$0")" >> "$CALL_LOG"
printf ' %q' "$@" >> "$CALL_LOG"
printf '\n' >> "$CALL_LOG"
MOCK
done

run_configure_host() {
    PATH="$TMPDIR/bin:$PATH" \
    CALL_LOG="$CALL_LOG" \
    HOME="$TMPDIR/home" \
    DOTFILES="$ROOT" \
    CONFIGURE_HOST_SYSTEM_ROOT="$TMPDIR/system-root" \
    bash "$ROOT/scripts/configure-host.sh" "$@"
}

set +e
plan_output="$(run_configure_host plan --host servalws 2>&1)"
plan_rc=$?
set -e
assert_eq "plan succeeds for servalws" "0" "$plan_rc"
assert_text_contains "plan identifies the selected profile" "Profile: servalws" "$plan_output"
assert_text_contains "plan includes the Ly animation module" "system:ly-screen" "$plan_output"
assert_text_contains "plan reports Ly target drift" "ABSENT /etc/ly/config.ini" "$plan_output"
assert_text_contains "plan simulates Stow before applying" "--simulate" "$(<"$CALL_LOG")"
assert_text_not_contains "plan does not invoke sudo" "sudo" "$(<"$CALL_LOG")"
assert_text_not_contains "plan does not invoke package managers" "dnf" "$(<"$CALL_LOG")"
assert_text_not_contains "plan does not invoke Git" $'\ngit ' "$(<"$CALL_LOG")"
assert_text_not_contains "plan does not globally unstow" "-D" "$(<"$CALL_LOG")"

: > "$CALL_LOG"
set +e
system_plan_output="$(run_configure_host plan --host servalws --scope system 2>&1)"
system_plan_rc=$?
set -e
assert_eq "system-only plan succeeds" "0" "$system_plan_rc"
assert_text_contains "system-only plan includes Ly configuration" "ABSENT /etc/ly/config.ini" "$system_plan_output"
assert_empty_file "system-only plan does not invoke Stow" "$CALL_LOG"

: > "$CALL_LOG"
set +e
bootstrap_output="$(run_configure_host bootstrap --host servalws 2>&1)"
bootstrap_rc=$?
set -e
assert_eq "bootstrap status succeeds when prerequisites are current" "0" "$bootstrap_rc"
assert_text_contains "bootstrap reports current prerequisites" "CURRENT prerequisites are installed" "$bootstrap_output"
assert_text_not_contains "bootstrap status invokes no package manager" "dnf" "$(<"$CALL_LOG")"

: > "$CALL_LOG"
for plugin in tpm tmux-sensible tmux-resurrect tmux-continuum tmux-fzf; do
    mkdir -p "$TMPDIR/home/.tmux/plugins/$plugin/.git"
done
set +e
update_output="$(run_configure_host update tmux-plugins --host servalws --yes 2>&1)"
update_rc=$?
set -e
assert_eq "explicit tmux-plugin update succeeds" "0" "$update_rc"
assert_text_contains "explicit tmux-plugin update invokes Git pull" "pull" "$(<"$CALL_LOG")"

: > "$CALL_LOG"
set +e
unknown_output="$(run_configure_host apply --host unknown --yes 2>&1)"
unknown_rc=$?
set -e
if (( unknown_rc != 0 )); then
    pass "apply rejects unknown hosts"
else
    fail "apply rejects unknown hosts"
fi
assert_text_contains "unknown-host refusal explains the override" "--allow-unknown-host" "$unknown_output"
assert_empty_file "unknown-host refusal invokes no side-effect commands" "$CALL_LOG"

finish_tests
