import QtQuick
import "../../services"

// FocusedTitle.qml — name of the currently focused AwesomeWM window,
// driven by BridgeState. Falls back to blank text (not an invented
// placeholder title) when BridgeState.connected is false or no client is
// focused — an empty bar center is a more honest "no data yet" signal
// than fabricating a fake window name.
Text {
    id: root

    readonly property string title: BridgeState.connected && BridgeState.focusedClientName ? BridgeState.focusedClientName : ""

    text: title
    color: Theme.colors.foreground
    font.family: Theme.fontFamily
    font.pixelSize: 13
    elide: Text.ElideRight
}
