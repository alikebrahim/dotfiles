import QtQuick
import "../../style" as ShellStyle

Item {
  id: root

  property string title: ""
  readonly property string displayText: title

  visible: title !== ""
  implicitWidth: title === "" ? 0 : Math.min(320, Math.ceil(titleMetrics.advanceWidth) + ShellStyle.Metrics.sectionGap)
  implicitHeight: ShellStyle.Metrics.barHeight

  TextMetrics {
    id: titleMetrics
    text: root.displayText
    font.family: ShellStyle.Metrics.fontFamily
    font.pixelSize: ShellStyle.Metrics.smallTextSize
  }

  Text {
    id: label
    anchors.fill: parent
    anchors.leftMargin: ShellStyle.Metrics.sectionGap
    text: root.displayText
    textFormat: Text.PlainText
    color: ShellStyle.Palette.foreground
    opacity: 0.85
    font.family: ShellStyle.Metrics.fontFamily
    font.pixelSize: ShellStyle.Metrics.smallTextSize
    verticalAlignment: Text.AlignVCenter
    elide: Text.ElideRight
  }

  Behavior on implicitWidth {
    NumberAnimation { duration: ShellStyle.Metrics.animationMs }
  }
}
