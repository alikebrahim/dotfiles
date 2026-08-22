import QtQuick
import Quickshell

PanelWindow {
  id: root

  property int panelSize: 32
  property bool reserveSpace: true
  property string wmName: "quickshell-shell"

  anchors {
    top: true
    left: true
    right: true
  }

  implicitHeight: panelSize
  color: "transparent"
  surfaceFormat.opaque: false
  focusable: false
  aboveWindows: true
  exclusiveZone: reserveSpace && visible ? panelSize : 0

  Binding {
    target: root.contentItem.Window.window
    property: "title"
    value: root.wmName
    when: root.contentItem.Window.window !== null
  }
}
