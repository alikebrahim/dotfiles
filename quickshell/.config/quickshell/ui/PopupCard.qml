import QtQuick
import Quickshell
import "../style" as ShellStyle

PanelWindow {
  id: root

  property bool open: false
  property bool animateTransitions: true
  property real cardOpacity: open ? 1 : 0
  property int cardWidth: 380
  property int cardHeight: 240
  property int cardRadius: 6
  property int padding: ShellStyle.Metrics.panelPadding
  property color cardColor: "#f2101315"
  property color borderColor: "#b3d7c9bd"

  default property alias content: contentHolder.data

  anchors {
    top: true
    right: true
  }

  margins {
    top: 34
    right: 8
  }

  visible: open || cardOpacity > 0
  implicitWidth: cardWidth
  implicitHeight: cardHeight
  color: "transparent"
  surfaceFormat.opaque: false
  focusable: open
  aboveWindows: true
  exclusionMode: ExclusionMode.Ignore
  exclusiveZone: 0

  Behavior on cardOpacity {
    enabled: root.animateTransitions
    NumberAnimation {
      duration: ShellStyle.Metrics.animationMs
      easing.type: Easing.OutCubic
    }
  }

  Rectangle {
    anchors.fill: parent
    opacity: root.cardOpacity
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
