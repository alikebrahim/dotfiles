import QtQuick
import "../../services"

// QuickPanelTile.qml — reusable tile delegate for QuickPanel's grid.
//
// Click activates/expands the tile (deep-link into detail view); a
// small toggle affordance (top-right dot) flips the underlying state
// directly without expanding, per decisions.md §4 option B ("each tile
// shows current state... Enter expands it into detail, Esc collapses").
Rectangle {
    id: root

    property string icon: ""
    property string label: ""
    property string valueText: ""
    property bool expanded: false

    signal activated
    signal toggled

    radius: Theme.radius * 0.6
    color: expanded ? Theme.colors.accent : Theme.colors.surface
    border.color: expanded ? Theme.colors.accent : Theme.colors.muted
    border.width: 1

    Column {
        anchors.centerIn: parent
        spacing: 4

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.icon
            color: root.expanded ? Theme.colors.background : Theme.colors.foreground
            font.family: Theme.fontFamily
            font.pixelSize: 24
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.label
            color: root.expanded ? Theme.colors.background : Theme.colors.foreground
            font.family: Theme.fontFamily
            font.pixelSize: 11
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.valueText
            color: root.expanded ? Theme.colors.background : Theme.colors.muted
            font.family: Theme.fontFamily
            font.pixelSize: 10
        }
    }

    // Small toggle affordance, top-right corner — flips state without
    // expanding the tile.
    Rectangle {
        width: 12
        height: 12
        radius: 6
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: 6
        color: root.expanded ? Theme.colors.background : Theme.colors.accent

        MouseArea {
            anchors.fill: parent
            onClicked: root.toggled()
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: root.activated()
    }
}
