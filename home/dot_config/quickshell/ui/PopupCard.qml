import QtQuick
import "../style" as ShellStyle

// Inner card for BarPopoutHost. The host window is already below the bar
// (PanelWindow margins.top), so layout y stays 0. Visual parent is the host
// card layer — not the bar widget — so Qt does not keep the bar's scene Y.
Item {
  id: root

  property var host: null
  property Item anchorItem: null
  property bool open: false
  property bool animateTransitions: true
  property real cardOpacity: open ? 1 : 0
  property int cardWidth: 380
  property int cardHeight: 240
  property int cardRadius: 6
  property int padding: ShellStyle.Metrics.panelPadding
  property color cardColor: "#f2101315"
  property color borderColor: "#b3d7c9bd"
  property bool lockSizeWhileOpen: false
  property int maxCardHeight: 0
  property string placement: "anchor"
  property var screen: null

  default property alias content: contentHolder.data
  property alias cardBackground: cardBackground

  parent: host && host.cardLayer ? host.cardLayer : null
  implicitWidth: 0
  implicitHeight: 0
  width: Math.max(1, cardWidth)
  height: Math.max(1, cardHeight)
  z: open ? 1 : 0
  visible: (open || cardOpacity > 0) && host && host.cardLayer
  opacity: cardOpacity

  function contentX() {
    if (!host) return 0

    var inset = ShellStyle.Metrics.edgeInset
    var w = Math.max(1, cardWidth)
    var hostW = Math.max(w + inset * 2, host.width)

    if (placement === "center")
      return Math.round((hostW - w) / 2)
    if (placement === "right" || !anchorItem)
      return Math.max(inset, hostW - inset - w)
    if (anchorItem && host.cardLayer && typeof anchorItem.mapToGlobal === "function") {
      var globalPos = anchorItem.mapToGlobal(0, 0)
      var local = host.cardLayer.mapFromGlobal(globalPos.x, globalPos.y)
      var center = local.x + anchorItem.width / 2
      var xPos = Math.round(center - w / 2)
      return Math.max(inset, Math.min(xPos, hostW - inset - w))
    }
    return Math.max(inset, hostW - inset - w)
  }

  function applyPosition() {
    if (!host || !host.cardLayer || parent !== host.cardLayer) return
    x = contentX()
    y = 0
  }

  onHostChanged: applyPosition()
  onParentChanged: applyPosition()
  onOpenChanged: {
    if (open) {
      applyPosition()
      Qt.callLater(applyPosition)
      if (host) host.setActiveCard(root)
    }
  }
  onCardWidthChanged: if (open || visible) applyPosition()
  onPlacementChanged: if (open || visible) applyPosition()
  onAnchorItemChanged: if (open || visible) applyPosition()
  Component.onCompleted: {
    if (open && host) host.setActiveCard(root)
    applyPosition()
  }

  Connections {
    target: root.host
    enabled: root.host !== null
    function onWidthChanged() { root.applyPosition() }
  }

  Behavior on cardOpacity {
    enabled: root.animateTransitions
    NumberAnimation {
      duration: ShellStyle.Metrics.animationMs
      easing.type: Easing.OutCubic
    }
  }

  Rectangle {
    id: cardBackground
    anchors.fill: parent
    radius: root.cardRadius
    color: root.cardColor
    border.width: 2
    border.color: root.borderColor

    Item {
      id: contentHolder
      anchors.fill: parent
      anchors.margins: root.padding
    }
  }
}
