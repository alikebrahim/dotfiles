import QtQuick
import Quickshell
import Quickshell.Io
import "../../services"

// Launcher.qml — Mod+Space launcher.
//
// decisions.md §7 (as overridden by §12's definitive keybind comment):
// ONE launcher surface bound to Mod+Space, presentation style (center
// modal vs. bottom-sprout) chosen from the Full Control Panel, not two
// separate keybinds. Window-switcher mode is dropped from this launcher
// entirely — it is now Mod+Tab's own dedicated surface
// (WindowSwitcher.qml in this same directory), per §12 item 2 overriding
// §7's original "window switcher mode within launcher" idea.
//
// Content per §7's final choice: app search (.desktop via
// Quickshell.DesktopEntries) + inline calculator. No command-palette
// prefix (explicitly declined).
//
// `launcherStyle` is a plain property here (not yet a persisted setting)
// — "center" or "sprout". Full Control Panel's Launcher-style setting
// (once built) should bind to this via the same IpcHandler exposed
// below, or a shared settings singleton in a later pass; for now it
// defaults to "center" and can be flipped via IPC for testing:
//   quickshell ipc -p <shell.qml> call launcher setStyle sprout
Item {
    id: root

    property bool panelVisible: false
    property string launcherStyle: "center"
    property string query: ""
    property int selectedIndex: 0

    // Resolve the raw DesktopEntries model to a plain JS array once per
    // change. `.values` is a QObjectList — QML exposes it as an
    // array-LIKE object, but NOT a true JS Array: Array.isArray() on it
    // returns false (verified in the 2026-07-06 Xvfb smoke test, where
    // an isArray guard silently emptied the whole app list). Spread into
    // a real JS array instead; guard only against null/undefined.
    readonly property var allApps: {
        if (typeof DesktopEntries === "undefined" || !DesktopEntries.applications)
            return [];
        const raw = DesktopEntries.applications.values;
        return raw ? [...raw] : [];
    }

    // Inline calculator: recognize a query that looks like a pure
    // arithmetic expression (digits, whitespace, + - * / ( ) . only) and
    // evaluate it instead of/alongside the app search results. Rejects
    // anything containing letters so app names are never misdetected as
    // expressions.
    readonly property bool looksLikeMath: /^[\d\s+\-*/().]+$/.test(root.query) && /[\d]/.test(root.query)
    readonly property var calcResult: {
        if (!root.looksLikeMath)
            return null;
        try {
            // Function(...) constructor, not eval() directly — same
            // isolation Qt/QML JS engines commonly recommend for
            // sandboxed expression evaluation; input is already
            // restricted to digits/operators/parens by the regex above,
            // so this cannot execute arbitrary code even though it is a
            // dynamic-code path.
            const value = Function('"use strict"; return (' + root.query + ')')();
            return (typeof value === "number" && isFinite(value)) ? value : null;
        } catch (e) {
            return null;
        }
    }

    readonly property var filteredApps: {
        if (root.query.length === 0)
            return root.allApps;
        const q = root.query.toLowerCase();
        const result = [];
        for (let i = 0; i < root.allApps.length; i++) {
            const app = root.allApps[i];
            const name = (app.name || "").toLowerCase();
            const generic = (app.genericName || "").toLowerCase();
            if (name.indexOf(q) >= 0 || generic.indexOf(q) >= 0) {
                result.push(app);
            }
        }
        return result;
    }

    function toggle() {
        root.panelVisible = !root.panelVisible;
        if (root.panelVisible)
            root.reset();
    }

    function show() {
        root.panelVisible = true;
        root.reset();
    }

    function hide() {
        root.panelVisible = false;
    }

    function reset() {
        root.query = "";
        root.selectedIndex = 0;
    }

    function setStyle(style) {
        if (style === "center" || style === "sprout")
            root.launcherStyle = style;
    }

    function moveSelection(delta) {
        const count = root.filteredApps.length;
        if (count === 0)
            return;
        root.selectedIndex = ((root.selectedIndex + delta) % count + count) % count;
    }

    function activateSelected() {
        if (root.filteredApps.length === 0)
            return;
        const app = root.filteredApps[root.selectedIndex];
        if (app && typeof app.execute === "function") {
            app.execute();
            root.hide();
        }
    }

    IpcHandler {
        target: "launcher"

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

        function setStyle(style: string): string {
            root.setStyle(style);
            return "ok";
        }
    }

    PanelWindow {
        id: launcherWindow

        readonly property bool isSprout: root.launcherStyle === "sprout"

        // PanelWindow, not plain Window — see OSD.qml: plain Window{}
        // never maps to a real X11 window in Quickshell 0.3.0 (confirmed
        // in the 2026-07-06 Xvfb smoke test).
        // Center style: no anchors = centered on screen.
        // Sprout style: anchored to the bottom edge, growing upward via
        // animated implicitHeight (decisions.md §7's Caelestia-style
        // bottom-sprout).
        visible: root.panelVisible
        anchors.bottom: isSprout
        implicitWidth: 480
        implicitHeight: isSprout ? (root.panelVisible ? 420 : 0) : 420
        exclusiveZone: 0
        aboveWindows: true
        focusable: true
        color: "transparent"

        Behavior on implicitHeight {
            enabled: launcherWindow.isSprout
            NumberAnimation {
                duration: 160
                easing.type: Easing.OutCubic
            }
        }

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
            clip: true

            Column {
                anchors.fill: parent
                anchors.margins: Theme.spacing
                spacing: Theme.spacing

                TextInput {
                    id: searchInput
                    width: parent.width
                    height: 32
                    color: Theme.colors.foreground
                    font.family: Theme.fontFamily
                    font.pixelSize: 15
                    focus: root.panelVisible
                    text: root.query
                    clip: true

                    onTextEdited: {
                        root.query = text;
                        root.selectedIndex = 0;
                    }

                    Keys.onPressed: function (event) {
                        if (event.key === Qt.Key_Down) {
                            root.moveSelection(1);
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Up) {
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

                    Text {
                        visible: searchInput.text.length === 0
                        text: "Search apps, or type a sum\u2026"
                        color: Theme.colors.muted
                        font.family: Theme.fontFamily
                        font.pixelSize: 15
                    }
                }

                Rectangle {
                    visible: root.calcResult !== null
                    width: parent.width
                    height: 40
                    radius: Theme.radius * 0.4
                    color: Theme.colors.accent

                    Text {
                        anchors.centerIn: parent
                        text: root.query + " = " + root.calcResult
                        color: Theme.colors.background
                        font.family: Theme.fontFamily
                        font.pixelSize: 14
                        font.bold: true
                    }
                }

                ListView {
                    width: parent.width
                    height: parent.height - 32 - Theme.spacing - (root.calcResult !== null ? 40 + Theme.spacing : 0)
                    clip: true
                    model: root.filteredApps
                    currentIndex: root.selectedIndex
                    spacing: 2

                    delegate: Rectangle {
                        required property var modelData
                        required property int index

                        width: ListView.view.width
                        height: 44
                        radius: Theme.radius * 0.4
                        color: index === root.selectedIndex ? Theme.colors.accent : "transparent"

                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.leftMargin: 10
                            spacing: 1

                            Text {
                                text: modelData.name || modelData.id || "Unknown"
                                color: index === root.selectedIndex ? Theme.colors.background : Theme.colors.foreground
                                font.family: Theme.fontFamily
                                font.pixelSize: 13
                                font.bold: index === root.selectedIndex
                            }

                            Text {
                                visible: !!modelData.genericName
                                text: modelData.genericName || ""
                                color: index === root.selectedIndex ? Theme.colors.background : Theme.colors.muted
                                font.family: Theme.fontFamily
                                font.pixelSize: 10
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
