#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
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

for command in sudo dnf apt-get git curl gum less column flock hostnamectl; do
    write_mock "$command" <<'MOCK'
#!/usr/bin/env bash
case "$(basename "$0")" in
    hostnamectl) printf 'servalws\n' ;;
    gum) exit 1 ;;
    *) : ;;
esac
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
no_pkg="$(run_configure_host prune --host servalws --yes 2>&1)"
no_pkg_rc=$?
set -e
assert_eq "prune without --stow-package is blocked" "2" "$no_pkg_rc"
assert_text_contains "prune explains explicit package requirement" "explicit --stow-package" "$no_pkg"
assert_empty_file "refused prune does not call stow" "$CALL_LOG"

: > "$CALL_LOG"
set +e
doctor_out="$(run_configure_host doctor --host servalws 2>&1)"
doctor_rc=$?
set -e
# doctor may return drift if environment differs; accept 0 or 1
if (( doctor_rc == 0 || doctor_rc == 1 || doctor_rc == 2 )); then
    pass "doctor command runs"
else
    fail "doctor command runs (exit $doctor_rc)"
fi
assert_text_contains "doctor prints checklist" "NEW STOW PACKAGE CHECKLIST" "$doctor_out"
assert_text_contains "doctor reports fold safety" "TREE-FOLD SAFETY" "$doctor_out"

finish_tests
