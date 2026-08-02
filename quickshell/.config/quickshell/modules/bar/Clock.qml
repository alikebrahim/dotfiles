import QtQuick
import Quickshell
import "../../style" as ShellStyle

Item {
  id: root

  signal activated()

  property date displayDate: clock.date
  readonly property string text: Qt.formatDateTime(displayDate, "ddd dd MMM - HH:mm")

  implicitWidth: label.implicitWidth
  implicitHeight: ShellStyle.Metrics.barHeight
  Accessible.role: Accessible.Button
  Accessible.name: "Calendar, " + text

  SystemClock {
    id: clock
    precision: SystemClock.Minutes
    onDateChanged: root.displayDate = date
  }

  Text {
    id: label
    anchors.centerIn: parent
    text: root.text
    textFormat: Text.PlainText
    color: clockMouse.containsMouse
      ? ShellStyle.Palette.accent
      : ShellStyle.Palette.foreground
    font.family: ShellStyle.Metrics.fontFamily
    font.pixelSize: ShellStyle.Metrics.textSize
    font.weight: Font.Medium
  }

  MouseArea {
    id: clockMouse
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: root.activated()
  }
}
