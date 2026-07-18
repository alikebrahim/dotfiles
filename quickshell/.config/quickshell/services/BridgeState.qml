pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

// BridgeState.qml — reads AwesomeWM's tag/focus state.
//
// Reads $XDG_RUNTIME_DIR/awesome-bridge-state.json, written by
// awesome-integration/bridge.lua (currently inert/unwired — see
// revamp/ambiguities.md #8). That file does not exist yet on this
// machine, so this singleton must degrade gracefully: `connected` stays
// false and `screens`/`focused` stay at their empty defaults until the
// bridge is wired into AwesomeWM's rc.lua during the later integration
// phase.
//
// Deliberately uses manual JSON.parse() in onLoaded/onLoadFailed (the
// pattern DankMaterialShell's SettingsSearchService.qml and
// NotepadStorageService.qml use for complex/dynamic JSON), NOT
// FileView+JsonAdapter. JsonAdapter binds fixed property names to fixed
// JSON keys one-to-one, which works for theme_tokens.json's small flat
// schema (see Theme.qml) but not for this file's dynamic array-of-objects
// shape (a variable number of screens, each with a variable number of
// tags) — there is no way to declare "however many screens/tags show up"
// as adapter properties ahead of time.
//
// Shape written by bridge.lua:
// {
//   "screens": [
//     {"index":1,"primary":true,"tags":[{"index":1,"name":"1","active":true,"urgent":false,"clientCount":2,"clients":[{"name":"...","class":"...","urgent":false}, ...]}, ...]},
//     ...
//   ],
//   "focused": {"hasClient":true,"name":"...","class":"...","screen":1}
// }
//
// The per-tag "clients" array was added specifically for
// modules/Launcher/WindowSwitcher.qml (Mod+Tab), which needs to list and
// search actual open windows, not just a per-tag count.
Singleton {
    id: root

    // True once a state file has been successfully read at least once.
    // Consumers (Bar's tag indicator, etc.) should use this to fall back
    // to a placeholder UI instead of showing stale/empty data as if it
    // were real.
    property bool connected: false

    // Raw parsed arrays/objects, as-is from the JSON (screens[].tags[]
    // keep their original key names: index, name, active, urgent,
    // clientCount).
    property var screens: []

    // Focused-client info, normalized to camelCase since "class" is a
    // reserved-ish word to avoid confusion with QML's own class concept
    // elsewhere in this codebase — kept as a plain object copy, not bound
    // through any adapter, so the rename is just a JS assignment below.
    property bool focusedHasClient: false
    property string focusedClientName: ""
    property string focusedClientClass: ""
    property int focusedScreenIndex: 0

    // Active tag index on the primary screen (or the first screen if no
    // primary flag is set), 1-based to match AwesomeWM's tag numbering.
    // Falls back to 1 when disconnected/no data yet.
    readonly property int primaryActiveTagIndex: {
        const s = primaryScreen();
        if (!s || !s.tags)
            return 1;
        for (const t of s.tags) {
            if (t.active)
                return t.index;
        }
        return 1;
    }

    function primaryScreen() {
        if (!screens || screens.length === 0)
            return null;
        for (const s of screens) {
            if (s.primary)
                return s;
        }
        return screens[0];
    }

    function screenByIndex(index) {
        if (!screens)
            return null;
        for (const s of screens) {
            if (s.index === index)
                return s;
        }
        return null;
    }

    FileView {
        id: stateFile
        path: (Quickshell.env("XDG_RUNTIME_DIR") || "/run/user/1000") + "/awesome-bridge-state.json"
        watchChanges: true
        printErrors: false
        blockLoading: false

        // watchChanges only emits fileChanged — it does NOT reload the
        // content by itself (confirmed in the 2026-07-06 Xvfb smoke
        // test; DankMaterialShell's SettingsData/Theme FileViews use
        // exactly this onFileChanged->reload() pattern).
        onFileChanged: stateFile.reload()

        onLoaded: {
            try {
                const data = JSON.parse(text());
                root.screens = (data && Array.isArray(data.screens)) ? data.screens : [];

                const f = data && data.focused ? data.focused : null;
                root.focusedHasClient = f ? !!f.hasClient : false;
                root.focusedClientName = f ? (f.name || "") : "";
                root.focusedClientClass = f ? (f["class"] || "") : "";
                root.focusedScreenIndex = f ? (f.screen || 0) : 0;

                root.connected = true;
            } catch (e) {
                console.warn("BridgeState.qml: failed to parse awesome-bridge-state.json:", e);
                root.connected = false;
            }
        }

        onLoadFailed: function (error) {
            // Expected until bridge.lua is wired into AwesomeWM and has
            // written at least one state file. Not an error condition to
            // surface loudly — just means "bridge not connected yet".
            root.connected = false;
        }
    }

    // The file watcher cannot arm on a file that did not exist at
    // startup (loadFailed leaves no inotify target). Poll a reload every
    // 3s while disconnected so the bridge is picked up whenever
    // AwesomeWM starts writing it; once connected, the fileChanged
    // watcher takes over and this timer stops.
    Timer {
        interval: 3000
        repeat: true
        running: !root.connected
        onTriggered: stateFile.reload()
    }
}
