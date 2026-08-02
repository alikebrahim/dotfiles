import QtQuick
import Quickshell.Services.SystemTray as Tray
import "../../ui" as Ui
import "../../style" as ShellStyle

Item {
  id: root

  required property var trayItem

  readonly property string itemTitle: trayItem
    ? String(trayItem.title || trayItem.id || "Tray item")
    : "Tray item"
  readonly property string itemDescription: trayItem
    ? String(trayItem.tooltipDescription || "")
    : ""
  readonly property string iconSource: trayItem ? String(trayItem.icon || "") : ""
  readonly property bool needsAttention: trayItem
    && trayItem.status === Tray.Status.NeedsAttention

  signal primaryRequested(var item)
  signal menuRequested(var item)
  signal secondaryRequested(var item)
  signal scrollRequested(var item, int delta, bool horizontal)

  implicitWidth: ShellStyle.Metrics.trayIconSlot
  implicitHeight: ShellStyle.Metrics.barHeight
  Accessible.role: Accessible.Button
  Accessible.name: itemDescription !== ""
    ? itemTitle + ", " + itemDescription
    : itemTitle

  Rectangle {
    anchors.centerIn: parent
    width: ShellStyle.Metrics.trayIconSlot - 2
    height: width
    radius: ShellStyle.Metrics.cornerRadius
    color: root.needsAttention
      ? ShellStyle.Palette.urgent
      : hover.hovered ? ShellStyle.Palette.hoverWash : ShellStyle.Palette.transparent
  }

  Image {
    id: icon
    anchors.centerIn: parent
    width: ShellStyle.Metrics.trayIconSize
    height: width
    source: root.iconSource
    fillMode: Image.PreserveAspectFit
    asynchronous: true
    smooth: true
    visible: root.iconSource !== "" && status !== Image.Error
  }

  Text {
    anchors.centerIn: parent
    visible: !icon.visible
    text: root.itemTitle.length > 0 ? root.itemTitle.charAt(0).toUpperCase() : "•"
    textFormat: Text.PlainText
    color: ShellStyle.Palette.foreground
    font.family: ShellStyle.Metrics.fontFamily
    font.pixelSize: ShellStyle.Metrics.bodySmallSize
  }

  HoverHandler { id: hover }

  MouseArea {
    anchors.fill: parent
    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

    onClicked: function(mouse) {
      if (!root.trayItem) return
      if (mouse.button === Qt.RightButton) {
        root.menuRequested(root.trayItem)
      } else if (mouse.button === Qt.MiddleButton) {
        root.secondaryRequested(root.trayItem)
      } else {
        root.primaryRequested(root.trayItem)
      }
    }

    onWheel: function(wheel) {
      if (!root.trayItem) return
      if (wheel.angleDelta.y !== 0)
        root.scrollRequested(root.trayItem, wheel.angleDelta.y, false)
      else if (wheel.angleDelta.x !== 0)
        root.scrollRequested(root.trayItem, wheel.angleDelta.x, true)
      wheel.accepted = true
    }
  }

  Ui.PopupToolTip {
    anchorItem: root
    text: root.itemDescription !== ""
      ? root.itemTitle + " — " + root.itemDescription
      : root.itemTitle
    shown: hover.hovered
    delay: 500
  }
}
