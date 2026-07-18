//@ pragma Env QT_QPA_PLATFORM=xcb
//@ pragma Env QT_QUICK_CONTROLS_STYLE=Basic

// lock.qml — standalone Quickshell-native lock screen entry point.
//
// decisions.md §10: "build now" — theme-matched, centered password field
// + clock. Backend switch (i3lock vs. this) is decided by a thin wrapper
// script reading quickshell/.config/quickshell/lock-settings.json
// (option A, per ambiguities.md #6/#7), NOT by this file.
//
// CRITICAL: this is a SEPARATE Quickshell config/process, not part of
// shell.qml. A lock screen must not be one Loader/Item among many others
// in the main shell process — it needs to be launchable independently
// (`quickshell -p lock.qml`) so the wrapper script's dispatch logic
// (i3lock vs. qs) stays a simple process choice, and so a bug in the
// main bar/launcher/panel shell can never take the lock screen down with
// it. This file is intentionally NOT imported by
// quickshell/.config/quickshell/shell.qml.
//
// Per the user's explicit instruction, this module is built but NOT
// wired into the live xss-lock invocation
// (awesome_wm_scripts/.config/scripts/*) — that wiring is deferred to
// the authorized integration phase.

import QtQuick
import Quickshell
import "modules/LockScreen"

ShellRoot {
    id: shellRoot

    LockScreen {
        id: lockScreen
    }
}
