#!/usr/bin/env bash
# TTY-only Gum rendering. Command and automation modes stay plain text.
# Session loop: persistent main menu with sub-menus, pagers, and spinners.

# shellcheck source=scripts/lib/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

UI_ROOT=""
UI_THEME="orange-gas-plasma"
UI_BG="#262626"
UI_FG="#FFCB83"
UI_ACTIVE="#FC531D"
UI_METRIC="#FFBE55"
UI_ALERT="#FF8C68"
UI_MUTED="#6A4F2A"
UI_DISABLED=false
UI_COLOR_ENABLED=true

SESSION_TMPDIR=""

# ─── Theme management ──────────────────────────────────────────

ui_auto_theme() {
    local theme_config="${HOME}/.tmux/theme.conf"
    local selected

    if [[ -r "$theme_config" ]]; then
        selected="$(sed -nE 's|.*themes/([A-Za-z0-9_-]+)\.conf.*|\1|p' "$theme_config" | head -1)"
        if [[ -n "$selected" ]]; then
            printf '%s\n' "$selected"
            return
        fi
    fi
    printf 'orange-gas-plasma\n'
}

ui_init() {
    local root="$1"
    local requested_theme="${2:-auto}"
    local theme_file

    UI_ROOT="$root"
    if [[ "$requested_theme" == auto ]]; then
        requested_theme="$(ui_auto_theme)"
    fi

    theme_file="${UI_ROOT}/scripts/ui-themes/${requested_theme}.sh"
    if [[ ! -r "$theme_file" ]]; then
        theme_file="${UI_ROOT}/scripts/ui-themes/orange-gas-plasma.sh"
        requested_theme="orange-gas-plasma"
    fi

    # Theme files are repository-controlled variable declarations.
    # shellcheck disable=SC1090
    source "$theme_file"
    UI_THEME="$requested_theme"
    [[ -z "${NO_COLOR:-}" ]] && UI_COLOR_ENABLED=true || UI_COLOR_ENABLED=false
}

ui_has_tty() {
    [[ -t 0 && -t 1 ]]
}

ui_colors_enabled() {
    [[ "$UI_COLOR_ENABLED" == true && -z "${NO_COLOR:-}" ]]
}

ui_should_use_gum() {
    [[ "$UI_DISABLED" != true ]] || return 1
    ui_has_tty || return 1
    command -v gum >/dev/null 2>&1
}

ui_content_width() {
    local columns="${COLUMNS:-}"
    [[ "$columns" =~ ^[0-9]+$ ]] || columns="$(tput cols 2>/dev/null || printf '80')"
    (( columns > 76 )) && columns=76
    (( columns < 24 )) && columns=24
    printf '%d\n' "$((columns - 4))"
}

ui_list_height() {
    local requested="${1:-10}" lines="${LINES:-}" available
    [[ "$lines" =~ ^[0-9]+$ ]] || lines="$(tput lines 2>/dev/null || printf '24')"
    available=$((lines - 8))
    (( available < 5 )) && available=5
    (( available > 18 )) && available=18
    (( requested < available )) && available="$requested"
    printf '%d\n' "$available"
}

ui_pager_backend() {
    if command -v less >/dev/null 2>&1; then
        printf 'less\n'
    elif command -v gum >/dev/null 2>&1; then
        printf 'gum\n'
    else
        printf 'plain\n'
    fi
}

ui_clear() {
    ui_has_tty || return 0
    tput clear 2>/dev/null || printf '\033[2J\033[H'
}

# ─── Session lifecycle ─────────────────────────────────────────

ui_session_init() {
    SESSION_TMPDIR=$(mktemp -d)
    trap ui_session_cleanup EXIT
}

ui_session_cleanup() {
    [[ -n "$SESSION_TMPDIR" ]] && rm -rf "$SESSION_TMPDIR"
    SESSION_TMPDIR=""
}

# ─── Primitives ────────────────────────────────────────────────

