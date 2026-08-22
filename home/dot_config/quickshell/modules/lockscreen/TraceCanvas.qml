import QtQuick
import "." as Instrument

Item {
  id: root

  property var values: []
  property var secondaryValues: []
  property color lineColor: Instrument.InstrumentPalette.signal
  property color secondaryColor: Instrument.InstrumentPalette.compute
  property color gridColor: Instrument.InstrumentPalette.grid
  property bool fillPrimary: false

  onValuesChanged: plot.requestPaint()
  onSecondaryValuesChanged: plot.requestPaint()
  onLineColorChanged: plot.requestPaint()
  onSecondaryColorChanged: plot.requestPaint()
  onWidthChanged: plot.requestPaint()
  onHeightChanged: plot.requestPaint()

  function drawSeries(context, series, color, fill) {
    if (!series || series.length < 2) return
    var left = 4
    var top = 4
    var usableWidth = Math.max(1, width - 8)
    var usableHeight = Math.max(1, height - 8)
    context.beginPath()
    var started = false
    for (var index = 0; index < series.length; index++) {
      var value = Number(series[index])
      if (!isFinite(value)) continue
      var x = left + usableWidth * index / Math.max(1, series.length - 1)
      var y = top + usableHeight * (1 - Math.max(0, Math.min(1, value)))
      if (!started) {
        context.moveTo(x, y)
        started = true
      } else {
        context.lineTo(x, y)
      }
    }
    if (!started) return
    context.strokeStyle = color
    context.lineWidth = 2
    context.stroke()
    if (fill) {
      context.lineTo(left + usableWidth, top + usableHeight)
      context.lineTo(left, top + usableHeight)
      context.closePath()
      context.globalAlpha = 0.10
      context.fillStyle = color
      context.fill()
      context.globalAlpha = 1
    }
  }

  Canvas {
    id: plot
    anchors.fill: parent

    onPaint: {
      var context = getContext("2d")
      context.clearRect(0, 0, width, height)
      context.strokeStyle = root.gridColor
      context.lineWidth = 1
      for (var vertical = 0; vertical <= 6; vertical++) {
        var x = Math.round(vertical * width / 6) + 0.5
        context.beginPath()
        context.moveTo(x, 0)
        context.lineTo(x, height)
        context.stroke()
      }
      for (var horizontal = 0; horizontal <= 3; horizontal++) {
        var y = Math.round(horizontal * height / 3) + 0.5
        context.beginPath()
        context.moveTo(0, y)
        context.lineTo(width, y)
        context.stroke()
      }
      root.drawSeries(context, root.values, root.lineColor, root.fillPrimary)
      root.drawSeries(context, root.secondaryValues, root.secondaryColor, false)
    }
  }
}
