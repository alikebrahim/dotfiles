import QtQuick
import Quickshell
import Quickshell.Io
import "../../services"

// WindowSwitcher.qml — Mod+Tab floating window switcher.
//
// decisions.md §12's definitive override (item 2): this is its OWN
// surface, styled like the Quick Control Panel (small floating popup),
// listing open windows across all tags/screens with a search field —
// NOT a mode inside Launcher.qml as §7 originally sketched.
//
// Data source: BridgeState.screens[].tags[].clients[] (extended in
// awesome-integration/bridge.lua specifically for this surface — see
// that file's comment and BridgeState.qml's shape doc). Degrades to an
// empty, honestly-labeled list when BridgeState.connected is false,
// which is the current state until the bridge is wired into AwesomeWM
// during the authorized integration phase.
Item {
    id: root

    property bool panelVisible: false
    property string query: ""
    property int selectedIndex: 0

    // Flatten BridgeState's screens[].tags[].clients[] into one list of
    // {name, class, tagName, tagIndex, screenIndex} for search/selection.
    readonly property var allWindows: {
        if (!BridgeState.connected || !BridgeState.screens)
            return [];
        const result = [];
        const screens = BridgeState.screens;
        for (let si = 0; si < screens.length; si++) {
            const s = screens[si];
            if (!s.tags)
                continue;
            for (let ti = 0; ti < s.tags.length; ti++) {
                const t = s.tags[ti];
                if (!t.clients)
                    continue;
                for (let ci = 0; ci < t.clients.length; ci++) {
                    const c = t.clients[ci];
                    result.push({
                        name: c.name || "(untitled)",
                        clientClass: c["class"] || "",
                        urgent: !!c.urgent,
                        tagName: t.name || String(t.index),
                        tagIndex: t.index,
                        screenIndex: s.index
                    });
                }
            }
        }
        return result;
    }

    readonly property var filteredWindows: {
        if (root.query.length === 0)
            return root.allWindows;
        const q = root.query.toLowerCase();
        const result = [];
        for (let i = 0; i < root.allWindows.length; i++) {
            const w = root.allWindows[i];
            if (w.name.toLowerCase().indexOf(q) >= 0 || w.clientClass.toLowerCase().indexOf(q) >= 0) {
                result.push(w);
            }
        }
        return result;
    }

    function toggle() {
        root.panelVisible = !root.panelVisible;
        if (root.panelVisible) {
            root.query = "";
            root.selectedIndex = 0;
        }
    }

    function show() {
        root.panelVisible = true;
        root.query = "";
        root.selectedIndex = 0;
    }

    function hide() {
        root.panelVisible = false;
    }

    function moveSelection(delta) {
        const count = root.filteredWindows.length;
        if (count === 0)
            return;
        root.selectedIndex = ((root.selectedIndex + delta) % count + count) % count;
    }

    // Focusing a specific window from here requires an AwesomeWM-side
    // IPC command (e.g. "focus client by name on tag N"), which does not
    // exist yet — bridge.lua today only WRITES state, it does not listen
    // for commands. Documented as a follow-up in ambiguities.md rather
    // than guessed at here; this function is a deliberate no-op stub
    // until that command channel exists.
    function activateSelected() {
        if (root.filteredWindows.length === 0)
            return;
        console.warn("WindowSwitcher.qml: activateSelected() is a stub — AwesomeWM has no command-listener yet, only a state-writer. See revamp/ambiguities.md.");
        root.hide();
    }

    IpcHandler {
        target: "windowSwitcher"

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
        id: switcherWindow

        // PanelWindow, not plain Window — see OSD.qml: plain Window{}
        // never maps to a real X11 window in Quickshell 0.3.0 (confirmed
        // in the 2026-07-06 Xvfb smoke test). No anchors = centered.
        visible: root.panelVisible
        implicitWidth: 420
        implicitHeight: 360
        exclusiveZone: 0
        aboveWindows: true
        focusable: true
        color: "transparent"

        Shortcut {
            sequence: "Escape"
            onActivated: root.hide()
        }

        Rectangle {
            anchors.fill: parent
            radius: Theme.radius
            color: Theme.colors.background
            border.color: Theme.colors.accent
            border.width: 1

            Column {
                anchors.fill: parent
                anchors.margins: Theme.spacing
                spacing: Theme.spacing

                Text {
                    text: "Windows"
                    color: Theme.colors.foreground
                    font.family: Theme.fontFamily
                    font.pixelSize: 15
                    font.bold: true
                }

                TextInput {
                    id: searchInput
                    width: parent.width
                    height: 30
                    color: Theme.colors.foreground
                    font.family: Theme.fontFamily
                    font.pixelSize: 13
                    focus: root.panelVisible
                    text: root.query
                    clip: true

                    onTextEdited: {
                        root.query = text;
                        root.selectedIndex = 0;
                    }

                    Keys.onPressed: function (event) {
                        if (event.key === Qt.Key_Down || event.key === Qt.Key_Tab) {
                            root.moveSelection(1);
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Up || (event.key === Qt.Key_Tab && (event.modifiers & Qt.ShiftModifier))) {
                            root.moveSelection(-1);
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            root.activateSelected();
                            event.accepted = true;
                        }
                    }

                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: -4
                        z: -1
                        radius: Theme.radius * 0.4
                        color: Theme.colors.surface
                    }
                }

                Text {
                    visible: !BridgeState.connected
                    width: parent.width
                    wrapMode: Text.WordWrap
                    text: "Not connected to AwesomeWM yet \u2014 window list will populate once the bridge is wired in during integration."
                    color: Theme.colors.muted
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                }

                ListView {
                    width: parent.width
                    height: parent.height - 15 - 30 - (BridgeState.connected ? 0 : 34) - 2 * Theme.spacing
                    clip: true
                    model: root.filteredWindows
                    currentIndex: root.selectedIndex
                    spacing: 2

                    delegate: Rectangle {
                        required property var modelData
                        required property int index

                        width: ListView.view.width
                        height: 40
                        radius: Theme.radius * 0.4
                        color: index === root.selectedIndex ? Theme.colors.accent : "transparent"

                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.leftMargin: 10
                            spacing: 8

                            Text {
                                text: "[" + modelData.tagName + "]"
                                color: index === root.selectedIndex ? Theme.colors.background : Theme.colors.muted
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                            }

                            Text {
                                text: modelData.name
                                color: modelData.urgent ? Theme.colors.urgent : (index === root.selectedIndex ? Theme.colors.background : Theme.colors.foreground)
                                font.family: Theme.fontFamily
                                font.pixelSize: 12
                                elide: Text.ElideRight
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                root.selectedIndex = index;
                                root.activateSelected();
                            }
                        }
                    }
                }
            }
        }
    }
}
