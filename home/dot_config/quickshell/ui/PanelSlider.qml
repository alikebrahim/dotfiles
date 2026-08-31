import QtQuick
import "../style" as ShellStyle

// Compact slider. Changes are previewed locally and committed only on release
// so native commands are never spammed while dragging.
Item {
  id: root

  property real minimum: 0
  property real maximum: 100
  property real value: 0
  property real previewValue: -1
  property bool enabled: true
  property bool hasCursor: false
  property string accessibleName: "Value"
  readonly property real displayValue: previewValue >= minimum ? previewValue : value
  readonly property real fraction: maximum > minimum ? Math.max(0, Math.min(1, (displayValue - minimum) / (maximum - minimum))) : 0
  signal committed(real value)
  signal hovered(bool value)

  implicitHeight: 28
  opacity: enabled ? 1 : 0.42
  Accessible.role: Accessible.Slider
  Accessible.name: accessibleName + ": " + Math.round(displayValue)

  Rectangle {
    id: track
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    height: 6
    radius: height / 2
    color: ShellStyle.Palette.track

    Rectangle {
      width: parent.width * root.fraction
      height: parent.height
      radius: parent.radius
      color: ShellStyle.Palette.foreground
    }
  }

  Rectangle {
    anchors.verticalCenter: track.verticalCenter
    x: Math.max(0, Math.min(root.width - width, root.fraction * root.width - width / 2))
    width: 12
    height: 12
    radius: width / 2
    color: ShellStyle.Palette.foreground
    border.width: root.hasCursor || pointer.containsMouse ? 2 : 0
    border.color: ShellStyle.Palette.accent
  }

  function valueAt(x) {
    if (width <= 0) return minimum
    return Math.max(minimum, Math.min(maximum, minimum + (maximum - minimum) * x / width))
  }

  MouseArea {
    id: pointer
    anchors.fill: parent
    enabled: root.enabled
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onEntered: root.hovered(true)
    onExited: root.hovered(false)
    onPressed: function(mouse) { root.previewValue = root.valueAt(mouse.x) }
    onPositionChanged: function(mouse) {
      if (pressed) root.previewValue = root.valueAt(mouse.x)
    }
    onReleased: {
      var committedValue = root.previewValue
      root.previewValue = -1
      root.committed(committedValue)
    }
    onCanceled: root.previewValue = -1
  }
}
