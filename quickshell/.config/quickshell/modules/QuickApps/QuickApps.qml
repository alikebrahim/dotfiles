import QtQuick
import Quickshell
import Quickshell.Io
import "../../services"

// QuickApps.qml — Quick Launch Menu (Mod+Shift+Space per decisions.md
// §8's final choice, confirmed free of collision with the Full Control
// Panel which also wants Mod+Shift+Space — see revamp/ambiguities.md for
// the flagged three-way keybind conflict; this module itself does not
// resolve which surface actually gets that key during integration, it
// only implements the menu itself).
//
// decisions.md §8:
// - Layout: ALL THREE styles exist (grid/radial/hex), user picks the
//   active one from the Full Control Panel (not yet wired — see
//   FullPanel.qml's TODO in the AwesomeWM/Workspace card). Style is read
//   from quickapps-settings.json ("layout": "grid"|"radial"|"hex").
// - Customization: plain config file is the source of truth
//   (quickapps.json, hand-edited), matching choice A+control-panel.
// - Navigation: number keys 1-9 direct-launch, hjkl/arrows move
//   selection, Tab/Shift+Tab also cycle selection.
//
// Config files (both created alongside this module):
//   quickshell/.config/quickshell/quickapps.json          -- pinned app list
//   quickshell/.config/quickshell/quickapps-settings.json -- active layout
Item {
    id: root

    property bool panelVisible: false
    property int selectedIndex: 0
    property string layout: "grid"

    // Raw pinned entries from quickapps.json: [{id, label}, ...]
    property var pinnedRaw: []

    // Resolved entries: pinnedRaw joined with DesktopEntries lookups.
    // Unresolvable ids are skipped (with a console warning) rather than
    // shown as broken tiles.
    readonly property var resolvedApps: {
        const result = [];
        const hasDesktopEntries = typeof DesktopEntries !== "undefined" && DesktopEntries.applications;
        for (let i = 0; i < root.pinnedRaw.length; i++) {
            const pin = root.pinnedRaw[i];
            let entry = null;
            if (hasDesktopEntries && typeof DesktopEntries.byId === "function") {
                entry = DesktopEntries.byId(pin.id);
            }
            if (!entry && hasDesktopEntries && typeof DesktopEntries.heuristicLookup === "function") {
                entry = DesktopEntries.heuristicLookup(pin.label || pin.id);
            }
            if (!entry) {
                console.warn("QuickApps.qml: could not resolve pinned app id '" + pin.id + "' to a desktop entry, skipping");
                continue;
            }
            result.push({
                entry: entry,
                label: pin.label || entry.name || pin.id
            });
        }
        return result;
    }

    FileView {
        id: pinnedFile
        path: Quickshell.shellPath("quickapps.json")
        watchChanges: true
        printErrors: false
        blockLoading: true

        onLoaded: {
            try {
                const data = JSON.parse(text());
                root.pinnedRaw = (data && Array.isArray(data.pinned)) ? data.pinned : [];
            } catch (e) {
                console.warn("QuickApps.qml: failed to parse quickapps.json:", e);
                root.pinnedRaw = [];
            }
        }

        onLoadFailed: function (error) {
            console.warn("QuickApps.qml: could not read quickapps.json (" + error + "), no pinned apps available");
            root.pinnedRaw = [];
        }
    }

    FileView {
        id: settingsFile
        path: Quickshell.shellPath("quickapps-settings.json")
        watchChanges: true
        printErrors: false
        blockLoading: true

        onLoaded: {
            try {
                const data = JSON.parse(text());
                if (data && (data.layout === "grid" || data.layout === "radial" || data.layout === "hex")) {
                    root.layout = data.layout;
                }
            } catch (e) {
                console.warn("QuickApps.qml: failed to parse quickapps-settings.json, keeping current layout:", e);
            }
        }

        onLoadFailed: function (error) {
            // Not fatal -- defaults to "grid" from the property
            // initializer above.
        }
    }

    function toggle() {
        root.panelVisible = !root.panelVisible;
        if (root.panelVisible)
            root.selectedIndex = 0;
    }

    function show() {
        root.panelVisible = true;
        root.selectedIndex = 0;
    }

    function hide() {
        root.panelVisible = false;
    }

    function setLayout(mode) {
        if (mode === "grid" || mode === "radial" || mode === "hex")
            root.layout = mode;
    }

    function moveSelection(delta) {
        const count = root.resolvedApps.length;
        if (count === 0)
            return;
        root.selectedIndex = ((root.selectedIndex + delta) % count + count) % count;
    }

    function launchIndex(index) {
        if (index < 0 || index >= root.resolvedApps.length)
            return;
        const app = root.resolvedApps[index];
        if (app && app.entry && typeof app.entry.execute === "function") {
            app.entry.execute();
            root.hide();
        }
    }

    function launchSelected() {
        root.launchIndex(root.selectedIndex);
    }

    IpcHandler {
        target: "quickApps"

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

        function setLayout(mode: string): string {
            root.setLayout(mode);
            return "ok";
        }
    }

    PanelWindow {
        id: menuWindow

        // Hex/radial layouts want a square-ish canvas; grid wants a wide
        // rectangle. Sized generously enough for both without per-layout
        // window resizing logic.
        readonly property int menuSize: 420

        // PanelWindow, not plain Window — see OSD.qml: plain Window{}
        // never maps to a real X11 window in Quickshell 0.3.0 (confirmed
        // in the 2026-07-06 Xvfb smoke test). No anchors = centered.
        visible: root.panelVisible
        implicitWidth: menuSize
        implicitHeight: menuSize
        exclusiveZone: 0
        aboveWindows: true
        focusable: true
        color: "transparent"

        Shortcut {
            sequence: "Escape"
            onActivated: root.hide()
        }

        // Number-key direct launch, 1-9, per decisions.md §8's
        // "direct number-key shortcuts" navigation choice. Uses
        // Instantiator, not Repeater: Shortcut is a QtObject, not an
        // Item-derived type, and Repeater is documented/optimized
        // specifically for Item delegates (same fix already applied in
        // modules/Notifications/Toast.qml for Window delegates).
        Instantiator {
            model: 9
            Shortcut {
                required property int index
                sequence: String(index + 1)
                enabled: menuWindow.visible
                onActivated: root.launchIndex(index)
            }
        }

        Item {
            anchors.fill: parent
            focus: root.panelVisible

            Keys.onPressed: function (event) {
                if (event.key === Qt.Key_H || event.key === Qt.Key_Left || (event.key === Qt.Key_Tab && (event.modifiers & Qt.ShiftModifier))) {
                    root.moveSelection(-1);
                    event.accepted = true;
                } else if (event.key === Qt.Key_L || event.key === Qt.Key_Right || event.key === Qt.Key_Tab) {
                    root.moveSelection(1);
                    event.accepted = true;
                } else if (event.key === Qt.Key_J || event.key === Qt.Key_Down) {
                    root.moveSelection(root.layout === "grid" ? 3 : 1);
                    event.accepted = true;
                } else if (event.key === Qt.Key_K || event.key === Qt.Key_Up) {
                    root.moveSelection(root.layout === "grid" ? -3 : -1);
                    event.accepted = true;
                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    root.launchSelected();
                    event.accepted = true;
                }
            }

            Rectangle {
                anchors.fill: parent
                radius: Theme.radius
                color: Theme.colors.background
                border.color: Theme.colors.accent
                border.width: 1

                Text {
                    visible: root.resolvedApps.length === 0
                    anchors.centerIn: parent
                    width: parent.width - 40
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    text: "No pinned apps. Edit quickapps.json to add some."
                    color: Theme.colors.muted
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                }

                // ---- Grid layout ---------------------------------------
                Grid {
                    visible: root.layout === "grid" && root.resolvedApps.length > 0
                    anchors.centerIn: parent
                    columns: 3
                    spacing: Theme.spacing
                    width: parent.width - 2 * Theme.spacing

                    Repeater {
                        model: root.resolvedApps

                        QuickAppsTile {
                            required property var modelData
                            required property int index
                            width: (menuWindow.menuSize - 4 * Theme.spacing) / 3
                            height: width
                            label: modelData.label
                            selected: index === root.selectedIndex
                            onActivated: root.launchIndex(index)
                        }
                    }
                }

                // ---- Radial layout --------------------------------------
                // Pinned apps arranged in a circle around a center point,
                // per §8 option A.
                Item {
                    visible: root.layout === "radial" && root.resolvedApps.length > 0
                    anchors.fill: parent

                    Repeater {
                        model: root.resolvedApps

                        QuickAppsTile {
                            required property var modelData
                            required property int index
                            readonly property real angle: (2 * Math.PI * index) / Math.max(1, root.resolvedApps.length) - Math.PI / 2
                            readonly property real orbitRadius: menuWindow.menuSize * 0.32

                            width: 84
                            height: 84
                            x: menuWindow.menuSize / 2 + orbitRadius * Math.cos(angle) - width / 2
                            y: menuWindow.menuSize / 2 + orbitRadius * Math.sin(angle) - height / 2
                            label: modelData.label
                            selected: index === root.selectedIndex
                            onActivated: root.launchIndex(index)
                        }
                    }

                    Rectangle {
                        anchors.centerIn: parent
                        width: 10
                        height: 10
                        radius: 5
                        color: Theme.colors.accent
                    }
                }

                // ---- Hex layout -----------------------------------------
                // Pointy-top hex tiles, HUD-style, per §8 option B (the
                // "quickapps2" variant referenced in bjarneo/
                // omarchy-quickapps). Approximated with a hex-offset grid
                // rather than a true honeycomb tiling algorithm, close
                // enough for a small pinned-app count.
                Item {
                    visible: root.layout === "hex" && root.resolvedApps.length > 0
                    anchors.fill: parent

                    Repeater {
                        model: root.resolvedApps

                        QuickAppsTile {
                            required property var modelData
                            required property int index
                            readonly property int hexCols: 3
                            readonly property int col: index % hexCols
                            readonly property int row: Math.floor(index / hexCols)
                            readonly property real hexW: 96
                            readonly property real hexH: 84

                            hexShape: true
                            width: hexW
                            height: hexH
                            x: 20 + col * (hexW * 0.85) + (row % 2 === 1 ? hexW * 0.42 : 0)
                            y: 20 + row * (hexH * 0.78)
                            label: modelData.label
                            selected: index === root.selectedIndex
                            onActivated: root.launchIndex(index)
                        }
                    }
                }
            }
        }
    }
}
