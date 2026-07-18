import QtQuick
import Quickshell
import "../../services"

// Bar.qml — top bar (Polybar replacement), primary-monitor-only per
// decisions.md §6 ("B. Bar on primary monitor only").
//
// PanelWindow is the root element here (matching DankMaterialShell's
// DankBarWindow.qml pattern) — Quickshell panel/window types are meant
// to be the top-level component of their own file, not nested inside a
// plain Item.
//
// Single PanelWindow bound to one target screen — not a
// Variants{model:Quickshell.screens} fan-out, since only one monitor
// gets a bar per the decision above. (Variants is still the documented
// pattern for the "bar on both monitors" / "reduced secondary set"
// options if that decision changes later — this file would wrap itself
// in a Variants block at that point instead.)
//
// `anchors`/`exclusiveZone` usage matches the exact pattern already
// confirmed live on this machine in quickshell-research.md §1's
// throwaway test bar (real strut reservation confirmed via
// awesome-client/xprop/xwininfo).
//
// Primary-screen selection: Quickshell's X11 backend does not expose a
// `Quickshell.primaryScreen` property (confirmed absent from the
// installed 0.3.0 build's type info — see OSD.qml's identical note).
// Matches by output name directly using "HDMI-1-0" — the primary output
// confirmed live via `xrandr --query` in findings.md — with a safe
// fallback to the first available screen if that name isn't present
// (single-monitor session, docking-station rename, etc.).
PanelWindow {
    id: barWindow

    readonly property string primaryOutputName: "HDMI-1-0"
    readonly property var targetScreen: {
        const list = Quickshell.screens;
        for (let i = 0; i < list.length; i++) {
            if (list[i].name === barWindow.primaryOutputName)
                return list[i];
        }
        return list.length > 0 ? list[0] : null;
    }

    screen: targetScreen

    anchors {
        top: true
        left: true
        right: true
    }

    implicitHeight: 30
    exclusiveZone: 30
    color: "transparent"

    Rectangle {
        anchors.fill: parent
        color: Theme.colors.background

        Row {
            id: leftSection
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: Theme.spacing
            spacing: Theme.spacing

            TagIndicator {}
        }

        FocusedTitle {
            anchors.centerIn: parent
        }

        Row {
            id: rightSection
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.rightMargin: Theme.spacing
            spacing: Theme.spacing

            ClockLabel {}
        }
    }
}
