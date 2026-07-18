import QtQuick
import "../../services"

// FullPanelCard.qml — reusable card container for FullPanel.qml's
// dashboard layout (decisions.md §5 shape choice B: "card-based
// dashboard, Caelestia style").
//
// Each card is a titled rounded rectangle with a `default` content
// property, so callers just nest their content directly:
//   FullPanelCard { title: "Audio"; Row { ... } }
Rectangle {
    id: root

    property string title: ""
    default property alias cardContent: contentItem.data

    implicitHeight: cardColumn.height + Theme.spacing * 2
    radius: Theme.radius * 0.6
    color: Theme.colors.surface
    border.color: Theme.colors.muted
    border.width: 1

    Column {
        id: cardColumn
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Theme.spacing
        spacing: 8

        Text {
            text: root.title
            color: Theme.colors.accent
            font.family: Theme.fontFamily
            font.pixelSize: 13
            font.bold: true
        }

        Item {
            id: contentItem
            width: parent.width
            height: childrenRect.height
        }
    }
}
