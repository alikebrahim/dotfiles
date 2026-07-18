#!/usr/bin/env bash
# Declarative tool/utility registry with detection, named sets, and
# OS-native package installation. Supports manual hints for tools not
# in native package repositories.

# shellcheck source=scripts/lib/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

# Parallel associative arrays keyed by tool name.
declare -A TOOL_DESC TOOL_CATEGORY TOOL_FEDORA_PKG TOOL_UBUNTU_PKG
declare -A TOOL_DETECT TOOL_MANUAL_HINT
declare -A TOOL_SETS

TOOLS_REGISTERED=()

tool_register() {
    local name="$1"
    shift

    TOOL_DESC["$name"]=""
    TOOL_CATEGORY["$name"]=""
    TOOL_FEDORA_PKG["$name"]=""
    TOOL_UBUNTU_PKG["$name"]=""
    TOOL_DETECT["$name"]="command:$name"
    TOOL_MANUAL_HINT["$name"]=""

    while (( $# > 0 )); do
        case "$1" in
            --desc)    TOOL_DESC["$name"]="$2"; shift 2 ;;
            --category) TOOL_CATEGORY["$name"]="$2"; shift 2 ;;
            --fedora)  TOOL_FEDORA_PKG["$name"]="$2"; shift 2 ;;
            --ubuntu)  TOOL_UBUNTU_PKG["$name"]="$2"; shift 2 ;;
            --detect)  TOOL_DETECT["$name"]="$2"; shift 2 ;;
            --manual-hint) TOOL_MANUAL_HINT["$name"]="$2"; shift 2 ;;
            *) shift ;;
        esac
    done

    TOOLS_REGISTERED+=("$name")
}

tool_define_set() {
    local set_name="$1"
    shift
    TOOL_SETS["$set_name"]="$*"
}

# Check if a tool is installed.
# Returns 0 if installed, 1 if absent.
tool_is_installed() {
    local name="$1"
    local detect="${TOOL_DETECT[$name]}"
    local method="${detect%%:*}"
    local target="${detect#*:}"

    case "$method" in
        command)
            command -v "$target" >/dev/null 2>&1
            ;;
        command-any)
            local candidate
            local candidates=()
            IFS=',' read -r -a candidates <<< "$target"
            for candidate in "${candidates[@]}"; do
                command -v "$candidate" >/dev/null 2>&1 && return 0
            done
            return 1
            ;;
        path)
            [[ -x "$target" ]]
            ;;
        *)
            command -v "$name" >/dev/null 2>&1
            ;;
    esac
}

# Get the OS-native package name for a tool.
# Prints the package name, or empty if not available natively.
tool_package_name() {
    local name="$1"
    local os_id="$2"

    case "$os_id" in
        fedora) printf '%s' "${TOOL_FEDORA_PKG[$name]}" ;;
        ubuntu) printf '%s' "${TOOL_UBUNTU_PKG[$name]}" ;;
        *)      printf '%s' "${TOOL_FEDORA_PKG[$name]:-${TOOL_UBUNTU_PKG[$name]}}" ;;
    esac
}

# Check status of all registered tools. Prints tab-separated table.
# Columns: Tool, Status, Fedora Pkg, Category, Description
tools_check_all() {
    local os_id="${1:-fedora}"
    local tool
    local status

    printf 'Tool\tStatus\tPackage (%s)\tCategory\tDescription\n' "$os_id"
    printf '────────\t────────\t───────────\t────────\t───────────\n'

    for tool in "${TOOLS_REGISTERED[@]}"; do
        if tool_is_installed "$tool"; then
            status="$STATUS_CURRENT"
        else
            status="$STATUS_ABSENT"
        fi
        printf '%s\t%s\t%s\t%s\t%s\n' \
            "$tool" "$status" \
            "$(tool_package_name "$tool" "$os_id")" \
            "${TOOL_CATEGORY[$tool]}" \
            "${TOOL_DESC[$tool]}"
    done
}

# Check only tools in a profile's expected set.
# $1 = comma-separated or space-separated tool list
tools_check_profile() {
    local tools_str="$1"
    local tool
    local status

    printf 'Tool\tStatus\tDescription\n'
    printf '────────\t────────\t───────────\n'

    for tool in $tools_str; do
        [[ -v TOOL_DESC["$tool"] ]] || {
            printf '%s\t%s\t%s\n' "$tool" "$STATUS_BLOCKED" "unknown tool"
            continue
        }
        if tool_is_installed "$tool"; then
            status="$STATUS_CURRENT"
        else
            status="$STATUS_ABSENT"
        fi
        printf '%s\t%s\t%s\n' "$tool" "$status" "${TOOL_DESC[$tool]}"
    done
}

# Return list of missing tools from a profile set.
# $1 = space-separated tool list
# Prints one missing tool per line.
tools_missing_from() {
    local tools_str="$1"
    local tool

    for tool in $tools_str; do
        [[ -v TOOL_DESC["$tool"] ]] || continue
        tool_is_installed "$tool" || printf '%s\n' "$tool"
    done
}

