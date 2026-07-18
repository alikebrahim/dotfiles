#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=tests/deploy/testlib.sh
source "$ROOT/tests/deploy/testlib.sh"
# shellcheck source=scripts/lib/module-runner.sh
source "$ROOT/scripts/lib/module-runner.sh"

TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT
mkdir -p "$TMPDIR/bin" "$TMPDIR/system-root"

cat > "$TMPDIR/bin/rpm" <<'MOCK'
#!/usr/bin/env bash
[[ "$1" == -q ]] && [[ "$2" == ly || "$2" == mate-polkit || "$2" == 1password ]]
MOCK
cat > "$TMPDIR/bin/systemctl" <<'MOCK'
#!/usr/bin/env bash
case "$*" in
    *is-enabled*) printf 'enabled\n' ;;
    *is-active*) printf 'active\n' ;;
    *) exit 1 ;;
esac
MOCK
chmod +x "$TMPDIR/bin/rpm" "$TMPDIR/bin/systemctl"

PATH="$TMPDIR/bin:$PATH"
module_runner_init "$ROOT" "$TMPDIR/system-root"

ly_status="$(module_run system:ly-display-manager status)"
assert_text_contains "Ly service module recognizes enabled Ly" "CURRENT" "$ly_status"
assert_text_contains "Ly service module names tty2 unit" "ly@tty2.service" "$ly_status"

polkit_status="$(module_run system:mate-polkit-package status)"
assert_text_contains "MATE Polkit module recognizes installed package" "CURRENT" "$polkit_status"

keyring_status="$(module_run user:gnome-keyring-units status)"
assert_text_contains "keyring module recognizes enabled user units" "CURRENT" "$keyring_status"

awesome_status="$(module_run user:awesome-auth-startup status)"
assert_text_contains "Awesome module recognizes configured Polkit startup" "CURRENT" "$awesome_status"

finish_tests
