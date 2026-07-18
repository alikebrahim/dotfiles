#!/usr/bin/env bash
set -euo pipefail

# Aggregate test runner for all deploy tests.
# Usage: bash tests/deploy/run-all.sh

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TEST_DIR="$ROOT/tests/deploy"

pass=0
fail=0

printf 'Running deploy test suite...\n\n'

for test_file in "$TEST_DIR"/test-*.sh; do
    [[ -f "$test_file" ]] || continue
    name="$(basename "$test_file")"
    printf '  %-40s' "$name"
    if bash "$test_file" >/dev/null 2>&1; then
        printf 'PASS\n'
        pass=$((pass + 1))
    else
        printf 'FAIL\n'
        fail=$((fail + 1))
        bash "$test_file" 2>&1 | head -5 | sed 's/^/    /'
    fi
done

printf '\n%d passed, %d failed\n' "$pass" "$fail"

if (( fail > 0 )); then
    exit 1
fi
exit 0
