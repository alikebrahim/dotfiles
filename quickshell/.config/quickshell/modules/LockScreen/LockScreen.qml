import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pam
import "../../services"

// LockScreen.qml — Quickshell-native lock screen content.
//
// decisions.md §10: theme-matched background/accent colors, simple
// centered password field + clock. Loaded only by the standalone
// lock.qml entry point (quickshell/.config/quickshell/lock.qml) — never
// by the main shell.qml. See that file's header for why this must stay
// a separate process.
//
// Root is `PanelWindow`, not plain `Window` or `Item`: ShellRoot
// provides no geometry to its children, and plain Window{} never maps
// to a real X11 window in Quickshell 0.3.0 on X11 (confirmed in the
// 2026-07-06 Xvfb smoke test). PanelWindow with all-four-anchors is
// the correct fullscreen primitive.
//
// Authentication via Quickshell.Services.Pam's PamContext. The PAM
// signal/handler mapping (confirmed against both the installed
// qmltypes AND DankMaterialShell's working Pam.qml):
//   - Signal `pamMessage` → handler `onPamMessage`
//   - Signal `completed`  → handler `onCompleted` (arrow-function form
//     to avoid collision with Component.onCompleted)
//   - Signal `error`      → handler `onError`
//   - Property `message` is read via onMessageChanged, NOT onMessage
//   - Property `responseRequired` is read via onResponseRequiredChanged
//
// NOT live-tested for actual auth (no interactive password entry in
// Xvfb). The previous cold-start test confirmed the file LOADS and
// RENDERS without errors after the signal-handler fix.
PanelWindow {
    id: root

    // PanelWindow, not plain Window — see OSD.qml: plain Window{}
    // never maps to a real X11 window in Quickshell 0.3.0 (confirmed
    // in the 2026-07-06 Xvfb smoke test). Anchored to all four edges
    // = true fullscreen, which is exactly what a lock screen should be.
    visible: true
    anchors.top: true
    anchors.bottom: true
    anchors.left: true
    anchors.right: true
    exclusiveZone: -1
    aboveWindows: true
    focusable: true
    color: "transparent"

    property string password: ""
    property string statusMessage: ""
    property bool statusIsError: false
    property bool unlocking: false
    property bool unlocked: false

    // "login" is the most common baseline PAM service name for
    // unlock-style auth on non-greetd desktop sessions; swappable via
    // config field if a different service name is needed on this
    // distro's PAM stack. Not verified against Fedora 44's actual PAM
    // service files in this pass — flagged here rather than silently
    // assumed correct.
    property string pamService: "login"

    Component.onCompleted: {
        pam.user = Quickshell.env("USER") || "";
        pam.config = root.pamService;
    }

    PamContext {
        id: pam

        onPamMessage: function (message, isError, responseRequired, responseVisible) {
            if (message && message.length > 0) {
                root.statusMessage = message;
                root.statusIsError = isError;
            }
            if (responseRequired) {
                pam.respond(root.password);
            }
        }

        onCompleted: function (result) {
            root.unlocking = false;
            if (result === PamResult.Success) {
                root.unlocked = true;
                root.statusMessage = "";
                root.statusIsError = false;
                Qt.quit();
            } else {
                root.statusMessage = "Authentication failed";
                root.statusIsError = true;
                root.password = "";
                passwordInput.text = "";
            }
        }

        onError: function (error) {
            root.unlocking = false;
            root.statusMessage = "PAM error: " + error;
            root.statusIsError = true;
        }
    }

    function attemptUnlock() {
        if (root.unlocking || root.password.length === 0)
            return;
        root.unlocking = true;
        root.statusMessage = "";
        root.statusIsError = false;
        pam.start();
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.colors.background

        Column {
            anchors.centerIn: parent
            spacing: Theme.spacing * 2
            width: 360

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatDateTime(new Date(), "HH:mm")
                color: Theme.colors.foreground
                font.family: Theme.fontFamily
                font.pixelSize: 56
                font.bold: true

                Timer {
                    interval: 1000
                    running: true
                    repeat: true
                    onTriggered: parent.text = Qt.formatDateTime(new Date(), "HH:mm")
                }
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatDateTime(new Date(), "dddd, dd MMMM yyyy")
                color: Theme.colors.muted
                font.family: Theme.fontFamily
                font.pixelSize: 15
            }

            Rectangle {
                width: parent.width
                height: 44
                radius: Theme.radius * 0.5
                color: Theme.colors.surface
                border.color: root.statusIsError ? Theme.colors.urgent : Theme.colors.accent
                border.width: 1

                TextInput {
                    id: passwordInput
                    anchors.fill: parent
                    anchors.margins: 12
                    verticalAlignment: TextInput.AlignVCenter
                    echoMode: TextInput.Password
                    color: Theme.colors.foreground
                    font.family: Theme.fontFamily
                    font.pixelSize: 15
                    focus: true
                    enabled: !root.unlocking

                    onTextChanged: root.password = text

                    Keys.onPressed: function (event) {
                        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            root.attemptUnlock();
                            event.accepted = true;
                        }
                    }

                    Text {
                        visible: passwordInput.text.length === 0
                        text: root.unlocking ? "Checking\u2026" : "Enter password"
                        color: Theme.colors.muted
                        font.family: Theme.fontFamily
                        font.pixelSize: 15
                    }
                }
            }

            Text {
                visible: root.statusMessage.length > 0
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.statusMessage
                color: root.statusIsError ? Theme.colors.urgent : Theme.colors.muted
                font.family: Theme.fontFamily
                font.pixelSize: 12
            }
        }
    }
}