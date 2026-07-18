#!/usr/bin/env bash
set -euo pipefail

TEST_COUNT=0
FAIL_COUNT=0

pass() {
    TEST_COUNT=$((TEST_COUNT + 1))
    printf 'ok %d - %s\n' "$TEST_COUNT" "$1"
}

fail() {
    TEST_COUNT=$((TEST_COUNT + 1))
    FAIL_COUNT=$((FAIL_COUNT + 1))
    printf 'not ok %d - %s\n' "$TEST_COUNT" "$1" >&2
}

assert_eq() {
    local description="$1"
    local expected="$2"
    local actual="$3"

    if [[ "$expected" == "$actual" ]]; then
        pass "$description"
    else
        fail "$description (expected: ${expected@Q}; actual: ${actual@Q})"
    fi
}

assert_contains() {
    local description="$1"
    local needle="$2"
    shift 2
    local item

    for item in "$@"; do
        if [[ "$item" == "$needle" ]]; then
            pass "$description"
            return 0
        fi
    done

    fail "$description (missing: ${needle@Q})"
}

assert_not_contains() {
    local description="$1"
    local needle="$2"
    shift 2
    local item

    for item in "$@"; do
        if [[ "$item" == "$needle" ]]; then
            fail "$description (unexpected: ${needle@Q})"
            return 0
        fi
    done

    pass "$description"
}

assert_file_exists() {
    local description="$1"
    local path="$2"

    if [[ -f "$path" ]]; then
        pass "$description"
    else
        fail "$description (missing file: ${path@Q})"
    fi
}

assert_text_contains() {
    local description="$1"
    local needle="$2"
    local text="$3"

    if [[ "$text" == *"$needle"* ]]; then
        pass "$description"
    else
        fail "$description (missing text: ${needle@Q})"
    fi
}

assert_text_not_contains() {
    local description="$1"
    local needle="$2"
    local text="$3"

    if [[ "$text" == *"$needle"* ]]; then
        fail "$description (unexpected text: ${needle@Q})"
    else
        pass "$description"
    fi
}

assert_empty_file() {
    local description="$1"
    local path="$2"

    if [[ ! -s "$path" ]]; then
        pass "$description"
    else
        fail "$description (expected empty: ${path@Q})"
    fi
}

finish_tests() {
    printf '1..%d\n' "$TEST_COUNT"
    if (( FAIL_COUNT > 0 )); then
        printf '%d test(s) failed\n' "$FAIL_COUNT" >&2
        return 1
    fi
}
