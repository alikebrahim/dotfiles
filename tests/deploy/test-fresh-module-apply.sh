#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT/tests/deploy/testlib.sh"
source "$ROOT/scripts/lib/module-runner.sh"

TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT
mkdir -p "$TMPDIR/bin" "$TMPDIR/system-root"
CALLS="$TMPDIR/calls"

cat > "$TMPDIR/bin/rpm" <<'MOCK'
#!/usr/bin/env bash
exit 1
MOCK
cat > "$TMPDIR/bin/dnf" <<'MOCK'
#!/usr/bin/env bash
printf 'dnf %s\n' "$*" >> "$CALLS"
MOCK
cat > "$TMPDIR/bin/systemctl" <<'MOCK'
#!/usr/bin/env bash
case "$1" in
  is-enabled|is-active) exit 1 ;;
  *) printf 'systemctl %s\n' "$*" >> "$CALLS" ;;
esac
MOCK
chmod +x "$TMPDIR/bin/rpm" "$TMPDIR/bin/dnf" "$TMPDIR/bin/systemctl"

export CALLS
PATH="$TMPDIR/bin:$PATH"
module_runner_init "$ROOT" "$TMPDIR/system-root"

# Keep the probe unprivileged and observable while requiring modules to use
# the shared helper name.
run_as_root() { "$@"; }

set +e
module_run system:ly-display-manager apply >/dev/null 2>&1
ly_rc=$?
module_run system:mate-polkit-package apply >/dev/null 2>&1
mate_rc=$?
set -e

assert_eq "fresh Ly apply succeeds through shared root helper" "0" "$ly_rc"
assert_eq "fresh MATE Polkit apply succeeds through shared root helper" "0" "$mate_rc"
calls="$(cat "$CALLS" 2>/dev/null || true)"
assert_text_contains "Ly package install was requested" "dnf install -y ly" "$calls"
assert_text_contains "Ly service enable was requested" "systemctl enable --now ly@tty2.service" "$calls"
assert_text_contains "MATE Polkit package install was requested" "dnf install -y mate-polkit" "$calls"

finish_tests
