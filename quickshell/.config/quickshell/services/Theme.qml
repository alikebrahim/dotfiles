pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

// Theme.qml — live theme-token singleton.
//
// Matches the proven-working pattern from the original shell.qml
// prototype (confirmed live via `quickshell -p shell.qml` + IPC inventory
// call in quickshell-research.md): `Quickshell.shellPath()` for the file
// path, and `JsonAdapter` bound to `JsonObject` properties (NOT plain
// QtObject — JsonAdapter's nested-object binding requires JsonObject to
// read/write sub-object fields).
//
// Registered as a singleton via services/qmldir so any other module can
// `import "../services"` and reference `Theme.colors.background`,
// `Theme.fontFamily`, etc.
Singleton {
    id: root

    property string name: "everforest"
    property string fontFamily: "JetBrainsMono Nerd Font"
    property int radius: 18
    property int spacing: 12

    property JsonObject colors: JsonObject {
        property string background: "#2d353b"
        property string foreground: "#d3c6aa"
        property string accent: "#7fbbb3"
        property string muted: "#475258"
        property string surface: "#475258"
        property string urgent: "#e67e80"
        property string success: "#a7c080"
        property string warning: "#dbbc7f"
        property string info: "#83c092"
        property string osd_background: "#dd2d353b"
    }

    FileView {
        id: themeFile
        path: Quickshell.shellPath("theme_tokens.json")
        watchChanges: true
        printErrors: false
        blockLoading: true

        // watchChanges only emits fileChanged — it does NOT re-read the
        // file into the adapter by itself (confirmed in the 2026-07-06
        // Xvfb smoke test on BridgeState; DankMaterialShell's Theme/
        // SettingsData FileViews use this same onFileChanged->reload()
        // pattern). Without this, theme-apply edits would silently
        // never propagate to a running shell.
        onFileChanged: themeFile.reload()

        adapter: JsonAdapter {
            property string name: root.name
            property string font_family: root.fontFamily
            property int radius: root.radius
            property int spacing: root.spacing
            property JsonObject colors: root.colors
        }
    }
}