ui_header() {
    local title="$1"
    local subtitle="${2:-}"
    local width
    width="$(ui_content_width)"

    if ui_should_use_gum; then
        if ui_colors_enabled; then
            gum style --border double --border-foreground "$UI_ACTIVE" --foreground "$UI_FG" \
                --align center --width "$width" --padding "0 1" --bold "$title" >&2
            [[ -n "$subtitle" ]] && gum style --foreground "$UI_MUTED" \
                --align center --width "$width" "$subtitle" >&2
        else
            gum style --border double --align center --width "$width" \
                --padding "0 1" --bold "$title" >&2
            [[ -n "$subtitle" ]] && gum style --align center --width "$width" "$subtitle" >&2
        fi
    else
        printf '== %s ==\n' "$title" >&2
        [[ -n "$subtitle" ]] && printf '%s\n' "$subtitle" >&2
    fi
}

ui_section() {
    local title="$1"
    local hint="${2:-Esc to go back}"

    if ui_should_use_gum; then
        if ui_colors_enabled; then
            gum style --foreground "$UI_METRIC" --bold --margin "1 0 0 0" "// ${title}" >&2
            [[ -n "$hint" ]] && gum style --foreground "$UI_MUTED" --margin "0 0" "$hint" >&2
        else
            gum style --bold --margin "1 0 0 0" "// ${title}" >&2
            [[ -n "$hint" ]] && gum style --margin "0 0" "$hint" >&2
        fi
    else
        printf '\n// %s\n' "$title" >&2
        [[ -n "$hint" ]] && printf '%s\n' "$hint" >&2
    fi
}

ui_footer() {
    local text="$1"

    if ui_should_use_gum; then
        if ui_colors_enabled; then
            gum style --foreground "$UI_MUTED" --margin "0 0" "$text" >&2
        else
            gum style --margin "0 0" "$text" >&2
        fi
    else
        printf '%s\n' "$text" >&2
    fi
}

ui_choose() {
    local header="$1"
    shift
    local height
    height="$(ui_list_height "$#")"

    if ui_colors_enabled; then
        gum choose --show-help --header "$header" --height "$height" --cursor "› " --cursor-prefix "" \
            --header.foreground "$UI_METRIC" --cursor.foreground "$UI_ACTIVE" \
            --item.foreground "$UI_FG" --selected.foreground "$UI_ACTIVE" "$@"
    else
        gum choose --show-help --header "$header" --height "$height" \
            --cursor "› " --cursor-prefix "" "$@"
    fi
}

ui_choose_multi() {
    local header="$1"
    shift
    local height
    height="$(ui_list_height "$#")"

    if ui_colors_enabled; then
        gum choose --show-help --ordered --no-limit --header "$header" --height "$height" --cursor "› " \
            --cursor-prefix "" --selected-prefix "[x] " --unselected-prefix "[ ] " \
            --header.foreground "$UI_METRIC" --cursor.foreground "$UI_ACTIVE" \
            --item.foreground "$UI_FG" --selected.foreground "$UI_ACTIVE" "$@"
    else
        gum choose --show-help --ordered --no-limit --header "$header" --height "$height" --cursor "› " \
            --cursor-prefix "" --selected-prefix "[x] " --unselected-prefix "[ ] " "$@"
    fi
}

