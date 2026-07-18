#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=tests/deploy/testlib.sh
source "$ROOT/tests/deploy/testlib.sh"
# shellcheck source=scripts/lib/bootstrap.sh
source "$ROOT/scripts/lib/bootstrap.sh"

fedora_plan="$(bootstrap_plan_for fedora stow gum)"
assert_text_contains "Fedora bootstrap uses dnf" "dnf install -y stow gum" "$fedora_plan"
assert_text_not_contains "Fedora bootstrap does not add Charm repositories" "repo.charm.sh" "$fedora_plan"

ubuntu_plan="$(bootstrap_plan_for ubuntu stow gum)"
assert_text_contains "Ubuntu bootstrap refreshes apt metadata" "apt-get update" "$ubuntu_plan"
assert_text_contains "Ubuntu bootstrap uses apt-get" "apt-get install -y stow gum" "$ubuntu_plan"

assert_eq "Fedora less maps to less package" "less" "$(bootstrap_package_for fedora less)"
assert_eq "Fedora column maps to util-linux" "util-linux" "$(bootstrap_package_for fedora column)"
assert_eq "Ubuntu flock maps to util-linux" "util-linux" "$(bootstrap_package_for ubuntu flock)"
bootstrap_status_output="$(bootstrap_status)"
assert_text_contains "bootstrap status includes pager" "less" "$bootstrap_status_output"
assert_text_contains "bootstrap status includes locking" "flock" "$bootstrap_status_output"

set +e
unsupported_output="$(bootstrap_plan_for termux stow 2>&1)"
unsupported_rc=$?
set -e
assert_eq "unsupported bootstrap OS fails safely" "2" "$unsupported_rc"
assert_text_contains "unsupported bootstrap explains supported systems" "Fedora and Ubuntu" "$unsupported_output"

finish_tests
