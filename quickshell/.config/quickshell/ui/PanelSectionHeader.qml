import QtQuick
import "../style" as ShellStyle

Text {
  property string label: ""
  text: label.toUpperCase()
  textFormat: Text.PlainText
  color: ShellStyle.Palette.muted
  font.family: ShellStyle.Metrics.fontFamily
  font.pixelSize: ShellStyle.Metrics.captionSize
  font.bold: true
  font.letterSpacing: 1.2
}
