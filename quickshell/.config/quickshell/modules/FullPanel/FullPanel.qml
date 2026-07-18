import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import Quickshell.Bluetooth
import "../../services"

// FullPanel.qml — Full Control Panel (Mod+Shift+Space).
//
// decisions.md §5: shape = B (card-based dashboard, Caelestia style, no
// sidebar), presentation = A (full-screen overlay), trigger = B (one
// dedicated key, Mod+Shift+Space — the quick audio/wifi/bluetooth/power
// keys are retired per §12's definitive override, replaced entirely by
// the Quick Control Panel).
//
// Section order follows Noctalia/Caelestia convention (overview first,
// hardware next, then software/system, then reference/utility last):
// Home, Audio, Network, Bluetooth, Power, Display, Theme, Notifications,
// AwesomeWM/Workspace, Keybinds, Calendar — all 11 sections from §5's
// checklist, "all sections, reasonable order".
//
// Structural completeness over content depth for this pass: simple
// sections (Home, Power, Theme, Keybinds, Calendar) have real, working
// content; complex ones (Audio mixer, Network list, Bluetooth pairing)
// have functional-but-simplified content with explicit TODO markers for
// enrichment during the integration phase, once real testing against a
// live session is possible.
Item {
    id: root

    property bool panelVisible: false

    function toggle() {
        root.panelVisible = !root.panelVisible;
    }

    function show() {
        root.panelVisible = true;
    }

    function hide() {
        root.panelVisible = false;
    }

    IpcHandler {
        target: "fullPanel"

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
        id: overlayWindow

        // PanelWindow, not plain Window — see OSD.qml: plain Window{}
        // never maps to a real X11 window in Quickshell 0.3.0 (confirmed
        // in the 2026-07-06 Xvfb smoke test). Anchored to all four edges
        // = true full-screen overlay per decisions.md §5 presentation
        // choice A.
        visible: root.panelVisible
        anchors.top: true
        anchors.bottom: true
        anchors.left: true
        anchors.right: true
        exclusiveZone: 0
        aboveWindows: true
        focusable: true
        color: "transparent"

        Shortcut {
            sequence: "Escape"
            onActivated: root.hide()
        }

        // Full-screen dim per decisions.md §5 presentation choice A.
        Rectangle {
            anchors.fill: parent
            color: Theme.colors.background
            opacity: 0.97

            Flickable {
                anchors.fill: parent
                anchors.margins: Theme.spacing * 2
                contentWidth: width
                contentHeight: cardColumn.height
                clip: true

                Column {
                    id: cardColumn
                    width: parent.width
                    spacing: Theme.spacing

                    Text {
                        text: "Control Panel"
                        color: Theme.colors.foreground
                        font.family: Theme.fontFamily
                        font.pixelSize: 22
                        font.bold: true
                    }

                    // ---- Home / overview -----------------------------
                    FullPanelCard {
                        title: "Overview"
                        width: parent.width

                        Row {
                            spacing: Theme.spacing * 2

                            Column {
                                spacing: 4
                                Text {
                                    text: Qt.formatDateTime(new Date(), "HH:mm")
                                    color: Theme.colors.foreground
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 28
                                    font.bold: true
                                }
                                Text {
                                    text: Qt.formatDateTime(new Date(), "dddd, dd MMMM yyyy")
                                    color: Theme.colors.muted
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 12
                                }
                            }

                            Column {
                                spacing: 4
                                Text {
                                    text: "AwesomeWM bridge"
                                    color: Theme.colors.muted
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 11
                                }
                                Text {
                                    text: BridgeState.connected ? "Connected" : "Not connected (integration pending)"
                                    color: BridgeState.connected ? Theme.colors.success : Theme.colors.warning
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 13
                                }
                            }

                            Column {
                                spacing: 4
                                Text {
                                    text: "Theme"
                                    color: Theme.colors.muted
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 11
                                }
                                Text {
                                    text: Theme.name
                                    color: Theme.colors.foreground
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 13
                                }
                            }
                        }
                    }

                    // ---- Audio ----------------------------------------
                    // TODO(integration): per-app volume mixer (§5's
                    // "if you want that level of detail") needs
                    // Pipewire.nodes enumeration + per-node volume
                    // controls; simplified here to the default sink only.
                    FullPanelCard {
                        title: "Audio"
                        width: parent.width

                        Column {
                            width: parent.width
                            spacing: 8

                            Row {
                                spacing: Theme.spacing
                                width: parent.width

                                Text {
                                    text: (Pipewire.defaultAudioSink && Pipewire.defaultAudioSink.audio && Pipewire.defaultAudioSink.audio.muted) ? "\uf6a9" : "\uf028"
                                    color: Theme.colors.accent
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 18
                                }

                                Slider {
                                    id: volumeSlider
                                    width: parent.width - 60
                                    from: 0
                                    to: 1
                                    value: (Pipewire.defaultAudioSink && Pipewire.defaultAudioSink.audio) ? Pipewire.defaultAudioSink.audio.volume : 0
                                    onMoved: {
                                        if (Pipewire.defaultAudioSink && Pipewire.defaultAudioSink.audio) {
                                            Pipewire.defaultAudioSink.audio.volume = value;
                                        }
                                    }
                                }

                                Text {
                                    text: (Pipewire.defaultAudioSink && Pipewire.defaultAudioSink.audio) ? Math.round(Pipewire.defaultAudioSink.audio.volume * 100) + "%" : "--"
                                    color: Theme.colors.foreground
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 12
                                }
                            }

                            Text {
                                text: "Per-app mixer: not yet implemented (TODO, integration phase)"
                                color: Theme.colors.muted
                                font.family: Theme.fontFamily
                                font.pixelSize: 10
                            }
                        }
                    }

                    // ---- Network ---------------------------------------
                    // TODO(integration): real Wi-Fi scan/connect/forget
                    // flow needs Quickshell.Networking (NetworkManager)
                    // wiring; placeholder list shown here.
                    FullPanelCard {
                        title: "Network"
                        width: parent.width

                        Text {
                            text: "Wi-Fi list, saved networks, connect/forget: not yet implemented (TODO, integration phase). Replaces rofi-wifi-menu.sh."
                            color: Theme.colors.muted
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            wrapMode: Text.WordWrap
                            width: parent.width
                        }
                    }

                    // ---- Bluetooth --------------------------------------
                    FullPanelCard {
                        title: "Bluetooth"
                        width: parent.width

                        Column {
                            width: parent.width
                            spacing: 6

                            Row {
                                spacing: Theme.spacing

                                Text {
                                    text: "Adapter:"
                                    color: Theme.colors.muted
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 12
                                }

                                Text {
                                    text: (typeof Bluetooth !== "undefined" && Bluetooth.defaultAdapter) ? (Bluetooth.defaultAdapter.enabled ? "On" : "Off") : "Not available"
                                    color: Theme.colors.foreground
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 12
                                    font.bold: true
                                }
                            }

                            Repeater {
                                model: (typeof Bluetooth !== "undefined" && Bluetooth.devices) ? Bluetooth.devices.values : []

                                Text {
                                    required property var modelData
                                    text: "\u2022 " + (modelData.name || modelData.deviceName || "Unknown device")
                                    color: Theme.colors.foreground
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 11
                                }
                            }

                            Text {
                                visible: typeof Bluetooth === "undefined" || !Bluetooth.devices || Bluetooth.devices.values.length === 0
                                text: "No paired devices. Full pairing flow: TODO, integration phase."
                                color: Theme.colors.muted
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                            }
                        }
                    }

                    // ---- Power ------------------------------------------
                    FullPanelCard {
                        title: "Power"
                        width: parent.width

                        Column {
                            width: parent.width
                            spacing: 8

                            Row {
                                spacing: Theme.spacing

                                Text {
                                    text: (typeof UPower !== "undefined" && UPower.displayDevice && UPower.displayDevice.ready) ? Math.round(UPower.displayDevice.percentage) + "%" : "No battery detected"
                                    color: Theme.colors.foreground
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 14
                                    font.bold: true
                                }

                                Text {
                                    visible: typeof UPower !== "undefined" && UPower.onBattery
                                    text: "(on battery)"
                                    color: Theme.colors.muted
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 11
                                }
                            }

                            Row {
                                spacing: Theme.spacing

                                // Absorbs rofi-power-menu.sh per §5's
                                // checklist. Uses Quickshell.execDetached
                                // rather than re-implementing systemd/
                                // loginctl calls inline.
                                Repeater {
                                    model: [
                                        { label: "Suspend", cmd: ["systemctl", "suspend"] },
                                        { label: "Restart", cmd: ["systemctl", "reboot"] },
                                        { label: "Power off", cmd: ["systemctl", "poweroff"] },
                                        { label: "Log out", cmd: ["awesome-client", "awesome.quit()"] }
                                    ]

                                    Rectangle {
                                        required property var modelData
                                        width: 90
                                        height: 32
                                        radius: Theme.radius * 0.4
                                        color: Theme.colors.surface

                                        Text {
                                            anchors.centerIn: parent
                                            text: modelData.label
                                            color: Theme.colors.foreground
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 11
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            onClicked: Quickshell.execDetached(modelData.cmd)
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // ---- Display / Brightness ---------------------------
                    // TODO(integration): monitor layout switch (absorbs
                    // rofi-display-manager.sh) needs real xrandr output
                    // enumeration; brightness control needs a real
                    // backlight backend (brightnessctl or similar) wired
                    // via Quickshell.execDetached, not guessed at here.
                    FullPanelCard {
                        title: "Display / Brightness"
                        width: parent.width

                        Column {
                            width: parent.width
                            spacing: 8

                            Slider {
                                id: brightnessSlider
                                width: parent.width - 20
                                from: 0
                                to: 100
                                value: 80

                                onMoved: {
                                    Quickshell.execDetached(["brightnessctl", "set", Math.round(value) + "%"]);
                                }
                            }

                            Text {
                                text: "Monitor layout switch: not yet implemented (TODO, integration phase). Replaces rofi-display-manager.sh."
                                color: Theme.colors.muted
                                font.family: Theme.fontFamily
                                font.pixelSize: 10
                                wrapMode: Text.WordWrap
                                width: parent.width
                            }
                        }
                    }

                    // ---- Theme -------------------------------------------
                    FullPanelCard {
                        title: "Theme"
                        width: parent.width

                        Column {
                            width: parent.width
                            spacing: 6

                            Text {
                                text: "Active: " + Theme.name
                                color: Theme.colors.foreground
                                font.family: Theme.fontFamily
                                font.pixelSize: 13
                            }

                            Text {
                                text: "Theme picker: not yet implemented (TODO, integration phase). Replaces the broken Mod+Ctrl+T theme-select keybind per decisions.md §12."
                                color: Theme.colors.muted
                                font.family: Theme.fontFamily
                                font.pixelSize: 10
                                wrapMode: Text.WordWrap
                                width: parent.width
                            }
                        }
                    }

                    // ---- Notifications -----------------------------------
                    FullPanelCard {
                        title: "Notifications"
                        width: parent.width

                        Column {
                            width: parent.width
                            spacing: 6

                            Text {
                                text: "Notification center: press Mod+N to open the full history view."
                                color: Theme.colors.foreground
                                font.family: Theme.fontFamily
                                font.pixelSize: 12
                            }

                            Text {
                                text: "Not yet live \u2014 Notifications server is inert until Dunst is retired during the integration cutover (see revamp/ambiguities.md)."
                                color: Theme.colors.muted
                                font.family: Theme.fontFamily
                                font.pixelSize: 10
                                wrapMode: Text.WordWrap
                                width: parent.width
                            }
                        }
                    }

                    // ---- AwesomeWM / Workspace ----------------------------
                    FullPanelCard {
                        title: "AwesomeWM / Workspace"
                        width: parent.width

                        Column {
                            width: parent.width
                            spacing: 6

                            Text {
                                text: BridgeState.connected ? "Bridge connected \u2014 " + (BridgeState.screens ? BridgeState.screens.length : 0) + " screen(s) reporting" : "Bridge not connected yet"
                                color: BridgeState.connected ? Theme.colors.success : Theme.colors.warning
                                font.family: Theme.fontFamily
                                font.pixelSize: 12
                            }

                            Row {
                                spacing: Theme.spacing

                                Text {
                                    text: "Lock screen backend:"
                                    color: Theme.colors.muted
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 11
                                }

                                Text {
                                    text: root.lockBackendLabel
                                    color: Theme.colors.foreground
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 11
                                    font.bold: true
                                }

                                Rectangle {
                                    width: 70
                                    height: 24
                                    radius: Theme.radius * 0.4
                                    color: Theme.colors.surface

                                    Text {
                                        anchors.centerIn: parent
                                        text: "Switch"
                                        color: Theme.colors.foreground
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 10
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: root.toggleLockBackend()
                                    }
                                }
                            }
                        }
                    }

                    // ---- Keybinds cheat-sheet -----------------------------
                    // Replaces rofi-keybinds.sh (static), now searchable.
                    // Source of truth is a plain in-QML list here rather
                    // than parsing keys.lua at runtime -- keys.lua isn't
                    // touched by this system yet (per user instruction),
                    // and parsing live Lua source from QML would be
                    // fragile. This list should be kept in sync manually
                    // during the integration phase when keys.lua actually
                    // changes.
                    FullPanelCard {
                        title: "Keybinds"
                        width: parent.width

                        Column {
                            width: parent.width
                            spacing: 4

                            TextInput {
                                id: keybindSearch
                                width: parent.width
                                height: 26
                                color: Theme.colors.foreground
                                font.family: Theme.fontFamily
                                font.pixelSize: 12

                                Rectangle {
                                    anchors.fill: parent
                                    anchors.margins: -4
                                    z: -1
                                    radius: Theme.radius * 0.4
                                    color: Theme.colors.surface
                                }

                                Text {
                                    visible: keybindSearch.text.length === 0
                                    text: "Filter keybinds\u2026"
                                    color: Theme.colors.muted
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 12
                                }
                            }

                            Repeater {
                                model: {
                                    const q = keybindSearch.text.toLowerCase();
                                    return root.keybindList.filter(k => q.length === 0 || k.keys.toLowerCase().indexOf(q) >= 0 || k.action.toLowerCase().indexOf(q) >= 0);
                                }

                                Row {
                                    required property var modelData
                                    spacing: Theme.spacing
                                    width: parent.width

                                    Text {
                                        text: modelData.keys
                                        color: Theme.colors.accent
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 11
                                        font.bold: true
                                        width: 140
                                    }

                                    Text {
                                        text: modelData.action
                                        color: Theme.colors.foreground
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 11
                                    }
                                }
                            }
                        }
                    }

                    // ---- Calendar -----------------------------------------
                    // Replaces rofi-calendar.sh. Simple month grid,
                    // current day highlighted; no event integration
                    // (out of scope per decisions.md, not requested).
                    FullPanelCard {
                        title: "Calendar"
                        width: parent.width

                        Grid {
                            columns: 7
                            spacing: 4
                            width: parent.width

                            Repeater {
                                model: ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"]
                                Text {
                                    required property var modelData
                                    text: modelData
                                    color: Theme.colors.muted
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 10
                                    horizontalAlignment: Text.AlignHCenter
                                    width: 30
                                }
                            }

                            Repeater {
                                model: root.calendarDays

                                Rectangle {
                                    required property var modelData
                                    width: 30
                                    height: 26
                                    radius: 4
                                    color: modelData.isToday ? Theme.colors.accent : "transparent"

                                    Text {
                                        anchors.centerIn: parent
                                        visible: modelData.day > 0
                                        text: modelData.day > 0 ? String(modelData.day) : ""
                                        color: modelData.isToday ? Theme.colors.background : Theme.colors.foreground
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 11
                                    }
                                }
                            }
                        }
                    }

                    Item {
                        width: 1
                        height: Theme.spacing * 2
                    }
                }
            }
        }
    }

    // ---- Shared data for the Keybinds and Calendar cards -----------------

    readonly property var keybindList: [
        { keys: "Mod+Space", action: "Launcher" },
        { keys: "Mod+Tab", action: "Window switcher" },
        { keys: "Mod+Shift+A", action: "Quick Control Panel" },
        { keys: "Mod+Shift+Space", action: "Full Control Panel" },
        { keys: "Mod+N", action: "Notification center" },
        { keys: "Mod+Shift+Space (alt binding, see ambiguities.md)", action: "Quick Apps menu" },
        { keys: "Mod+Grave", action: "Scratchpad toggle" }
    ]

    readonly property var calendarDays: {
        const now = new Date();
        const year = now.getFullYear();
        const month = now.getMonth();
        const firstDay = new Date(year, month, 1).getDay();
        const daysInMonth = new Date(year, month + 1, 0).getDate();
        const today = now.getDate();
        const cells = [];
        for (let i = 0; i < firstDay; i++) {
            cells.push({
                day: 0,
                isToday: false
            });
        }
        for (let d = 1; d <= daysInMonth; d++) {
            cells.push({
                day: d,
                isToday: d === today
            });
        }
        return cells;
    }

    property string lockBackendLabel: "i3lock"

    FileView {
        id: lockSettingsFile
        path: Quickshell.shellPath("lock-settings.json")
        watchChanges: false
        printErrors: false

        onLoaded: {
            try {
                const data = JSON.parse(text());
                root.lockBackendLabel = (data.backend === "quickshell") ? "Quickshell" : "i3lock";
            } catch (e) {
                // File missing or invalid — keep default
            }
        }

        onLoadFailed: {
            // File not created yet — keep default
        }
    }

    function toggleLockBackend() {
        root.lockBackendLabel = (root.lockBackendLabel === "i3lock") ? "Quickshell" : "i3lock";
        const backend = (root.lockBackendLabel === "Quickshell") ? "quickshell" : "i3lock";
        const payload = JSON.stringify({ backend: backend }, null, 2);
        lockSettingsFile.setText(payload);
    }
}
