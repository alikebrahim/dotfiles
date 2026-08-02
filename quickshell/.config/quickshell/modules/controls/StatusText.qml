import QtQuick
import "../../ui" as Ui
import "../../style" as ShellStyle

Item {
  id: root

  property string text: ""
  property string tooltipText: ""
  property bool available: true
  readonly property alias tooltipPopupVisible: popupTooltip.popupVisible
  readonly property alias tooltipPopupWindow: popupTooltip.popupWindow
  signal activated()
  signal middleActivated()

  implicitWidth: 27
  implicitHeight: ShellStyle.Metrics.barHeight
  opacity: available ? 1 : 0.48
  Accessible.role: Accessible.Button
  Accessible.name: tooltipText || text || "Status control"

  Text {
    id: label
    anchors.centerIn: parent
    text: root.text
    textFormat: Text.PlainText
    color: ShellStyle.Palette.foreground
    font.family: ShellStyle.Metrics.fontFamily
    font.pixelSize: ShellStyle.Metrics.titleSize
  }

  HoverHandler { id: hover }
  TapHandler {
    acceptedButtons: Qt.LeftButton
    onTapped: root.activated()
  }
  TapHandler {
    acceptedButtons: Qt.MiddleButton
    onTapped: root.middleActivated()
  }

  Ui.PopupToolTip {
    id: popupTooltip
    anchorItem: root
    text: root.tooltipText
    shown: hover.hovered
    delay: 500
  }
}
