//@ pragma Env QT_QPA_PLATFORM=xcb
//@ pragma Env QT_QUICK_CONTROLS_STYLE=Basic

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth
import Quickshell.Networking
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower

ShellRoot {
    id: shell

    JsonObject {
        id: tokenColors

        property string background: "#1e1e2e"
        property string foreground: "#cdd6f4"
        property string accent: "#89b4fa"
        property string muted: "#585b70"
        property string surface: "#45475a"
        property string urgent: "#f38ba8"
        property string success: "#a6e3a1"
        property string warning: "#f9e2af"
        property string info: "#94e2d5"
        property string osd_background: "#dd1e1e2e"
    }

    JsonObject {
        id: themeTokens

        property string name: "bootstrap"
        property string font_family: "JetBrainsMono Nerd Font"
        property int radius: 18
        property int spacing: 12
        property JsonObject colors: tokenColors
    }

    FileView {
        id: themeFile

        path: Quickshell.shellPath("theme_tokens.json")
        watchChanges: true
        printErrors: false
        blockLoading: true
        adapter: JsonAdapter {
            property string name: themeTokens.name
            property string font_family: themeTokens.font_family
            property int radius: themeTokens.radius
            property int spacing: themeTokens.spacing
            property JsonObject colors: themeTokens.colors
        }
    }

    property var sink: Pipewire.defaultAudioSink
    property real volumePercent: (sink && sink.audio) ? Math.round(sink.audio.volume * 100) : 0
    property bool muted: (sink && sink.audio) ? sink.audio.muted : false
    property bool osdVisible: false

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

    function countModel(model) {
        return model && model.values ? model.values.length : 0;
    }

    function connectedBluetoothCount() {
        let count = 0;
        const devices = Bluetooth.devices && Bluetooth.devices.values ? Bluetooth.devices.values : [];
        for (let i = 0; i < devices.length; i++) {
            if (devices[i].connected)
                count++;
        }
        return count;
    }

    function connectedNetworkName() {
        const devices = Networking.devices && Networking.devices.values ? Networking.devices.values : [];
        for (let i = 0; i < devices.length; i++) {
            const device = devices[i];
            const networks = device.networks && device.networks.values ? device.networks.values : [];
            for (let j = 0; j < networks.length; j++) {
                if (networks[j].connected)
                    return networks[j].name || device.name || "connected";
            }
            if (device.connected)
                return device.name || "connected";
        }
        return "disconnected";
    }

    function inventoryJson() {
        const displayDevice = UPower.displayDevice;
        const batteryReady = displayDevice ? displayDevice.ready : false;
        const batteryPercent = displayDevice && displayDevice.ready ? Math.round(displayDevice.percentage) : null;
        const adapter = Bluetooth.defaultAdapter;
        const sinkReady = sink && sink.audio;

        return JSON.stringify({
            theme: {
                name: themeFile.loaded ? themeFile.text().match(/"name"\s*:\s*"([^"]+)"/)?.[1] || themeTokens.name : themeTokens.name,
                fontFamily: themeTokens.font_family,
                accent: tokenColors.accent,
                background: tokenColors.background
            },
            audio: {
                service: "Quickshell.Services.Pipewire",
                ready: Pipewire.ready,
                hasDefaultSink: !!sink,
                sinkDescription: sink ? (sink.description || sink.name || "") : "",
                volumePercent: sinkReady ? clampPercent(sink.audio.volume * 100) : null,
                muted: sinkReady ? sink.audio.muted : null,
                nativeControls: sinkReady
            },
            bluetooth: {
                service: "Quickshell.Bluetooth",
                hasDefaultAdapter: !!adapter,
                adapterName: adapter ? adapter.name : "",
                enabled: adapter ? adapter.enabled : false,
                adapters: countModel(Bluetooth.adapters),
                devices: countModel(Bluetooth.devices),
                connectedDevices: connectedBluetoothCount(),
                nativeControls: !!adapter
            },
            network: {
                service: "Quickshell.Networking",
                backend: NetworkBackendType.toString(Networking.backend),
                wifiEnabled: Networking.wifiEnabled,
                wifiHardwareEnabled: Networking.wifiHardwareEnabled,
                connectivity: NetworkConnectivity.toString(Networking.connectivity),
                devices: countModel(Networking.devices),
                connectedName: connectedNetworkName(),
                nativeControls: Networking.backend === NetworkBackendType.NetworkManager
            },
            power: {
                service: "Quickshell.Services.UPower",
                onBattery: UPower.onBattery,
                displayReady: batteryReady,
                percentage: batteryPercent,
                nativeControls: true
            },
            brightness: {
                service: null,
                nativeControls: false,
                fallback: "brightnessctl or sysfs bridge required in this Quickshell build"
            }
        });
    }

    function showVolume(percent, mutedValue) {
        // Keep this IPC path for manual testing and for any external fallback.
        volumePercent = clampPercent(percent);
        muted = parseMuted(mutedValue);
        osdVisible = true;
        hideTimer.restart();
    }

    function showCurrentVolume() {
        if (sink && sink.audio) {
            volumePercent = clampPercent(sink.audio.volume * 100);
            muted = sink.audio.muted;
        }
        osdVisible = true;
        hideTimer.restart();
    }

    IpcHandler {
        target: "services"

        function inventory(): string {
            return shell.inventoryJson();
        }
    }

    IpcHandler {
        target: "osd"

        function showVolume(percent: string, mutedValue: string): string {
            shell.showVolume(percent, mutedValue);
            return "ok";
        }

        function volumeUp(step: string): string {
            const delta = Number(step || "5") / 100;
            if (shell.sink && shell.sink.audio) {
                shell.sink.audio.muted = false;
                shell.sink.audio.volume = Math.min(1.0, shell.sink.audio.volume + delta);
                shell.showCurrentVolume();
                return "ok";
            }
            return "no-sink";
        }

        function volumeDown(step: string): string {
            const delta = Number(step || "5") / 100;
            if (shell.sink && shell.sink.audio) {
                shell.sink.audio.volume = Math.max(0.0, shell.sink.audio.volume - delta);
                shell.showCurrentVolume();
                return "ok";
            }
            return "no-sink";
        }

        function toggleMute(): string {
            if (shell.sink && shell.sink.audio) {
                shell.sink.audio.muted = !shell.sink.audio.muted;
                shell.showCurrentVolume();
                return "ok";
            }
            return "no-sink";
        }

        function showCurrentVolume(): string {
            shell.showCurrentVolume();
            return "ok";
        }
    }

    PwObjectTracker {
        objects: shell.sink ? [shell.sink] : []
    }

    Connections {
        target: shell.sink && shell.sink.audio ? shell.sink.audio : null

        function onVolumesChanged() {
            if (shell.sink && shell.sink.audio) {
                shell.volumePercent = shell.clampPercent(shell.sink.audio.volume * 100);
            }
        }

        function onMutedChanged() {
            if (shell.sink && shell.sink.audio) {
                shell.muted = shell.sink.audio.muted;
            }
        }
    }

    Timer {
        id: hideTimer
        interval: 1400
        repeat: false
        onTriggered: osdVisible = false
    }

    Window {
        id: osdWindow

        visible: shell.osdVisible
        opacity: shell.osdVisible ? 1.0 : 0.0
        title: "quickshell-osd-volume"
        width: 360
        height: 128
        x: 2700
        y: 112
        color: "transparent"
        flags: Qt.Tool | Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint | Qt.WindowDoesNotAcceptFocus

        Behavior on opacity {
            NumberAnimation {
                duration: 120
                easing.type: Easing.OutCubic
            }
        }

        Rectangle {
            anchors.fill: parent
            radius: themeTokens.radius
            color: tokenColors.osd_background
            border.color: shell.muted ? tokenColors.urgent : tokenColors.accent
            border.width: 1

            Column {
                anchors.fill: parent
                anchors.margins: 18
                spacing: themeTokens.spacing

                Row {
                    width: parent.width
                    spacing: themeTokens.spacing

                    Text {
                        text: shell.muted ? "" : ""
                        color: shell.muted ? tokenColors.urgent : tokenColors.accent
                        font.family: themeTokens.font_family
                        font.pixelSize: 22
                        width: 32
                        horizontalAlignment: Text.AlignHCenter
                    }

                    Column {
                        width: parent.width - 44
                        spacing: 4

                        Text {
                            text: shell.muted ? "Volume muted" : "Volume"
                            color: tokenColors.foreground
                            font.family: themeTokens.font_family
                            font.pixelSize: 15
                            font.bold: true
                        }

                        Text {
                            text: Pipewire.ready ? "PipeWire native service · " + themeTokens.name : "Waiting for PipeWire"
                            color: tokenColors.muted
                            font.family: themeTokens.font_family
                            font.pixelSize: 11
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 10
                    radius: 5
                    color: tokenColors.surface

                    Rectangle {
                        width: parent.width * (shell.muted ? 0 : shell.volumePercent / 100)
                        height: parent.height
                        radius: parent.radius
                        color: shell.muted ? tokenColors.urgent : tokenColors.accent
                    }
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: shell.muted ? "muted" : shell.volumePercent + "%"
                    color: tokenColors.foreground
                    font.family: themeTokens.font_family
                    font.pixelSize: 12
                }
            }
        }
    }
}
