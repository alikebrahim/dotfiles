import QtQuick
import Quickshell
import "../style" as ShellStyle

Item {
  id: root

  property Item anchorItem: parent
  property string text: ""
  property bool shown: false
  property int delay: 500
  property int maxWidth: 320
  property bool delayedShown: false
  readonly property bool popupVisible: popupLoader.item !== null && popupLoader.item.visible
  readonly property var popupWindow: popupLoader.item

  implicitWidth: 0
  implicitHeight: 0

  function updateVisibility() {
    showDelay.stop()
    if (!shown || text === "") {
      delayedShown = false
    } else if (delay <= 0) {
      delayedShown = true
    } else {
      showDelay.restart()
    }
  }

  onShownChanged: updateVisibility()
  onTextChanged: updateVisibility()
  onDelayChanged: updateVisibility()
  Component.onCompleted: updateVisibility()

  Timer {
    id: showDelay
    interval: Math.max(1, root.delay)
    repeat: false
    onTriggered: root.delayedShown = root.shown && root.text !== ""
  }

  Loader {
    id: popupLoader
    active: root.delayedShown && root.anchorItem !== null

    sourceComponent: PopupWindow {
      id: popup

      visible: true
      grabFocus: false
      color: "transparent"
      implicitWidth: Math.min(root.maxWidth, label.implicitWidth + 18)
      implicitHeight: label.implicitHeight + 10

      anchor {
        item: root.anchorItem
        edges: Edges.Bottom | Edges.Right
        gravity: Edges.Bottom | Edges.Left
        adjustment: PopupAdjustment.FlipY | PopupAdjustment.SlideX
      }

      mask: Region { item: null }

      Rectangle {
        anchors.fill: parent
        radius: ShellStyle.Metrics.cornerRadius
        color: ShellStyle.Palette.panel
        border.width: 1
        border.color: ShellStyle.Palette.panelBorder

        Text {
          id: label
          anchors.centerIn: parent
          width: Math.max(0, parent.width - 18)
          text: root.text
          textFormat: Text.PlainText
          color: ShellStyle.Palette.foreground
          font.family: ShellStyle.Metrics.fontFamily
          font.pixelSize: ShellStyle.Metrics.bodySize
          horizontalAlignment: Text.AlignHCenter
          elide: Text.ElideRight
        }
      }
    }
  }
}
