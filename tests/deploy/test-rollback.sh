#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT/tests/deploy/testlib.sh"
source "$ROOT/scripts/lib/module-runner.sh"
source "$ROOT/scripts/lib/rollback.sh"

TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT
SYSTEM_ROOT="$TMPDIR/system-root"
RUN_DIR="$TMPDIR/run"
mkdir -p "$SYSTEM_ROOT/etc/example" "$RUN_DIR/backup"
printf 'old bytes\n' > "$SYSTEM_ROOT/etc/example/config"
printf 'new bytes\n' > "$TMPDIR/source"

CONFIGURE_HOST_BACKUP_DIR="$RUN_DIR/backup"
CONFIGURE_HOST_ROLLBACK_MANIFEST="$RUN_DIR/rollback.tsv"
: > "$CONFIGURE_HOST_ROLLBACK_MANIFEST"
module_runner_init "$ROOT" "$SYSTEM_ROOT"

module_manage_file apply system:test "$TMPDIR/source" /etc/example/config 0644 >/dev/null
assert_eq "apply writes new managed bytes" "new bytes" "$(tr -d '\n' < "$SYSTEM_ROOT/etc/example/config")"
assert_file_exists "apply creates a previous-file backup" "$RUN_DIR/backup/etc/example/config"
assert_eq "backup preserves previous bytes" "old bytes" "$(tr -d '\n' < "$RUN_DIR/backup/etc/example/config")"
assert_text_contains "rollback manifest records managed target" "/etc/example/config" "$(cat "$CONFIGURE_HOST_ROLLBACK_MANIFEST")"

printf 'PACKAGE\tly\tABSENT\nSTOW\tzsh\tDRIFT\nSERVICE\tsystem\tly@tty2.service\tdisabled\tinactive\n' \
    >> "$CONFIGURE_HOST_ROLLBACK_MANIFEST"
rollback_plan="$(rollback_describe_manifest "$CONFIGURE_HOST_ROLLBACK_MANIFEST")"
assert_text_contains "rollback plan reports retained package" "installed package ly" "$rollback_plan"
assert_text_contains "rollback plan reports Stow review" "Stow package zsh" "$rollback_plan"
assert_text_contains "rollback plan reports prior service state" "ly@tty2.service was disabled/inactive" "$rollback_plan"

rollback_apply_manifest "$CONFIGURE_HOST_ROLLBACK_MANIFEST" "$SYSTEM_ROOT" >/dev/null
assert_eq "rollback restores previous bytes" "old bytes" "$(tr -d '\n' < "$SYSTEM_ROOT/etc/example/config")"

FORGED="$RUN_DIR/forged.tsv"
OUTSIDE="$TMPDIR/outside-backup"
printf 'forged bytes\n' > "$OUTSIDE"
printf 'FILE\t/etc/example/forged\tPRESENT\t%s\t0644\t%s\t%s\n' \
    "$OUTSIDE" "$(id -u)" "$(id -g)" > "$FORGED"
set +e
rollback_apply_manifest "$FORGED" "$SYSTEM_ROOT" >/dev/null 2>&1
forged_rc=$?
set -e
assert_eq "rollback rejects backups outside the run tree" "$EXIT_BLOCKED" "$forged_rc"
[[ ! -e "$SYSTEM_ROOT/etc/example/forged" ]] && pass "forged rollback writes no target" || fail "forged rollback writes no target"

finish_tests
