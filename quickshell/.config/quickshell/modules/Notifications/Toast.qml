import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import "../../services"

// Toast.qml — transient notification popup.
//
// decisions.md §9: top-right corner, matches Dunst's current position
// (origin=top-right, offset=(10,40)). Reads Notifications.toastRequested
// (services/Notifications.qml) — one popup window per incoming
// notification, auto-hides after a few seconds. Multiple toasts stack
// vertically, newest at top, oldest pushed down — closest equivalent to
// Dunst's default stacking behavior without needing a queue manager.
//
// Uses Instantiator, not Repeater: Window is not an Item-derived type,
// and Repeater is documented/optimized specifically for Item delegates.
// Instantiator is the Qt Quick type designed for creating/destroying
// non-Item objects (including Window instances) dynamically from a
// model.
Item {
    id: root

    // Each entry: {entry: <notification data>, instanceId: <unique id>}
    property var activeToasts: []
    property int nextInstanceId: 0

    Connections {
        target: Notifications

        function onToastRequested(entry) {
            const instanceId = root.nextInstanceId++;
            root.activeToasts = root.activeToasts.concat([{
                entry: entry,
                instanceId: instanceId
            }]);
        }
    }

    function removeToast(instanceId) {
        root.activeToasts = root.activeToasts.filter(t => t.instanceId !== instanceId);
    }

    Instantiator {
        model: root.activeToasts

        PanelWindow {
            id: toastWindow
            required property var modelData

            // PanelWindow, not plain Window — see OSD.qml: plain Window{}
            // never maps to a real X11 window in Quickshell 0.3.0.
            // Anchored top+right, matching dunstrc's origin=top-right
            // per decisions.md §9. Toast stacking is handled via
            // margins.top computed dynamically from the toast's
            // position in activeToasts.
            visible: true
            anchors.top: true
            anchors.right: true
            margins.right: 10
            margins.top: {
                let offset = 40;
                for (let i = 0; i < root.activeToasts.length; i++) {
                    if (root.activeToasts[i].instanceId === modelData.instanceId)
                        break;
                    offset += 84 + 8;
                }
                return offset;
            }
            implicitWidth: 340
            implicitHeight: 84
            exclusiveZone: 0
            aboveWindows: true
            focusable: false
            color: "transparent"

            Rectangle {
                anchors.fill: parent
                radius: Theme.radius * 0.6
                color: Theme.colors.background
                border.color: modelData.entry.urgency === NotificationUrgency.Critical ? Theme.colors.urgent : Theme.colors.accent
                border.width: 1

                Row {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 10

                    Rectangle {
                        width: 4
                        height: parent.height
                        radius: 2
                        color: modelData.entry.urgency === NotificationUrgency.Critical ? Theme.colors.urgent : Theme.colors.accent
                    }

                    Column {
                        width: parent.width - 14
                        spacing: 4

                        Text {
                            text: modelData.entry.summary
                            color: Theme.colors.foreground
                            font.family: Theme.fontFamily
                            font.pixelSize: 13
                            font.bold: true
                            elide: Text.ElideRight
                            width: parent.width
                        }

                        Text {
                            text: modelData.entry.body
                            color: Theme.colors.muted
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            wrapMode: Text.WordWrap
                            width: parent.width
                            maximumLineCount: 2
                            elide: Text.ElideRight
                        }

                        Text {
                            text: modelData.entry.appName
                            color: Theme.colors.info
                            font.family: Theme.fontFamily
                            font.pixelSize: 9
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: root.removeToast(modelData.instanceId)
                }
            }

            Timer {
                interval: 5000
                running: true
                repeat: false
                onTriggered: root.removeToast(modelData.instanceId)
            }
        }
    }
}
