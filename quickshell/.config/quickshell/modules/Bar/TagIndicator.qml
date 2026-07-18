import QtQuick
import "../../services"

// TagIndicator.qml — AwesomeWM tag/workspace indicator for the primary
// screen, driven by BridgeState (services/BridgeState.qml).
//
// Falls back to a static "1 2 3 4 5" placeholder (no live data, all
// dimmed except tag 1) when BridgeState.connected is false — expected
// until awesome-integration/bridge.lua is wired into AwesomeWM's rc.lua
// during the later integration phase (see revamp/ambiguities.md #8 and
// plan.md §5). This is an honest "not connected yet" state, not invented
// live data.
Row {
    id: root
    spacing: 6

    readonly property var primaryScreenData: BridgeState.connected ? BridgeState.primaryScreen() : null
    readonly property var tags: primaryScreenData && primaryScreenData.tags ? primaryScreenData.tags : []
    readonly property bool usingPlaceholder: tags.length === 0

    Repeater {
        model: root.usingPlaceholder ? [1, 2, 3, 4, 5] : root.tags

        Text {
            readonly property bool active: root.usingPlaceholder ? modelData === 1 : !!modelData.active
            readonly property bool urgent: root.usingPlaceholder ? false : !!modelData.urgent
            readonly property string label: root.usingPlaceholder ? String(modelData) : (modelData.name || String(modelData.index))

            text: label
            color: urgent ? Theme.colors.urgent : (active ? Theme.colors.accent : Theme.colors.muted)
            font.family: Theme.fontFamily
            font.pixelSize: 13
            font.bold: active
        }
    }
}
