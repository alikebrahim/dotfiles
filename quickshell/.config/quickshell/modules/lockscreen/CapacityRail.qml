import QtQuick
import "." as Instrument

Item {
  id: root

  property string label: "CAPACITY"
  property string valueText: "--"
  property real fraction: 0
  property color accent: Instrument.InstrumentPalette.signal
  property int segments: 18

  implicitHeight: 42

  readonly property real boundedFraction: Math.max(0, Math.min(1, fraction))

  Text {
    anchors {
      left: parent.left
      top: parent.top
    }
    text: root.label
    color: Instrument.InstrumentPalette.muted
    font {
      family: Instrument.InstrumentPalette.monoFamily
      pixelSize: 11
      letterSpacing: 1
    }
  }

  Text {
    anchors {
      right: parent.right
      top: parent.top
    }
    text: root.valueText
    color: root.accent
    font {
      family: Instrument.InstrumentPalette.monoFamily
      pixelSize: 11
      weight: Font.DemiBold
    }
  }

  Item {
    id: rail
    anchors {
      left: parent.left
      right: parent.right
      bottom: parent.bottom
    }
    height: 15

    Repeater {
      model: root.segments

      delegate: Rectangle {
        required property int index

        x: index * (rail.width / root.segments)
        width: Math.max(2, rail.width / root.segments - 3)
        height: rail.height
        color: index < Math.round(root.boundedFraction * root.segments)
          ? root.accent : Instrument.InstrumentPalette.grid
        border.color: index < Math.round(root.boundedFraction * root.segments)
          ? root.accent : Instrument.InstrumentPalette.borderDim
        border.width: 1
      }
    }
  }
}
