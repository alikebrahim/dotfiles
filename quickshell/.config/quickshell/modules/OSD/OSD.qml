import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import "../../services"

// OSD.qml — on-screen display for volume (brightness/mic to follow).
//
// This preserves the exact IPC surface the existing
// awesome_wm_scripts/.config/scripts/quickshell-osd-volume.sh script
// depends on today:
//   quickshell ipc -p <shell.qml> call osd showVolume <percent> <muted>
// target "osd", methods showVolume/volumeUp/volumeDown/toggleMute/
// showCurrentVolume — unchanged from the original monolithic shell.qml
// prototype. Only the theme-token source changed: colors/font/radius/
// spacing now come from the shared Theme singleton (services/Theme.qml)
// instead of an inline JsonObject+FileView duplicated in this file.
Item {
    id: root

    property var sink: Pipewire.defaultAudioSink
    property real volumePercent: (sink && sink.audio) ? Math.round(sink.audio.volume * 100) : 0
    property bool muted: (sink && sink.audio) ? sink.audio.muted : false
    property bool visible_: false

    function clampPercent(value) {
        const n = Number(value);
        if (isNaN(n))
            return 0;
        return Math.max(0, Math.min(100, Math.round(n)));
    }

    function parseMuted(value) {
        const s = String(value).toLowerCase();
        return s === "true" || s === "1" || s === "yes" || s === "muted" || s === "on";
    }

    function showVolume(percent, mutedValue) {
        // Kept for manual testing / external fallback, same as the
        // original prototype's IPC-driven path.
        root.volumePercent = clampPercent(percent);
        root.muted = parseMuted(mutedValue);
        root.visible_ = true;
        hideTimer.restart();
    }

    function showCurrentVolume() {
        if (root.sink && root.sink.audio) {
            root.volumePercent = clampPercent(root.sink.audio.volume * 100);
            root.muted = root.sink.audio.muted;
        }
        root.visible_ = true;
        hideTimer.restart();
    }

    IpcHandler {
        target: "osd"

        function showVolume(percent: string, mutedValue: string): string {
            root.showVolume(percent, mutedValue);
            return "ok";
        }

        function volumeUp(step: string): string {
            const delta = Number(step || "5") / 100;
            if (root.sink && root.sink.audio) {
                root.sink.audio.muted = false;
                root.sink.audio.volume = Math.min(1.0, root.sink.audio.volume + delta);
                root.showCurrentVolume();
                return "ok";
            }
            return "no-sink";
        }

        function volumeDown(step: string): string {
            const delta = Number(step || "5") / 100;
            if (root.sink && root.sink.audio) {
                root.sink.audio.volume = Math.max(0.0, root.sink.audio.volume - delta);
                root.showCurrentVolume();
                return "ok";
            }
            return "no-sink";
        }

        function toggleMute(): string {
            if (root.sink && root.sink.audio) {
                root.sink.audio.muted = !root.sink.audio.muted;
                root.showCurrentVolume();
                return "ok";
            }
            return "no-sink";
        }

        function showCurrentVolume(): string {
            root.showCurrentVolume();
            return "ok";
        }
    }

    Connections {
        target: root.sink && root.sink.audio ? root.sink.audio : null

        function onVolumesChanged() {
            if (root.sink && root.sink.audio) {
                root.volumePercent = root.clampPercent(root.sink.audio.volume * 100);
            }
        }

        function onMutedChanged() {
            if (root.sink && root.sink.audio) {
                root.muted = root.sink.audio.muted;
            }
        }
    }

    Timer {
        id: hideTimer
        interval: 1400
        repeat: false
        onTriggered: root.visible_ = false
    }

    PanelWindow {
        id: osdWindow

        // PanelWindow, not plain QtQuick Window: verified in the Xvfb
        // smoke test (2026-07-06) that plain Window{} nested under an
        // Item root never maps to a real X11 window in Quickshell 0.3.0
        // — IPC returned ok but nothing rendered. PanelWindow with
        // exclusiveZone:0 is the correct Quickshell primitive for
        // overlay popups. Anchoring top-only centers horizontally along
        // that edge (layer-shell semantics), replacing the old
        // hardcoded x=2700,y=112 with margins.top.
        visible: root.visible_
        anchors.top: true
        margins.top: 112
        implicitWidth: 360
        implicitHeight: 128
        exclusiveZone: 0
        aboveWindows: true
        focusable: false
        color: "transparent"

        Rectangle {
            anchors.fill: parent
            radius: Theme.radius
            color: Theme.colors.osd_background
            border.color: root.muted ? Theme.colors.urgent : Theme.colors.accent
            border.width: 1
            opacity: root.visible_ ? 1.0 : 0.0

            Behavior on opacity {
                NumberAnimation {
                    duration: 120
                    easing.type: Easing.OutCubic
                }
            }

            Column {
                anchors.fill: parent
                anchors.margins: 18
                spacing: Theme.spacing

                Row {
                    width: parent.width
                    spacing: Theme.spacing

                    Text {
                        text: root.muted ? "\uf6a9" : "\uf028"
                        color: root.muted ? Theme.colors.urgent : Theme.colors.accent
                        font.family: Theme.fontFamily
                        font.pixelSize: 22
                        width: 32
                        horizontalAlignment: Text.AlignHCenter
                    }

                    Column {
                        width: parent.width - 44
                        spacing: 4

                        Text {
                            text: root.muted ? "Volume muted" : "Volume"
                            color: Theme.colors.foreground
                            font.family: Theme.fontFamily
                            font.pixelSize: 15
                            font.bold: true
                        }

                        Text {
                            text: Pipewire.ready ? "PipeWire native service \u00b7 " + Theme.name : "Waiting for PipeWire"
                            color: Theme.colors.muted
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 10
                    radius: 5
                    color: Theme.colors.surface

                    Rectangle {
                        width: parent.width * (root.muted ? 0 : root.volumePercent / 100)
                        height: parent.height
                        radius: parent.radius
                        color: root.muted ? Theme.colors.urgent : Theme.colors.accent
                    }
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.muted ? "muted" : root.volumePercent + "%"
                    color: Theme.colors.foreground
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                }
            }
        }
    }
}
