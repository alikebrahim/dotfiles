#!/usr/bin/env bash
# Declarative catalog of directories that are intentionally managed by GNU Stow.
# Top-level repository directories are never inferred as packages.

declare -A STOW_CATALOG_LABEL STOW_CATALOG_DESC STOW_CATALOG_CATEGORY
STOW_CATALOG_IDS=()
STOW_CATALOG_ROOT=""

stow_catalog_register() {
    local id="$1" label="$2" category="$3" description="$4"
    STOW_CATALOG_IDS+=("$id")
    STOW_CATALOG_LABEL["$id"]="$label"
    STOW_CATALOG_CATEGORY["$id"]="$category"
    STOW_CATALOG_DESC["$id"]="$description"
}

stow_catalog_init() {
    STOW_CATALOG_ROOT="$1"
}

stow_catalog_has() {
    [[ -v STOW_CATALOG_LABEL["$1"] && -d "${STOW_CATALOG_ROOT}/$1" ]]
}

stow_catalog_list() {
    local id
    for id in "${STOW_CATALOG_IDS[@]}"; do
        stow_catalog_has "$id" && printf '%s\n' "$id"
    done
    return "$EXIT_OK"
}

stow_catalog_register zsh "Zsh" shell "Interactive shell configuration"
stow_catalog_register bash "Bash" shell "Bash login and interactive configuration"
stow_catalog_register git "Git" development "Git defaults and aliases"
stow_catalog_register vim "Vim" editor "Classic Vim configuration"
stow_catalog_register nvim "Neovim" editor "LazyVim-based programming environment"
stow_catalog_register delta "Delta" development "Git diff viewer configuration"
stow_catalog_register my-bin "Personal commands" utilities "User-maintained command-line scripts"
stow_catalog_register bin "Legacy commands" utilities "Legacy user command scripts"
stow_catalog_register tmux-remote "Remote tmux" terminal "Shared remote tmux configuration"
stow_catalog_register tmux-remote-netmaster "Netmaster tmux" terminal "Netmaster tmux overlay"
stow_catalog_register tmux-remote-servalws "Servalws tmux" terminal "Servalws tmux overlay"
stow_catalog_register tmux-remote-minisforoum "Minisforoum tmux" terminal "Minisforoum tmux overlay"
stow_catalog_register tmux-remote-zotac-box "Zotac tmux" terminal "Zotac-box tmux overlay"
stow_catalog_register tmux-remote-macbook "MacBook tmux" terminal "MacBook tmux overlay"
stow_catalog_register tmux-remote-honor "Honor tmux" terminal "Honor phone tmux overlay"
stow_catalog_register apps "Desktop applications" desktop "Shared desktop application configuration"
stow_catalog_register 1Password "1Password" desktop "1Password desktop integration"
stow_catalog_register wezterm "WezTerm" terminal "WezTerm terminal configuration"
stow_catalog_register alacritty "Alacritty" terminal "Alacritty terminal configuration"
stow_catalog_register atuin "Atuin" shell "Shell history synchronization configuration"
stow_catalog_register awesome "AwesomeWM" desktop "Awesome window-manager configuration"
stow_catalog_register awesome_wm_scripts "AwesomeWM scripts" desktop "Helper scripts used by AwesomeWM"
stow_catalog_register awesomewm-bin "AwesomeWM commands" desktop "User commands used by AwesomeWM"
stow_catalog_register picom "Picom" desktop "X11 compositor configuration"
stow_catalog_register dunst "Dunst" desktop "Notification daemon configuration"
stow_catalog_register rofi "Rofi" desktop "Application launcher and control menus"
stow_catalog_register polybar "Polybar" desktop "Status-bar configuration"
stow_catalog_register quickshell "Quickshell" desktop "Quickshell desktop-shell configuration"
stow_catalog_register posting "Posting" development "API client configuration"
stow_catalog_register postman "Postman" development "Postman desktop integration"
stow_catalog_register alikebrahim_zotac-box "Alikebrahim Zotac overlay" host "User-specific Zotac configuration"
stow_catalog_register tima_zotac-box "Tima Zotac overlay" host "User-specific Zotac configuration"
