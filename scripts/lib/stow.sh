#!/usr/bin/env bash
# Safe GNU Stow helpers. Normal deployment only restows selected packages.

STOW_ROOT=""
STOW_HOME=""
STOW_VERBOSE="${STOW_VERBOSE:-false}"

# Safety directories that must exist as real directories (not symlinks)
# to prevent GNU Stow tree-folding.
STOW_SAFETY_DIRS=()
STOW_IGNORE_PATTERNS=()

_stow_init_safety_dirs() {
    STOW_SAFETY_DIRS=(
        "$STOW_HOME/.local"
        "$STOW_HOME/.local/state"
        "$STOW_HOME/.local/share"
        "$STOW_HOME/.tmux"
    )
}

stow_init() {
    STOW_ROOT="$1"
    STOW_HOME="$2"
    _stow_init_safety_dirs
}

stow_package_name_is_safe() {
    [[ "$1" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]]
}

stow_package_exists() {
    [[ -d "${STOW_ROOT}/$1" ]]
}

stow_command() {
    stow --dir "$STOW_ROOT" --target "$STOW_HOME" "$@"
}

stow_safety_check() {
    local directory

    for directory in "${STOW_SAFETY_DIRS[@]}"; do
        if [[ -L "$directory" ]]; then
            printf '%s tree-fold safety path is a symlink: %s\n' \
                "$STATUS_BLOCKED" "$directory" >&2
            return "$EXIT_BLOCKED"
        fi
        if [[ -e "$directory" && ! -d "$directory" ]]; then
            printf '%s tree-fold safety path is not a directory: %s\n' \
                "$STATUS_BLOCKED" "$directory" >&2
            return "$EXIT_BLOCKED"
        fi
    done
}

stow_safety_plan() {
    local directory

    stow_safety_check
    for directory in "${STOW_SAFETY_DIRS[@]}"; do
        if [[ -d "$directory" ]]; then
            printf '%s safety directory: %s\n' "$STATUS_CURRENT" "$directory"
        else
            printf '%s safety directory: %s\n' "$STATUS_ABSENT" "$directory"
        fi
    done
}

stow_ensure_safety_dirs() {
    local directory

    stow_safety_check
    for directory in "${STOW_SAFETY_DIRS[@]}"; do
        [[ -d "$directory" ]] || mkdir -p "$directory"
    done
}

stow_validate_package() {
    local package="$1"

    if ! stow_package_name_is_safe "$package"; then
        printf '%s invalid Stow package name: %s\n' "$STATUS_BLOCKED" "$package" >&2
        return "$EXIT_BLOCKED"
    fi
    if ! stow_package_exists "$package"; then
        printf '%s selected package is absent from repository: %s\n' \
            "$STATUS_SKIP" "$package"
        return "$EXIT_DRIFT"
    fi
}

