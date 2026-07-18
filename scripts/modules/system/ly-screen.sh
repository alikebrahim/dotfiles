#!/usr/bin/env bash

module_ly_screen_metadata() {
    case "$1" in
        label) printf 'Ly login-screen theme\n' ;;
        description) printf 'Install the managed Ly configuration, startup palette, and animation.\n' ;;
        privilege) printf 'root\n' ;;
        risk) printf 'medium\n' ;;
        impact) printf 'Visible on the next Ly login screen; does not restart the display manager.\n' ;;
    esac
}

module_ly_screen() {
    local action="$1"
    local source_root="${MODULE_ROOT}/scripts/system/ly"
    local rc=0

    module_manage_file "$action" "system:ly-screen" \
        "${source_root}/config.ini" "/etc/ly/config.ini" 0644 || rc=$?
    module_manage_file "$action" "system:ly-screen" \
        "${source_root}/startup.sh" "/etc/ly/startup.sh" 0755 || rc=$?
    module_manage_file "$action" "system:ly-screen" \
        "${source_root}/animations/cosmic-gravity-monitor-16c-240x67.dur" \
        "/etc/ly/animations/cosmic-gravity-monitor-16c-240x67.dur" 0644 || rc=$?

    return "$rc"
}
