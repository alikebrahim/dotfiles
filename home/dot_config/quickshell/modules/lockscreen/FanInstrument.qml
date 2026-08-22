import QtQuick
import "." as Instrument

Item {
  id: root

  property string label: "FAN"
  property real rpm: 0
  property real temperatureC: 0
  property real rotorPhase: 0
  property color accent: Instrument.InstrumentPalette.signal

  onRpmChanged: dial.requestPaint()
  onTemperatureCChanged: dial.requestPaint()
  onRotorPhaseChanged: dial.requestPaint()
  onAccentChanged: dial.requestPaint()

  Canvas {
    id: dial
    anchors {
      left: parent.left
      right: parent.right
      top: parent.top
      bottom: readout.top
      bottomMargin: 5
    }

    onPaint: {
      var context = getContext("2d")
      context.clearRect(0, 0, width, height)
      var cx = width / 2
      var cy = height / 2
      var radius = Math.max(10, Math.min(width, height) * 0.41)

      context.lineWidth = 1
      context.strokeStyle = Instrument.InstrumentPalette.borderDim
      context.beginPath()
      context.arc(cx, cy, radius, 0, Math.PI * 2)
      context.stroke()

      context.strokeStyle = root.accent
      context.lineWidth = 2
      context.beginPath()
      context.arc(cx, cy, radius - 5, -Math.PI * 0.8, Math.PI * 0.55)
      context.stroke()

      context.save()
      context.translate(cx, cy)
      context.rotate(root.rotorPhase)
      for (var blade = 0; blade < 6; blade++) {
        context.save()
        context.rotate(blade * Math.PI / 3)
        context.beginPath()
        context.moveTo(4, -3)
        context.bezierCurveTo(radius * 0.24, -radius * 0.08, radius * 0.58, -radius * 0.26, radius * 0.66, -4)
        context.bezierCurveTo(radius * 0.48, radius * 0.13, radius * 0.20, radius * 0.12, 4, 3)
        context.closePath()
        context.fillStyle = blade % 2 === 0 ? root.accent : Instrument.InstrumentPalette.border
        context.fill()
        context.restore()
      }
      context.fillStyle = Instrument.InstrumentPalette.background
      context.strokeStyle = root.accent
      context.lineWidth = 2
      context.beginPath()
      context.arc(0, 0, Math.max(5, radius * 0.12), 0, Math.PI * 2)
      context.fill()
      context.stroke()
      context.restore()

      context.fillStyle = Instrument.InstrumentPalette.muted
      context.font = "10px monospace"
      context.fillText("0", cx - radius - 2, cy + radius + 1)
      context.fillText("MAX", cx + radius - 18, cy + radius + 1)
    }
  }

  Item {
    id: readout
    anchors {
      left: parent.left
      right: parent.right
      bottom: parent.bottom
    }
    height: 39

    Text {
      anchors {
        left: parent.left
        verticalCenter: parent.verticalCenter
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
      text: Math.round(root.rpm).toLocaleString(Qt.locale("en_US"), "f", 0) + " RPM"
      color: root.accent
      font {
        family: Instrument.InstrumentPalette.monoFamily
        pixelSize: 14
        weight: Font.DemiBold
      }
    }

    Text {
      anchors {
        right: parent.right
        bottom: parent.bottom
      }
      text: root.temperatureC.toFixed(1) + "°C"
      color: Instrument.InstrumentPalette.secondaryText
      font {
        family: Instrument.InstrumentPalette.monoFamily
        pixelSize: 11
      }
    }
  }
}
