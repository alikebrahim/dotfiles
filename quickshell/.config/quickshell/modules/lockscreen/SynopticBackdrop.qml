import QtQuick
import "." as Instrument

Canvas {
  id: root

  property var busSegments: []

  onBusSegmentsChanged: requestPaint()
  onWidthChanged: requestPaint()
  onHeightChanged: requestPaint()

  onPaint: {
    var context = getContext("2d")
    context.clearRect(0, 0, width, height)

    context.strokeStyle = Instrument.InstrumentPalette.grid
    context.lineWidth = 1
    context.globalAlpha = 0.42
    for (var column = 0; column <= 240; column += 5) {
      var x = Math.round(column * width / 240) + 0.5
      context.beginPath()
      context.moveTo(x, 0)
      context.lineTo(x, height)
      context.stroke()
    }
    for (var row = 0; row <= 67; row += 4) {
      var y = Math.round(row * height / 67) + 0.5
      context.beginPath()
      context.moveTo(0, y)
      context.lineTo(width, y)
      context.stroke()
    }

    context.globalAlpha = 0.08
    context.strokeStyle = Instrument.InstrumentPalette.signal
    for (var scan = 1; scan < height; scan += 4) {
      context.beginPath()
      context.moveTo(0, scan + 0.5)
      context.lineTo(width, scan + 0.5)
      context.stroke()
    }

    context.globalAlpha = 0.8
    context.strokeStyle = Instrument.InstrumentPalette.signal
    context.lineWidth = 2
    for (var index = 0; index < root.busSegments.length; index++) {
      var segment = root.busSegments[index]
      if (!segment || segment.length < 4) continue
      context.beginPath()
      context.moveTo(segment[0] * width, segment[1] * height)
      context.lineTo(segment[2] * width, segment[3] * height)
      context.stroke()
      context.fillStyle = Instrument.InstrumentPalette.nominal
      context.beginPath()
      context.arc(segment[2] * width, segment[3] * height, 3, 0, Math.PI * 2)
      context.fill()
    }
    context.globalAlpha = 1
  }
}
