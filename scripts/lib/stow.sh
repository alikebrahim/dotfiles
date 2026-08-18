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
# Anchored or slash-prefixed expressions are matched against /<relative-path>,
# which mirrors GNU Stow's package-relative ignore boundary.
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
        if [[ "$pattern" == ^/* ]]; then
            [[ "/$rel" =~ $pattern ]] && return 0
            continue
        fi
        if [[ "$pattern" == /* ]]; then
            local ere="^${pattern}"
            [[ "/$rel" =~ $ere ]] && return 0
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

# Return the narrowest shared target directory for orphan scanning. Limit the
# scan to three directory components, which covers paths such as
# .local/share/icons without traversing unrelated shared data under
# ~/.local/share (for example container storage).
_stow_orphan_scan_root() {
    local rel="$1" directory part root="" components=0

    directory="${rel%/*}"
    [[ "$directory" != "$rel" && -n "$directory" ]] || return 1
    while [[ -n "$directory" && $components -lt 3 ]]; do
        part="${directory%%/*}"
        if [[ "$part" == "$directory" ]]; then
            directory=""
        else
            directory="${directory#*/}"
        fi
        root+="${root:+/}${part}"
        (( components += 1 ))
    done
    printf '%s\n' "$root"
}

# Print target-relative symlinks that still point into a selected package but no
# longer have a source path. Never scan the whole home tree or shared roots such
# as ~/.local/share.
stow_package_orphaned_links() {
    local package="$1"
    local source_dir rel scan_root target_root target link_value resolved
    local -A target_roots=()

    source_dir="${STOW_ROOT}/${package}"
    stow_package_exists "$package" || return "$EXIT_DRIFT"

    while IFS= read -r rel; do
        scan_root="$(_stow_orphan_scan_root "$rel")" || continue
        target_roots["$scan_root"]=1
    done < <(stow_package_managed_files "$package")

    for prefix in "${!target_roots[@]}"; do
        target_root="${STOW_HOME}/${prefix}"
        [[ -d "$target_root" ]] || continue
        while IFS= read -r -d '' target; do
            link_value="$(readlink -- "$target" 2>/dev/null || true)"
            [[ -n "$link_value" ]] || continue
            if [[ "$link_value" == /* ]]; then
                resolved="$(realpath -m -- "$link_value")"
            else
                resolved="$(realpath -m -- "$(dirname -- "$target")/${link_value}")"
            fi
            case "$resolved" in
                "$source_dir"/*)
                    rel="${resolved#${source_dir}/}"
                    if [[ ! -e "${source_dir}/${rel}" && ! -L "${source_dir}/${rel}" ]]; then
                        printf '%s\n' "${target#${STOW_HOME}/}"
                    fi
                    ;;
            esac
        done < <(find "$target_root" -type l -print0 2>/dev/null)
    done
}

# Remove only dangling target symlinks that are still verified to resolve inside
# the selected package and whose corresponding source path is absent. The target
# root is the trusted user's Stow home; this intentionally does not claim safety
# against a concurrent same-user pathname replacement race (GNU Stow has the same
# local-user trust boundary).
stow_remove_orphaned_links() {
    local package="$1"
    local source_dir rel target link_value resolved source_rel
    local orphaned_links=()

    source_dir="${STOW_ROOT}/${package}"
    mapfile -t orphaned_links < <(stow_package_orphaned_links "$package")
    for rel in "${orphaned_links[@]}"; do
        target="${STOW_HOME}/${rel}"
        if [[ ! -L "$target" ]]; then
            printf '%s orphan target changed before cleanup: %s\n' "$STATUS_BLOCKED" "$target" >&2
            return "$EXIT_BLOCKED"
        fi
        link_value="$(readlink -- "$target" 2>/dev/null || true)"
        [[ -n "$link_value" ]] || {
            printf '%s cannot read orphan target: %s\n' "$STATUS_BLOCKED" "$target" >&2
            return "$EXIT_BLOCKED"
        }
        if [[ "$link_value" == /* ]]; then
            resolved="$(realpath -m -- "$link_value")"
        else
            resolved="$(realpath -m -- "$(dirname -- "$target")/${link_value}")"
        fi
        case "$resolved" in
            "$source_dir"/*)
                source_rel="${resolved#${source_dir}/}"
                if [[ -e "${source_dir}/${source_rel}" || -L "${source_dir}/${source_rel}" ]]; then
                    printf '%s orphan source reappeared before cleanup: %s\n' \
                        "$STATUS_BLOCKED" "${source_dir}/${source_rel}" >&2
                    return "$EXIT_BLOCKED"
                fi
                ;;
            *)
                printf '%s orphan target escaped selected package: %s\n' "$STATUS_BLOCKED" "$target" >&2
                return "$EXIT_BLOCKED"
                ;;
        esac
        rm -- "$target"
        printf '%s removed package-owned orphan link: %s\n' "$STATUS_CHANGED" "$rel"
    done
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
        stow_remove_orphaned_links "$package" || return $?
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
    local total=0 linked=0 missing=0 conflicts=0 orphaned=0
    local orphaned_links=()

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

    mapfile -t orphaned_links < <(stow_package_orphaned_links "$package")
    orphaned="${#orphaned_links[@]}"

    if (( total == 0 )); then
        printf '%s %s has no managed files\n' "$STATUS_BLOCKED" "$package"
        return "$EXIT_BLOCKED"
    fi
    if (( linked == total && orphaned == 0 )); then
        printf '%s %s (%d/%d linked)\n' "$STATUS_CURRENT" "$package" "$linked" "$total"
        return "$EXIT_OK"
    fi
    if (( linked == 0 && conflicts == 0 )); then
        printf '%s %s (0/%d linked)\n' "$STATUS_ABSENT" "$package" "$total"
        return "$EXIT_DRIFT"
    fi
    printf '%s %s (%d/%d linked, %d missing, %d conflicts, %d orphaned links)\n' \
        "$STATUS_DRIFT" "$package" "$linked" "$total" "$missing" "$conflicts" "$orphaned"
    return "$EXIT_DRIFT"
}
