#!/usr/bin/env bash

module_xorg_libinput_metadata() {
    case "$1" in
        label) printf 'Natural scrolling\n' ;;
        description) printf 'Install the Xorg libinput policy for natural pointer scrolling.\n' ;;
        privilege) printf 'root\n' ;;
        risk) printf 'low\n' ;;
        impact) printf 'Takes effect for new X11 sessions; no service restart.\n' ;;
    esac
}

module_xorg_libinput() {
    local action="$1"
    module_manage_file \
        "$action" \
        "system:xorg-libinput" \
        "${MODULE_ROOT}/scripts/system/xorg-libinput/40-libinput-natural-scrolling.conf" \
        "/etc/X11/xorg.conf.d/40-libinput-natural-scrolling.conf" \
        0644
}