# Load .stow-local-ignore as literal path prefixes/segments (repo convention).
# Lines starting with '/' are treated as ERE against the relative path.
_stow_load_ignore_patterns() {
    local package="$1"
    local ignore_file="${STOW_ROOT}/${package}/.stow-local-ignore"
    local line
    STOW_IGNORE_PATTERNS=()
    [[ -r "$ignore_file" ]] || return 0
    while IFS= read -r line || [[ -n "$line" ]]; do
        line="${line#"${line%%[![:space:]]*}"}"
        line="${line%"${line##*[![:space:]]}"}"
        [[ -z "$line" || "$line" == \#* ]] && continue
        STOW_IGNORE_PATTERNS+=("$line")
    done < "$ignore_file"
}

_stow_path_is_ignored() {
    local rel="$1"
    local pattern base
    base="$(basename -- "$rel")"
    [[ "$base" == ".stow-local-ignore" ]] && return 0
    for pattern in "${STOW_IGNORE_PATTERNS[@]+"${STOW_IGNORE_PATTERNS[@]}"}"; do
        if [[ "$pattern" == /* ]]; then
            local ere="${pattern#/}"
            ere="${ere%/}"
            [[ "$rel" =~ $ere ]] && return 0
            continue
        fi
        if [[ "$rel" == "$pattern" ||
              "$rel" == "$pattern"/* ||
              "$rel" == */"$pattern" ||
              "$rel" == */"$pattern"/* ]]; then
            return 0
        fi
    done
    return 1
}

# Enumerate managed package files (respects .stow-local-ignore).
# Prints relative paths, one per line.
stow_package_managed_files() {
    local package="$1"
    local source_dir source_file rel
    source_dir="${STOW_ROOT}/${package}"
    _stow_load_ignore_patterns "$package"
    while IFS= read -r -d '' source_file; do
        rel="${source_file#${source_dir}/}"
        _stow_path_is_ignored "$rel" && continue
        printf '%s\n' "$rel"
    done < <(find "$source_dir" \( -type f -o -type l \) -print0 2>/dev/null)
}

# Print conflict lines: CONFLICT <rel> -> <target> (<reason>)
stow_package_conflict_report() {
    local package="$1"
    local source_dir rel target
    local conflicts=0
    source_dir="${STOW_ROOT}/${package}"

    stow_package_exists "$package" || return "$EXIT_DRIFT"
    while IFS= read -r rel; do
        [[ -n "$rel" ]] || continue
        target="${STOW_HOME}/${rel}"
        if [[ ! -e "$target" && ! -L "$target" ]]; then
            continue
        fi
        if [[ "${source_dir}/${rel}" -ef "$target" ]]; then
            continue
        fi
        if [[ -L "$target" ]]; then
            printf 'CONFLICT %s -> %s (symlink points elsewhere)\n' "$rel" "$target"
        elif [[ -f "$target" ]]; then
            printf 'CONFLICT %s -> %s (real file blocks Stow; refuse --adopt)\n' "$rel" "$target"
        else
            printf 'CONFLICT %s -> %s (unexpected target type)\n' "$rel" "$target"
        fi
        ((conflicts += 1))
    done < <(stow_package_managed_files "$package")

    (( conflicts > 0 )) && return "$EXIT_DRIFT"
    return "$EXIT_OK"
}

stow_simulate_package() {
    local package="$1"
    local output

    if ! output="$(stow_command --simulate -v -R "$package" 2>&1)"; then
        printf '%s Stow simulation failed for package: %s\n' \
            "$STATUS_BLOCKED" "$package" >&2
        [[ -n "$output" ]] && printf '%s\n' "$output" >&2
        stow_package_conflict_report "$package" >&2 || true
        return "$EXIT_BLOCKED"
    fi
    printf '%s %s\n' "$STATUS_CURRENT" "$package"
    if [[ "$STOW_VERBOSE" == true && -n "$output" ]]; then
        printf '%s\n' "$output"
    fi
    return "$EXIT_OK"
}

stow_plan_packages() {
    local package
    local rc

    [[ -n "$STOW_ROOT" && -n "$STOW_HOME" ]] || {
        printf 'stow_init must be called before Stow operations\n' >&2
        return "$EXIT_INTERNAL"
    }

    stow_safety_plan
    for package in "$@"; do
        stow_validate_package "$package" || {
            rc=$?
            [[ $rc -eq "$EXIT_DRIFT" ]] && continue
            return "$rc"
        }
        printf '%s restow package: %s\n' "$STATUS_INSTALL" "$package"
        stow_simulate_package "$package" || return $?
        stow_package_conflict_report "$package" || true
    done
}

stow_apply_packages() {
    local package
    local rc
    local output

    [[ -n "$STOW_ROOT" && -n "$STOW_HOME" ]] || {
        printf 'stow_init must be called before Stow operations\n' >&2
        return "$EXIT_INTERNAL"
    }

    stow_ensure_safety_dirs
    for package in "$@"; do
        stow_validate_package "$package" || {
            rc=$?
            [[ $rc -eq "$EXIT_DRIFT" ]] && continue
            return "$rc"
        }
        stow_simulate_package "$package" || return $?
        if ! output="$(stow_command -R "$package" 2>&1)"; then
            printf '%s restow failed for package: %s\n' "$STATUS_BLOCKED" "$package" >&2
            [[ -n "$output" ]] && printf '%s\n' "$output" >&2
            printf '%s stow -R is delete-then-create; links may be partially removed.\n' \
                "$STATUS_BLOCKED" >&2
            printf '%s re-run: configure-host status/plan --scope stow --stow-package %s\n' \
                "$STATUS_BLOCKED" "$package" >&2
            printf '%s resolve real-file conflicts, then apply again (no --adopt).\n' \
                "$STATUS_BLOCKED" >&2
            stow_package_status "$package" >&2 || true
            stow_package_conflict_report "$package" >&2 || true
            return "$EXIT_BLOCKED"
        fi
        [[ -n "$output" && "$STOW_VERBOSE" == true ]] && printf '%s\n' "$output"
        printf '%s restowed package: %s\n' "$STATUS_CHANGED" "$package"
    done
}

stow_prune_packages() {
    local package
    local rc
    local output

    [[ -n "$STOW_ROOT" && -n "$STOW_HOME" ]] || {
        printf 'stow_init must be called before Stow operations\n' >&2
        return "$EXIT_INTERNAL"
    }

    for package in "$@"; do
        stow_validate_package "$package" || {
            rc=$?
            [[ $rc -eq "$EXIT_DRIFT" ]] && continue
            return "$rc"
        }
        printf '%s prune package: %s\n' "$STATUS_INSTALL" "$package"
        if ! output="$(stow_command --simulate -v -D "$package" 2>&1)"; then
            printf '%s prune simulation failed for package: %s\n' \
                "$STATUS_BLOCKED" "$package" >&2
            [[ -n "$output" ]] && printf '%s\n' "$output" >&2
            return "$EXIT_BLOCKED"
        fi
        [[ "$STOW_VERBOSE" == true && -n "$output" ]] && printf '%s\n' "$output"
        if ! stow_command -D "$package"; then
            printf '%s prune failed for package: %s\n' "$STATUS_BLOCKED" "$package" >&2
            return "$EXIT_BLOCKED"
        fi
        printf '%s pruned package: %s\n' "$STATUS_CHANGED" "$package"
    done
}

# Return all Stow packages available in the repository.
stow_list_all_packages() {
    [[ -n "$STOW_ROOT" ]] || return "$EXIT_INTERNAL"
    local entry
    for entry in "$STOW_ROOT"/*/; do
        [[ -d "$entry" ]] || continue
        basename "$entry"
    done
}

# Check status of a single Stow package (CURRENT / ABSENT / DRIFT / BLOCKED).
stow_package_status() {
    local package="$1"
    local source_dir rel target
    local total=0 linked=0 missing=0 conflicts=0

    if ! stow_package_exists "$package"; then
        printf '%s %s\n' "$STATUS_ABSENT" "$package"
        return "$EXIT_DRIFT"
    fi

    source_dir="${STOW_ROOT}/${package}"
    while IFS= read -r rel; do
        [[ -n "$rel" ]] || continue
        target="${STOW_HOME}/${rel}"
        ((total += 1))
        if [[ ! -e "$target" && ! -L "$target" ]]; then
            ((missing += 1))
            continue
        fi
        if [[ "${source_dir}/${rel}" -ef "$target" ]]; then
            ((linked += 1))
        else
            ((conflicts += 1))
        fi
    done < <(stow_package_managed_files "$package")

    if (( total == 0 )); then
        printf '%s %s has no managed files\n' "$STATUS_BLOCKED" "$package"
        return "$EXIT_BLOCKED"
    fi
    if (( linked == total )); then
        printf '%s %s (%d/%d linked)\n' "$STATUS_CURRENT" "$package" "$linked" "$total"
        return "$EXIT_OK"
    fi
    if (( linked == 0 && conflicts == 0 )); then
        printf '%s %s (0/%d linked)\n' "$STATUS_ABSENT" "$package" "$total"
        return "$EXIT_DRIFT"
    fi
    printf '%s %s (%d/%d linked, %d missing, %d conflicts)\n' \
        "$STATUS_DRIFT" "$package" "$linked" "$total" "$missing" "$conflicts"
    return "$EXIT_DRIFT"
}
