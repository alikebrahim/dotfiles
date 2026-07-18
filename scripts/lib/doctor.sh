#!/usr/bin/env bash
# Read-only host/repo health checks for configure-host.

doctor_syncthing_notes() {
    local root="${1:-${DOTFILES:-${STOW_ROOT:-}}}"
    if [[ -n "$root" && -d "${root}/.stfolder" ]]; then
        printf '%s Syncthing-managed repo detected (.stfolder). Verify sync is idle on all hosts before apply.\n' \
            "$STATUS_CURRENT"
    else
        printf '%s no .stfolder marker in repo (not flagged as Syncthing-managed here)\n' \
            "$STATUS_CURRENT"
    fi
    if command -v syncthing >/dev/null 2>&1; then
        printf '%s syncthing binary is present; still confirm folder completion manually.\n' \
            "$STATUS_CURRENT"
    fi
}

doctor_fold_status() {
    local home_root="${1:-${STOW_HOME:-$HOME}}"
    local path
    for path in \
        "$home_root/.local" \
        "$home_root/.local/state" \
        "$home_root/.local/share" \
        "$home_root/.tmux"; do
        if [[ -L "$path" ]]; then
            printf '%s tree-folded path (symlink): %s -> %s\n' \
                "$STATUS_BLOCKED" "$path" "$(readlink -- "$path" 2>/dev/null || true)"
        elif [[ -d "$path" ]]; then
            printf '%s real directory: %s\n' "$STATUS_CURRENT" "$path"
        else
            printf '%s missing safety directory: %s\n' "$STATUS_ABSENT" "$path"
        fi
    done
}

doctor_catalog_audit() {
    local root="${1:-${DOTFILES:-${STOW_ROOT:-${STOW_CATALOG_ROOT:-}}}}"
    local id entry name
    local missing_on_disk=0 unregistered=0 profile_bad=0
    local skip_names='scripts docs tests ssh revamp'

    [[ -n "$root" ]] || {
        printf '%s doctor_catalog_audit needs a repo root\n' "$STATUS_BLOCKED" >&2
        return "$EXIT_INTERNAL"
    }

    stow_catalog_init "$root"

    printf 'CATALOG vs DISK\n'
    for id in "${STOW_CATALOG_IDS[@]}"; do
        if [[ -d "${root}/${id}" ]]; then
            printf '%s catalog package present: %s\n' "$STATUS_CURRENT" "$id"
        else
            printf '%s catalog package missing from disk: %s\n' "$STATUS_DRIFT" "$id"
            ((missing_on_disk += 1))
        fi
    done

    printf '\nDISK vs CATALOG\n'
    for entry in "$root"/*/; do
        [[ -d "$entry" ]] || continue
        name="$(basename "$entry")"
        case " $skip_names " in
            *" $name "*) continue ;;
        esac
        if stow_catalog_has "$name"; then
            continue
        fi
        printf '%s package-like directory not in catalog: %s\n' "$STATUS_DRIFT" "$name"
        ((unregistered += 1))
    done
    if (( unregistered == 0 )); then
        printf '%s no unregistered package-like directories\n' "$STATUS_CURRENT"
    fi

    printf '\nPROFILE vs CATALOG\n'
    if (( ${#PROFILE_STOW_PACKAGES[@]} == 0 )); then
        printf '%s profile lists no Stow packages\n' "$STATUS_CURRENT"
    else
        for id in "${PROFILE_STOW_PACKAGES[@]}"; do
            if stow_catalog_has "$id"; then
                printf '%s profile package registered: %s\n' "$STATUS_CURRENT" "$id"
            else
                printf '%s profile package not in catalog or missing: %s\n' \
                    "$STATUS_DRIFT" "$id"
                ((profile_bad += 1))
            fi
        done
    fi

    printf '\nSUMMARY\n'
    printf 'missing_on_disk=%d unregistered=%d profile_mismatches=%d\n' \
        "$missing_on_disk" "$unregistered" "$profile_bad"
    if (( missing_on_disk + unregistered + profile_bad > 0 )); then
        return "$EXIT_DRIFT"
    fi
    return "$EXIT_OK"
}

doctor_tmux_plugins_status() {
    local plugins_dir="${STOW_HOME:-$HOME}/.tmux/plugins"
    local entry name dest
    local plugins=(
        tpm
        tmux-sensible
        tmux-resurrect
        tmux-continuum
        tmux-fzf
    )
    printf 'TMUX PLUGINS (not applied by configure-host apply; use update tmux-plugins)\n'
    for name in "${plugins[@]}"; do
        dest="${plugins_dir}/${name}"
        if [[ -d "${dest}/.git" ]]; then
            printf '%s %s\n' "$STATUS_CURRENT" "$name"
        elif [[ -e "$dest" ]]; then
            printf '%s %s exists but is not a git checkout\n' "$STATUS_BLOCKED" "$name"
        else
            printf '%s %s\n' "$STATUS_ABSENT" "$name"
        fi
    done
}

doctor_new_package_checklist() {
    cat <<'EOF'
NEW STOW PACKAGE CHECKLIST
1. Create package tree under the repo root (relative symlinks only).
2. Register the package in scripts/lib/stow-catalog.sh.
3. Add it to scripts/profiles/common.conf and/or host PROFILE_EXTRA_STOW_PACKAGES.
4. Add .stow-local-ignore for any host-local paths (plugins, state, share).
5. Ensure tree-fold safety: do not own exclusive wide trees like ~/.local without real safety dirs.
6. bash scripts/configure-host.sh doctor
7. bash scripts/configure-host.sh check --scope stow --stow-package NAME
8. bash scripts/configure-host.sh plan --scope stow --stow-package NAME
9. bash scripts/configure-host.sh apply --scope stow --stow-package NAME
10. Wait for Syncthing idle on all hosts before applying elsewhere.
EOF
}

doctor_run() {
    local root="${1:-${DOTFILES:-${STOW_ROOT:-}}}"
    local home_root="${2:-${STOW_HOME:-$HOME}}"
    local rc=0

    printf 'CONFIGURE-HOST DOCTOR\n'
    printf 'Repo: %s\nHome: %s\nProfile: %s\n\n' \
        "${root:-unknown}" "$home_root" "${PROFILE_NAME:-unknown}"

    printf 'SYNCTHING\n'
    doctor_syncthing_notes "$root"
    printf '\nTREE-FOLD SAFETY\n'
    doctor_fold_status "$home_root"
    if ! stow_safety_check 2>/dev/null; then
        rc="$EXIT_BLOCKED"
    fi
    printf '\n'
    doctor_catalog_audit "$root" || {
        local audit_rc=$?
        (( rc == 0 || rc == EXIT_DRIFT )) && rc="$audit_rc"
    }
    printf '\n'
    doctor_tmux_plugins_status
    printf '\n'
    doctor_new_package_checklist
    return "$rc"
}
