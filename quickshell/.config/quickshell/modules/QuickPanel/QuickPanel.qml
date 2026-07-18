import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import Quickshell.Bluetooth
import "../../services"
// QuickPanel.qml — fast glance/toggle popup.
//
// decisions.md §4: layout = B (compact tile grid, subset of bjarneo's
// 4x3 — volume/wifi/bluetooth/battery), trigger = C (keybind AND bar
// click), position = B+C (small centered popup, anchored to whichever
// monitor currently has keyboard focus).
//
// "Whichever monitor currently has keyboard focus" would ideally come
// from BridgeState (AwesomeWM knows real keyboard focus), but the bridge
// is not wired into AwesomeWM yet (revamp/ambiguities.md #8) and this
// panel needs to be independently testable via `quickshell -p` before
// that integration happens. Falls back to Quickshell.screens[0] when
// BridgeState isn't connected — documented here, not hidden.
//
// IpcHandler target "quickPanel" lets AwesomeWM keybinds toggle this
// later (`quickshell ipc -p <shell.qml> call quickPanel toggle`) without
// needing any AwesomeWM-side changes yet — the keybind wiring itself is
// deferred to the integration phase per the user's explicit instruction.
Item {
    id: root

    property bool panelVisible: false

    readonly property var targetScreen: {
        if (BridgeState.connected) {
            const s = BridgeState.primaryScreen();
            if (s) {
                // BridgeState only carries AwesomeWM's internal screen
                // index today, not an X11 output name Quickshell can
                // match against — same gap noted in Bar.qml. Falls
                // through to the Quickshell-side default below until
                // bridge.lua is extended to carry output names.
            }
        }
        const list = Quickshell.screens;
        return list.length > 0 ? list[0] : null;
    }

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
        target: "quickPanel"

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

    // Tile data model. Each tile is a small self-contained delegate below
    // rather than a shared generic component, since each tile's expanded
    // detail view differs enough (slider vs. list vs. plain text) that a
    // one-size-fits-all delegate would need as much branching as just
    // writing four small tiles directly.
    property int expandedTileIndex: -1

    function expandTile(index) {
        root.expandedTileIndex = (root.expandedTileIndex === index) ? -1 : index;
    }

    PanelWindow {
        id: panelWindow

        readonly property int tileSize: 96
        readonly property int gridSpacing: Theme.spacing
        readonly property int columns: 2
        readonly property int rows: 2
        readonly property int panelWidth: columns * tileSize + (columns + 1) * gridSpacing
        readonly property int panelHeight: rows * tileSize + (rows + 1) * gridSpacing + (root.expandedTileIndex >= 0 ? 72 : 0)

        // PanelWindow, not plain Window — see OSD.qml's comment: plain
        // Window{} never maps to a real X11 window in Quickshell 0.3.0
        // (confirmed in the 2026-07-06 Xvfb smoke test). No anchors set
        // = centered on screen (layer-shell semantics), which matches
        // decisions.md §4's "small centered popup" placement.
        visible: root.panelVisible
        implicitWidth: panelWidth
        implicitHeight: panelHeight
        exclusiveZone: 0
        aboveWindows: true
        focusable: true
        color: "transparent"

        Behavior on height {
            NumberAnimation {
                duration: 120
                easing.type: Easing.OutCubic
            }
        }

        // Dismiss on click-outside / Escape, per the keyboard-navigation
        // contract in decisions.md §1 ("Esc = close current panel").
        Shortcut {
            sequence: "Escape"
            onActivated: root.hide()
        }

        Rectangle {
            anchors.fill: parent
            radius: Theme.radius
            color: Theme.colors.background
            border.color: Theme.colors.surface
            border.width: 1

            Column {
                anchors.fill: parent
                anchors.margins: panelWindow.gridSpacing
                spacing: panelWindow.gridSpacing

                Grid {
                    id: tileGrid
                    columns: panelWindow.columns
                    spacing: panelWindow.gridSpacing
                    width: parent.width

                    // Volume tile
                    QuickPanelTile {
                        width: panelWindow.tileSize
                        height: panelWindow.tileSize
                        icon: (Pipewire.defaultAudioSink && Pipewire.defaultAudioSink.audio && Pipewire.defaultAudioSink.audio.muted) ? "\uf6a9" : "\uf028"
                        label: "Volume"
                        valueText: (Pipewire.defaultAudioSink && Pipewire.defaultAudioSink.audio) ? Math.round(Pipewire.defaultAudioSink.audio.volume * 100) + "%" : "--"
                        expanded: root.expandedTileIndex === 0
                        onActivated: root.expandTile(0)
                        onToggled: {
                            if (Pipewire.defaultAudioSink && Pipewire.defaultAudioSink.audio) {
                                Pipewire.defaultAudioSink.audio.muted = !Pipewire.defaultAudioSink.audio.muted;
                            }
                        }
                    }

                    // Network tile
                    QuickPanelTile {
                        width: panelWindow.tileSize
                        height: panelWindow.tileSize
                        icon: "\uf1eb"
                        label: "Network"
                        valueText: "\u2014"
                        expanded: root.expandedTileIndex === 1
                        onActivated: root.expandTile(1)
                        onToggled: {}
                    }

                    // Bluetooth tile — guarded: Bluetooth.defaultAdapter
                    // is not confirmed present on every X11/AwesomeWM
                    // machine (no adapter, or the Bluetooth module not
                    // fully initialized at startup). Degrades to a plain
                    // "N/A" tile rather than throwing on a null property
                    // access.
                    QuickPanelTile {
                        width: panelWindow.tileSize
                        height: panelWindow.tileSize
                        icon: "\uf294"
                        label: "Bluetooth"
                        valueText: (typeof Bluetooth !== "undefined" && Bluetooth.defaultAdapter) ? (Bluetooth.defaultAdapter.enabled ? "On" : "Off") : "N/A"
                        expanded: root.expandedTileIndex === 2
                        onActivated: root.expandTile(2)
                        onToggled: {
                            if (typeof Bluetooth !== "undefined" && Bluetooth.defaultAdapter) {
                                Bluetooth.defaultAdapter.enabled = !Bluetooth.defaultAdapter.enabled;
                            }
                        }
                    }

                    // Battery/power tile — guarded: UPower.displayDevice
                    // may not be ready (e.g. desktop with no battery) or
                    // UPower may not resolve on this build at all.
                    QuickPanelTile {
                        width: panelWindow.tileSize
                        height: panelWindow.tileSize
                        icon: (typeof UPower !== "undefined" && UPower.onBattery) ? "\uf242" : "\uf1e6"
                        label: "Power"
                        valueText: (typeof UPower !== "undefined" && UPower.displayDevice && UPower.displayDevice.ready) ? Math.round(UPower.displayDevice.percentage) + "%" : "--"
                        expanded: root.expandedTileIndex === 3
                        onActivated: root.expandTile(3)
                        onToggled: {}
                    }
                }

                Item {
                    width: parent.width
                    height: root.expandedTileIndex >= 0 ? 60 : 0
                    visible: root.expandedTileIndex >= 0
                    clip: true

                    Text {
                        anchors.centerIn: parent
                        text: "Detail view for tile " + root.expandedTileIndex + " \u2014 placeholder, expand per tile in a follow-up pass"
                        color: Theme.colors.muted
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                        wrapMode: Text.WordWrap
                        width: parent.width - 20
                        horizontalAlignment: Text.AlignHCenter
                    }
                }
            }
        }
    }
}