ui_choose_multi_preselected() {
    local header="$1" selected_name="$2" options_name="$3"
    local -n selected_ref="$selected_name"
    local -n options_ref="$options_name"
    local height option
    local selected_args=()
    height="$(ui_list_height "${#options_ref[@]}")"
    for option in "${selected_ref[@]}"; do
        selected_args+=(--selected "$option")
    done

    if ui_colors_enabled; then
        gum choose --show-help --ordered --no-limit --header "$header" --height "$height" \
            --cursor "› " --cursor-prefix "" --selected-prefix "[x] " --unselected-prefix "[ ] " \
            --header.foreground "$UI_METRIC" --cursor.foreground "$UI_ACTIVE" \
            --item.foreground "$UI_FG" --selected.foreground "$UI_ACTIVE" \
            "${selected_args[@]}" "${options_ref[@]}"
    else
        gum choose --show-help --ordered --no-limit --header "$header" --height "$height" \
            --cursor "› " --cursor-prefix "" --selected-prefix "[x] " --unselected-prefix "[ ] " \
            "${selected_args[@]}" "${options_ref[@]}"
    fi
}

ui_confirm() {
    local prompt="$1"
    local affirmative="${2:-Yes}"
    local negative="${3:-Cancel}"

    if ui_should_use_gum; then
        if ui_colors_enabled; then
            gum confirm --show-help --affirmative "$affirmative" --negative "$negative" \
                --prompt.foreground "$UI_FG" --selected.foreground "$UI_BG" \
                --selected.background "$UI_ACTIVE" --unselected.foreground "$UI_FG" \
                --unselected.background "$UI_MUTED" "$prompt"
        else
            gum confirm --show-help --affirmative "$affirmative" --negative "$negative" "$prompt"
        fi
        return
    fi

    local answer
    read -r -p "${prompt} [y/N] " answer
    [[ "$answer" =~ ^[Yy]$ ]]
}

ui_spin() {
    local title="$1"
    shift

    if ui_should_use_gum; then
        gum spin --spinner dot --title "$title" -- "$@"
    else
        printf '%s\n' "$title" >&2
        "$@"
    fi
}

ui_wait_for_pid() {
    local title="$1" pid="$2"
    if ui_should_use_gum; then
        gum spin --spinner dot --title "$title" -- \
            bash -c 'while kill -0 "$1" 2>/dev/null; do sleep 0.1; done' _ "$pid"
    else
        printf '%s\n' "$title" >&2
        while kill -0 "$pid" 2>/dev/null; do sleep 0.1; done
    fi
}

# Show content in a pager with man-page + nvim-style keybinds.
# Uses gum pager in interactive mode; plain cat for fallback.
# $1 = title (printed as a header line above content), $2 = file path
ui_pager() {
    local title="$1"
    local source="$2"
    local file=""

    if [[ -f "$source" ]]; then
        file="$source"
    else
        file="${SESSION_TMPDIR}/pager-content.txt"
        printf '%s\n' "$source" > "$file"
    fi

    if ui_should_use_gum; then
        local backend width
        backend="$(ui_pager_backend)"
        width="$(ui_content_width)"
        local display_file="${SESSION_TMPDIR}/pager-display.txt"
        local header_file="${SESSION_TMPDIR}/pager-header.txt"
        if ui_colors_enabled; then
            gum style --border double --border-foreground "$UI_ACTIVE" \
                --foreground "$UI_FG" --align center --width "$width" --padding "0 1" \
                --bold "$title" > "$header_file" 2>&1
        else
            gum style --border double --align center --width "$width" --padding "0 1" \
                --bold "$title" > "$header_file" 2>&1
        fi
        {
            cat "$header_file"
            if [[ "$backend" == less ]]; then
                printf 'j/k or arrows: scroll  PgUp/PgDn: page  /: search  g/G: ends  q: back\n\n'
            else
                printf 'arrows: scroll  /: search  Esc: back\n\n'
            fi
            cat "$file"
        } > "$display_file"
        case "$backend" in
            less) LESS='-R -X -M' less "$display_file" ;;
            gum) gum pager < "$display_file" ;;
            *) cat "$display_file" ;;
        esac
    else
        printf '══ %s ══\n' "$title"
        cat "$file"
    fi
}

# Run a command, capture output to temp file, then show in pager.
# $1 = title, $2.. = command and args
ui_run_to_pager() {
    local title="$1"
    shift
    local outfile="${SESSION_TMPDIR}/run-output.txt"

    "$@" > "$outfile" 2>&1 || true
    ui_pager "$title" "$outfile"
}

# ─── Menu builders ─────────────────────────────────────────────

ui_main_menu_items() {
    printf '%s\n' \
        "Inspect current state" \
        "Preview deployment" \
        "Apply host profile" \
        "Manage Stow packages" \
        "Manage tools" \
        "Bootstrap prerequisites" \
        "Update tmux plugins" \
        "Quit"
}

ui_main_menu_footer() {
    local profile="$1"
    local os="$2"
    local theme="$3"
    printf 'Profile: %s  |  OS: %s  |  Theme: %s' "$profile" "$os" "$theme"
}

ui_tools_menu_items() {
    printf '%s\n' \
        "Check installed tools" \
        "Install missing (profile default)" \
        "Select tools to install" \
        "Install a named set" \
        "Return to main menu"
}

ui_stow_menu_items() {
    printf '%s\n' \
        "Check Stow package status" \
        "Stow selected packages" \
        "Select Stow packages to install" \
        "Return to main menu"
}
