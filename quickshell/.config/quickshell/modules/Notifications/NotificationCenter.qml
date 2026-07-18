import QtQuick
import Quickshell
import Quickshell.Io
import "../../services"

// NotificationCenter.qml — browsable notification history (Mod+N).
//
// decisions.md §9: flat chronological list (grouping option A), j/k
// move between stacked notifications, x/d dismiss the focused one,
// Enter triggers default action if present, c clears all, Esc closes.
// No DND control ("No need for DND" per that section's explicit answer).
//
// IpcHandler target "notificationCenter" so AwesomeWM's Mod+N keybind
// can toggle this later (deferred to the integration phase, per the
// user's instruction — not wired into keys.lua in this pass).
Item {
    id: root

    property bool panelVisible: false
    property int focusedIndex: 0

    function toggle() {
        root.panelVisible = !root.panelVisible;
        if (root.panelVisible)
            root.focusedIndex = 0;
    }

    function show() {
        root.panelVisible = true;
        root.focusedIndex = 0;
    }

    function hide() {
        root.panelVisible = false;
    }

    IpcHandler {
        target: "notificationCenter"

        function toggle(): string {
            root.toggle();
            return "ok";
        }

        function show(): string {
            root.show();
            return "ok";
        }

        function hide(): string {
            root.hide();
            return "ok";
        }
    }

    PanelWindow {
        id: centerWindow

        // PanelWindow, not plain Window — see OSD.qml: plain Window{}
        // never maps to a real X11 window in Quickshell 0.3.0 (confirmed
        // in the 2026-07-06 Xvfb smoke test). Anchored top+right for
        // the notification-center position (top-right corner, matching
        // decisions.md §9's placement choice).
        visible: root.panelVisible
        anchors.top: true
        anchors.right: true
        margins.top: 40
        margins.right: 20
        implicitWidth: 400
        implicitHeight: 520
        exclusiveZone: 0
        aboveWindows: true
        focusable: true
        color: "transparent"

        Rectangle {
            anchors.fill: parent
            radius: Theme.radius
            color: Theme.colors.background
            border.color: Theme.colors.surface
            border.width: 1

            focus: root.panelVisible

            Keys.onPressed: function (event) {
                const count = Notifications.history.length;
                if (event.key === Qt.Key_Escape) {
                    root.hide();
                    event.accepted = true;
                } else if ((event.key === Qt.Key_J || event.key === Qt.Key_Down) && count > 0) {
                    root.focusedIndex = Math.min(root.focusedIndex + 1, count - 1);
                    event.accepted = true;
                } else if ((event.key === Qt.Key_K || event.key === Qt.Key_Up) && count > 0) {
                    root.focusedIndex = Math.max(root.focusedIndex - 1, 0);
                    event.accepted = true;
                } else if ((event.key === Qt.Key_X || event.key === Qt.Key_D) && count > 0) {
                    Notifications.dismiss(Notifications.history[root.focusedIndex].id);
                    root.focusedIndex = Math.max(0, Math.min(root.focusedIndex, Notifications.history.length - 1));
                    event.accepted = true;
                } else if (event.key === Qt.Key_C) {
                    Notifications.clearAll();
                    root.focusedIndex = 0;
                    event.accepted = true;
                }
            }

            Column {
                anchors.fill: parent
                anchors.margins: Theme.spacing

                Text {
                    text: "Notifications"
                    color: Theme.colors.foreground
                    font.family: Theme.fontFamily
                    font.pixelSize: 15
                    font.bold: true
                }

                Text {
                    visible: Notifications.history.length === 0
                    text: "No notifications"
                    color: Theme.colors.muted
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                    topPadding: 12
                }

                ListView {
                    width: parent.width
                    height: parent.height - 40
                    clip: true
                    model: Notifications.history
                    currentIndex: root.focusedIndex
                    spacing: 6
                    topMargin: 8

                    delegate: Rectangle {
                        width: ListView.view.width
                        height: 60
                        radius: Theme.radius * 0.5
                        color: index === root.focusedIndex ? Theme.colors.surface : "transparent"
                        border.color: index === root.focusedIndex ? Theme.colors.accent : "transparent"
                        border.width: 1

                        Column {
                            anchors.fill: parent
                            anchors.margins: 8
                            spacing: 2

                            Text {
                                text: modelData.summary
                                color: Theme.colors.foreground
                                font.family: Theme.fontFamily
                                font.pixelSize: 12
                                font.bold: true
                                elide: Text.ElideRight
                                width: parent.width
                            }

                            Text {
                                text: modelData.body
                                color: Theme.colors.muted
                                font.family: Theme.fontFamily
                                font.pixelSize: 10
                                elide: Text.ElideRight
                                width: parent.width
                            }

                            Text {
                                text: modelData.appName
                                color: Theme.colors.info
                                font.family: Theme.fontFamily
                                font.pixelSize: 9
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: root.focusedIndex = index
                        }
                    }
                }
            }
        }
    }
}
