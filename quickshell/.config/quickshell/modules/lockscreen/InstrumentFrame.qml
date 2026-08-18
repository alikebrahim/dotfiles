import QtQuick
import "." as Instrument

Item {
  id: root

  default property alias content: body.data
  property string title: "INSTRUMENT"
  property string code: "SYS-00"
  property color accent: Instrument.InstrumentPalette.signal
  property color panelColor: Instrument.InstrumentPalette.panel
  property real headerHeight: 34

  Rectangle {
    anchors.fill: parent
    color: root.panelColor
    border.color: Instrument.InstrumentPalette.borderDim
    border.width: 1
  }

  Rectangle {
    anchors {
      left: parent.left
      right: parent.right
      top: parent.top
    }
    height: root.headerHeight
    color: Instrument.InstrumentPalette.panelRaised
  }

  Rectangle {
    anchors {
      left: parent.left
      top: parent.top
      bottom: body.top
    }
    width: 3
    color: root.accent
  }

  Rectangle {
    anchors {
      left: parent.left
      right: parent.right
      top: parent.top
    }
    height: 1
    color: root.accent
  }

  Text {
    anchors {
      left: parent.left
      leftMargin: 13
      verticalCenter: titleCode.verticalCenter
    }
    text: root.title
    color: Instrument.InstrumentPalette.text
    font {
      family: Instrument.InstrumentPalette.monoFamily
      pixelSize: 14
      letterSpacing: 1.5
      weight: Font.DemiBold
    }
  }

  Text {
    id: titleCode
    anchors {
      right: parent.right
      rightMargin: 11
      top: parent.top
      topMargin: 10
    }
    text: root.code
    color: root.accent
    font {
      family: Instrument.InstrumentPalette.monoFamily
      pixelSize: 11
      letterSpacing: 1
    }
  }

  Item {
    id: body
    anchors {
      left: parent.left
      right: parent.right
      top: parent.top
      topMargin: root.headerHeight
      bottom: parent.bottom
    }
    clip: true
  }
}