# Return all missing tools from all registered tools.
tools_all_missing() {
    local tool
    for tool in "${TOOLS_REGISTERED[@]}"; do
        tool_is_installed "$tool" || printf '%s\n' "$tool"
    done
}

# Build gum-compatible choice list for absent tools.
# $1 = array name to populate (by reference via nameref-like eval)
tools_build_absent_choices() {
    local _out_var="$1"
    local tool

    eval "$_out_var=()"
    for tool in "${TOOLS_REGISTERED[@]}"; do
        if ! tool_is_installed "$tool"; then
            eval "$_out_var+=(\"\$tool  —  \${TOOL_DESC[\$tool]}\")"
        fi
    done
}

# Install a list of tools using OS-native packages.
# $1 = OS ID, $2 = comma/newline/space-separated tool list
tools_install() {
    local os_id="$1"
    local tools_str="$2"
    local tool
    local packages=()
    local manual_tools=()
    local pkg

    for tool in $tools_str; do
        [[ -v TOOL_DESC["$tool"] ]] || {
            printf '%s unknown tool: %s\n' "$STATUS_BLOCKED" "$tool" >&2
            continue
        }
        pkg="$(tool_package_name "$tool" "$os_id")"
        if [[ -n "$pkg" ]]; then
            packages+=("$pkg")
        else
            manual_tools+=("$tool")
        fi
    done

    # Report manual-hint tools
    for tool in "${manual_tools[@]}"; do
        printf '%s %s: no native package on %s\n' "$STATUS_BLOCKED" "$tool" "$os_id"
        if [[ -n "${TOOL_MANUAL_HINT[$tool]}" ]]; then
            printf '  Manual install: %s\n' "${TOOL_MANUAL_HINT[$tool]}"
        fi
    done

    if (( ${#packages[@]} > 0 )); then
        case "$os_id" in
            fedora)
                run_as_root dnf install -y "${packages[@]}"
                ;;
            ubuntu)
                run_as_root apt-get update
                run_as_root apt-get install -y "${packages[@]}"
                ;;
            *)
                printf '%s tool install supports Fedora and Ubuntu only (got: %s)\n' \
                    "$STATUS_BLOCKED" "$os_id" >&2
                return "$EXIT_BLOCKED"
                ;;
        esac
    fi

    # Re-check and report
    for tool in $tools_str; do
        if tool_is_installed "$tool"; then
            printf '%s %s [tool]\n' "$STATUS_CHANGED" "$tool"
        else
            printf '%s %s [tool]\n' "$STATUS_ABSENT" "$tool"
        fi
    done
}

# Resolve a named tool set to a space-separated tool list.
tools_set_members() {
    local set_name="$1"
    printf '%s' "${TOOL_SETS[$set_name]:-}"
}

# List all defined tool sets with their members.
tools_list_sets() {
    local set_name
    for set_name in "${!TOOL_SETS[@]}"; do
        printf '%s\t%s\n' "$set_name" "${TOOL_SETS[$set_name]}"
    done | sort
}

# ─── Default registry ───────────────────────────────────────────

tool_register zsh \
    --desc "Zsh: interactive shell" \
    --category shell \
    --fedora zsh --ubuntu zsh \
    --detect command:zsh

tool_register tmux \
    --desc "Tmux: terminal multiplexer" \
    --category system \
    --fedora tmux --ubuntu tmux \
    --detect command:tmux

tool_register delta \
    --desc "Delta: beautiful git diffs" \
    --category git \
    --fedora git-delta --ubuntu git-delta \
    --detect command:delta

tool_register rg \
    --desc "Ripgrep: fast recursive search" \
    --category search \
    --fedora ripgrep --ubuntu ripgrep \
    --detect command:rg

tool_register fd \
    --desc "fd-find: fast find alternative" \
    --category search \
    --fedora fd-find --ubuntu fd-find \
    --detect command-any:fd,fdfind

tool_register zoxide \
    --desc "Zoxide: smarter cd" \
    --category navigation \
    --fedora zoxide --ubuntu zoxide \
    --detect command:zoxide

tool_register fzf \
    --desc "Fzf: fuzzy finder" \
    --category navigation \
    --fedora fzf --ubuntu fzf \
    --detect command:fzf

tool_register lazygit \
    --desc "Lazygit: TUI for git" \
    --category git \
    --fedora lazygit --ubuntu lazygit \
    --detect command:lazygit

tool_register yazi \
    --desc "Yazi: terminal file manager" \
    --category navigation \
    --fedora yazi --ubuntu "" \
    --detect command:yazi \
    --manual-hint "cargo install --locked yazi-fm yazi-cli"

tool_register awesome \
    --desc "AwesomeWM: tiling window manager" \
    --category wm \
    --fedora awesome --ubuntu awesome \
    --detect command:awesome

# Tool sets
tool_define_set minimal       "zsh tmux delta"
tool_define_set developer    "zsh tmux delta rg fd zoxide fzf lazygit"
tool_define_set desktop      "zsh tmux delta rg fd zoxide fzf lazygit awesome"
tool_define_set desktop-full "zsh tmux delta rg fd zoxide fzf lazygit awesome yazi"
