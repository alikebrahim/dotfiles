import QtQuick
import "../style" as ShellStyle

Item {
  id: root

  property string text: ""
  property string iconText: ""
  property string accessibleName: text || iconText || "Button"
  property bool current: false
  property bool hasCursor: false
  property bool enabled: true
  signal clicked()
  signal hovered(bool value)

  implicitWidth: Math.max(34, content.implicitWidth + ShellStyle.Metrics.controlPaddingX * 2)
  implicitHeight: ShellStyle.Metrics.controlHeight
  opacity: enabled ? 1 : 0.42
  Accessible.role: Accessible.Button
  Accessible.name: accessibleName
  Accessible.focusable: true

  Rectangle {
    anchors.fill: parent
    radius: ShellStyle.Metrics.cornerRadius
    color: root.current
      ? ShellStyle.Palette.selectedWash
      : ((pointer.hovered || root.hasCursor) ? ShellStyle.Palette.hoverWash : ShellStyle.Palette.normalWash)
    border.width: root.current ? 0 : 1
    border.color: (pointer.hovered || root.hasCursor)
      ? ShellStyle.Palette.hoverBorder
      : ShellStyle.Palette.controlBorder

    Behavior on color {
      ColorAnimation { duration: ShellStyle.Metrics.animationMs }
    }
  }

  Row {
    id: content
    anchors.centerIn: parent
    spacing: ShellStyle.Metrics.labelGap

    Text {
      visible: root.iconText !== ""
      text: root.iconText
      textFormat: Text.PlainText
      color: ShellStyle.Palette.foreground
      font.family: ShellStyle.Metrics.fontFamily
      font.pixelSize: ShellStyle.Metrics.titleSize
      anchors.verticalCenter: parent.verticalCenter
    }

    Text {
      visible: root.text !== ""
      text: root.text
      textFormat: Text.PlainText
      color: ShellStyle.Palette.foreground
      font.family: ShellStyle.Metrics.fontFamily
      font.pixelSize: ShellStyle.Metrics.bodySmallSize
      font.weight: Font.Medium
      anchors.verticalCenter: parent.verticalCenter
    }
  }

  HoverHandler {
    id: pointer
    onHoveredChanged: root.hovered(hovered)
  }

  TapHandler {
    enabled: root.enabled
    acceptedButtons: Qt.LeftButton
    onTapped: root.clicked()
  }
}
