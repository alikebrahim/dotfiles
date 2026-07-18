#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT/tests/deploy/testlib.sh"
source "$ROOT/scripts/lib/module-runner.sh"
module_runner_init "$ROOT" /tmp/test-system-root

modules=(
  system:xorg-libinput
  system:1password-unlock-polkit
  system:ly-display-manager
  system:ly-screen
  system:mate-polkit-package
  user:gnome-keyring-units
  user:awesome-auth-startup
)

for module in "${modules[@]}"; do
    label="$(module_metadata "$module" label)"
    description="$(module_metadata "$module" description)"
    privilege="$(module_metadata "$module" privilege)"
    risk="$(module_metadata "$module" risk)"
    impact="$(module_metadata "$module" impact)"
    [[ -n "$label" ]] && pass "$module has a label" || fail "$module has a label"
    [[ -n "$description" ]] && pass "$module has a description" || fail "$module has a description"
    [[ "$privilege" == root || "$privilege" == user ]] && pass "$module has valid privilege" || fail "$module has valid privilege"
    [[ "$risk" == low || "$risk" == medium || "$risk" == high ]] && pass "$module has valid risk" || fail "$module has valid risk"
    [[ -n "$impact" ]] && pass "$module describes impact" || fail "$module describes impact"
done

assert_eq "system module requires root" "root" "$(module_metadata system:xorg-libinput privilege)"
assert_eq "user module stays unprivileged" "user" "$(module_metadata user:awesome-auth-startup privilege)"

finish_tests
