import QtQuick
import QtQuick.Layouts
import "../../style" as ShellStyle

Item {
  id: root

  property var tags: []
  readonly property int count: tags ? tags.length : 0
  signal focusRequested(string name)

  implicitWidth: row.implicitWidth
  implicitHeight: ShellStyle.Metrics.barHeight

  RowLayout {
    id: row
    anchors.fill: parent
    spacing: 0

    Repeater {
      model: root.tags || []

      delegate: Item {
        id: tagItem
        required property var modelData
        implicitWidth: ShellStyle.Metrics.barHeight
        implicitHeight: ShellStyle.Metrics.barHeight
        Accessible.role: Accessible.PageTab
        Accessible.name: "Workspace " + String(tagItem.modelData.name || "")
        Accessible.selected: Boolean(tagItem.modelData.selected)

        Text {
          id: tagLabel
          anchors.centerIn: parent
          text: tagItem.modelData.selected
            ? "\uDB85\uDCFB"
            : String(tagItem.modelData.name || "")
          textFormat: Text.PlainText
          color: tagItem.modelData.urgent ? ShellStyle.Palette.urgent
            : (tagItem.modelData.selected || tagItem.modelData.occupied ? ShellStyle.Palette.foreground : ShellStyle.Palette.muted)
          opacity: hover.hovered || tagItem.modelData.selected || tagItem.modelData.occupied ? 1 : 0.5
          font.family: ShellStyle.Metrics.fontFamily
          font.pixelSize: ShellStyle.Metrics.smallTextSize
          font.weight: Font.Normal
        }

        HoverHandler { id: hover }
        TapHandler { onTapped: root.focusRequested(String(tagItem.modelData.name || "")) }
      }
    }
  }
}
