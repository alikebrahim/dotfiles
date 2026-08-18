import QtQuick
import "." as Instrument

Item {
  id: root

  property string label: "PRESSURE"
  property string valueText: "0.00"
  property string unitText: "AVG10"
  property real fraction: 0
  property color accent: Instrument.InstrumentPalette.nominal

  implicitWidth: 132
  implicitHeight: 72

  Rectangle {
    anchors.fill: parent
    color: Instrument.InstrumentPalette.panelRaised
    border.color: root.accent
    border.width: 1
  }

  Rectangle {
    anchors {
      left: parent.left
      bottom: parent.bottom
    }
    width: 3
    height: Math.max(3, parent.height * Math.max(0, Math.min(1, root.fraction)))
    color: root.accent
  }

  Text {
    anchors {
      left: parent.left
      leftMargin: 11
      top: parent.top
      topMargin: 9
    }
    text: root.label
    color: Instrument.InstrumentPalette.muted
    font {
      family: Instrument.InstrumentPalette.monoFamily
      pixelSize: 10
      letterSpacing: 1
    }
  }

  Text {
    anchors {
      left: parent.left
      leftMargin: 11
      bottom: parent.bottom
      bottomMargin: 9
    }
    text: root.valueText
    color: root.accent
    font {
      family: Instrument.InstrumentPalette.monoFamily
      pixelSize: 19
      weight: Font.DemiBold
    }
  }

  Text {
    anchors {
      right: parent.right
      rightMargin: 9
      bottom: parent.bottom
      bottomMargin: 11
    }
    text: root.unitText
    color: Instrument.InstrumentPalette.border
    font {
      family: Instrument.InstrumentPalette.monoFamily
      pixelSize: 9
    }
  }
}
