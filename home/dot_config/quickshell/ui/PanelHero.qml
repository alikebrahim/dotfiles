import QtQuick
import "../style" as ShellStyle

// Hero layout for audio, network, Bluetooth, power, and brightness panels.
Item {
  id: root

  property string iconText: ""
  property string title: ""
  property string subtitle: ""
  property string valueText: ""
  property bool dimIcon: false

  implicitHeight: Math.max(heroIcon.implicitHeight, labels.implicitHeight, value.implicitHeight)

  Text {
    id: heroIcon
    anchors.left: parent.left
    anchors.verticalCenter: parent.verticalCenter
    text: root.iconText
    textFormat: Text.PlainText
    color: ShellStyle.Palette.foreground
    opacity: root.dimIcon ? 0.5 : 1
    font.family: ShellStyle.Metrics.fontFamily
    font.pixelSize: ShellStyle.Metrics.displaySize
  }

  Column {
    id: labels
    anchors.left: heroIcon.right
    anchors.leftMargin: ShellStyle.Metrics.panelGap
    anchors.right: value.visible ? value.left : parent.right
    anchors.rightMargin: value.visible ? ShellStyle.Metrics.panelGap : 0
    anchors.verticalCenter: parent.verticalCenter
    spacing: 2

    Text {
      width: parent.width
      text: root.title
      textFormat: Text.PlainText
      color: ShellStyle.Palette.foreground
      font.family: ShellStyle.Metrics.fontFamily
      font.pixelSize: ShellStyle.Metrics.titleSize
      font.bold: true
      elide: Text.ElideRight
    }

    Text {
      width: parent.width
      text: root.subtitle.toUpperCase()
      textFormat: Text.PlainText
      color: ShellStyle.Palette.muted
      font.family: ShellStyle.Metrics.fontFamily
      font.pixelSize: ShellStyle.Metrics.captionSize
      font.bold: true
      font.letterSpacing: 1.2
      elide: Text.ElideRight
    }
  }

  Text {
    id: value
    visible: root.valueText !== ""
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    text: root.valueText
    textFormat: Text.PlainText
    color: ShellStyle.Palette.foreground
    font.family: ShellStyle.Metrics.fontFamily
    font.pixelSize: ShellStyle.Metrics.displayLargeSize
    font.bold: true
  }
}
