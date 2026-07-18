#!/usr/bin/env bash
# Structured logging for configure-host. All output goes to stderr.

_LOG_VERBOSE="${_LOG_VERBOSE:-false}"

log_set_verbose() {
    _LOG_VERBOSE="$1"
}

log_info() {
    printf '%s\n' "$*" >&2
}

log_warn() {
    printf 'WARN: %s\n' "$*" >&2
}

log_error() {
    printf 'ERROR: %s\n' "$*" >&2
}

log_debug() {
    [[ "$_LOG_VERBOSE" == true ]] || return 0
    printf 'DEBUG: %s\n' "$*" >&2
}
