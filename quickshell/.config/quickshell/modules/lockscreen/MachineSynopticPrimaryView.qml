import QtQuick
import "." as Instrument

Item {
  id: root

  property var telemetry: emptyTelemetry()
  property var history: []
  property string clockText: "--:--:--"
  property string durationText: "T+00:00"
  property string telemetryHealth: "acquiring"
  property bool lockMode: false
  property string lockState: "closed"
  property bool capsLockActive: false
  property bool inputRejected: false
  property int rejectionSequence: 0
  property real rejectionPulse: 0
  property real cpuRotorPhase: 0.25
  property real gpuRotorPhase: 0.82

  readonly property var cpuHistory: normalizedHistory("cpuUtilization", 100)
  readonly property var gpuHistory: normalizedHistory("gpuUtilization", 100)
  readonly property var networkHistory: normalizedHistory("networkBps", 0)
  readonly property var diskHistory: normalizedHistory("diskBps", 0)

  function gx(columns) { return width * columns / 240 }
  function gy(rows) { return height * rows / 67 }

  function emptyTelemetry() {
    return {
      cpu: {}, gpu: {}, memory: {}, io: {}, thermal: {}, power: {}, time: {}, freshness: {}
    }
  }

  function finite(value) {
    return typeof value === "number" && isFinite(value)
  }

  function percent(value) {
    return finite(value) ? value.toFixed(0) : "--"
  }

  function decimal(value, digits) {
    return finite(value) ? value.toFixed(digits) : "--"
  }

  function temperature(value) {
    return finite(value) ? value.toFixed(1) + "°C" : "--.-°C"
  }

  function rate(value) {
    if (!finite(value)) return "--"
    var units = ["B/s", "KiB/s", "MiB/s", "GiB/s"]
    var scaled = value
    var unit = 0
    while (scaled >= 1024 && unit < units.length - 1) {
      scaled /= 1024
      unit++
    }
    return (scaled >= 100 ? scaled.toFixed(0) : scaled.toFixed(1)) + " " + units[unit]
  }

  function capacity(used, total) {
    if (!finite(used) || !finite(total) || total <= 0) return "-- / --"
    return (used / 1073741824).toFixed(1) + " / " + (total / 1073741824).toFixed(1) + " GiB"
  }

  function ratio(used, total) {
    return finite(used) && finite(total) && total > 0 ? used / total : 0
  }

  function normalizedHistory(field, fixedMaximum) {
    if (!Array.isArray(history) || history.length === 0) return []
    var values = []
    var maximum = fixedMaximum
    for (var index = 0; index < history.length; index++) {
      var value = Number(history[index][field])
      if (!isFinite(value)) continue
      values.push(value)
      if (fixedMaximum <= 0) maximum = Math.max(maximum, value)
    }
    maximum = Math.max(1, maximum)
    return values.map(function(value) { return Math.max(0, Math.min(1, value / maximum)) })
  }

  function freshness(group) {
    var state = telemetry.freshness && telemetry.freshness[group]
      ? telemetry.freshness[group].state : "unavailable"
    return String(state).toUpperCase()
  }

  function healthColor() {
    if (telemetryHealth === "nominal") return Instrument.InstrumentPalette.nominal
    if (telemetryHealth === "stale" || telemetryHealth === "degraded")
      return Instrument.InstrumentPalette.warning
    return Instrument.InstrumentPalette.critical
  }

  onRejectionSequenceChanged: {
    if (rejectionSequence > 0) rejectionAnimation.restart()
  }

  SequentialAnimation {
    id: rejectionAnimation
    loops: 2
    NumberAnimation {
      target: root
      property: "rejectionPulse"
      from: 0
      to: 1
      duration: 90
      easing.type: Easing.OutCubic
    }
    NumberAnimation {
      target: root
      property: "rejectionPulse"
      from: 1
      to: 0
      duration: 170
      easing.type: Easing.InCubic
    }
  }

  Rectangle {
    anchors.fill: parent
    color: Instrument.InstrumentPalette.background
  }

  Instrument.SynopticBackdrop {
    anchors.fill: parent
    busSegments: [
      [0.230, 0.405, 0.250, 0.405],
      [0.555, 0.405, 0.570, 0.405],
      [0.770, 0.405, 0.785, 0.405],
      [0.500, 0.685, 0.500, 0.725]
    ]
  }

  Rectangle {
    x: root.gx(4)
    y: root.gy(1.4)
    width: root.gx(232)
    height: root.gy(4.1)
    color: Instrument.InstrumentPalette.panelRaised
    border.color: Instrument.InstrumentPalette.border
    border.width: 1

    Rectangle {
      anchors {
        left: parent.left
        top: parent.top
        bottom: parent.bottom
      }
      width: 5
      color: Instrument.InstrumentPalette.signal
    }

    Text {
      anchors {
        left: parent.left
        leftMargin: 18
        verticalCenter: parent.verticalCenter
      }
      text: "MACHINE SYNOPTIC  //  FLIGHT SYSTEMS INSTRUMENTATION"
      color: Instrument.InstrumentPalette.text
      font {
        family: Instrument.InstrumentPalette.monoFamily
        pixelSize: 17
        letterSpacing: 2
        weight: Font.DemiBold
      }
    }

    Row {
      anchors.centerIn: parent
      spacing: 10

      Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: 8
        height: 8
        radius: 4
        color: root.healthColor()
      }

      Text {
        text: "TELEMETRY " + root.telemetryHealth.toUpperCase()
        color: root.healthColor()
        font {
          family: Instrument.InstrumentPalette.monoFamily
          pixelSize: 11
          letterSpacing: 1.2
        }
      }
    }

    Text {
      anchors {
        right: parent.right
        rightMargin: 17
        verticalCenter: parent.verticalCenter
      }
      text: root.clockText + "  //  " + root.durationText
      color: Instrument.InstrumentPalette.signal
      font {
        family: Instrument.InstrumentPalette.monoFamily
        pixelSize: 16
        letterSpacing: 1.5
      }
    }
  }

  Instrument.InstrumentFrame {
    x: root.gx(4)
    y: root.gy(6.6)
    width: root.gx(51)
    height: root.gy(39.4)
    title: "COOLING LOOP"
    code: "THM-01"
    accent: Instrument.InstrumentPalette.signal

    Instrument.FanInstrument {
      x: parent.width * 0.045
      y: 12
      width: parent.width * 0.42
      height: 205
      label: "CPU IMPELLER"
      rpm: root.finite(root.telemetry.thermal.cpuFanRpm) ? root.telemetry.thermal.cpuFanRpm : 0
      temperatureC: root.finite(root.telemetry.cpu.packageTempC) ? root.telemetry.cpu.packageTempC : 0
      rotorPhase: root.cpuRotorPhase
      accent: Instrument.InstrumentPalette.signal
    }

    Instrument.FanInstrument {
      x: parent.width * 0.535
      y: 12
      width: parent.width * 0.42
      height: 205
      label: "GPU IMPELLER"
      rpm: root.finite(root.telemetry.thermal.gpuFanRpm) ? root.telemetry.thermal.gpuFanRpm : 0
      temperatureC: root.finite(root.telemetry.gpu.temperatureC) ? root.telemetry.gpu.temperatureC : 0
      rotorPhase: root.gpuRotorPhase
      accent: Instrument.InstrumentPalette.compute
    }

    Text {
      x: 17
      y: 225
      text: "THERMAL ENVELOPE"
      color: Instrument.InstrumentPalette.secondaryText
      font {
        family: Instrument.InstrumentPalette.monoFamily
        pixelSize: 11
        letterSpacing: 1.5
      }
    }

    Instrument.CapacityRail {
      x: 17
      y: 251
      width: parent.width - 34
      label: "CPU PACKAGE"
      valueText: root.temperature(root.telemetry.cpu.packageTempC)
      fraction: root.finite(root.telemetry.cpu.packageTempC) ? root.telemetry.cpu.packageTempC / 100 : 0
      accent: Instrument.InstrumentPalette.signal
    }

    Instrument.CapacityRail {
      x: 17
      y: 301
      width: parent.width - 34
      label: "GPU DIE"
      valueText: root.temperature(root.telemetry.gpu.temperatureC)
      fraction: root.finite(root.telemetry.gpu.temperatureC) ? root.telemetry.gpu.temperatureC / 100 : 0
      accent: Instrument.InstrumentPalette.compute
    }

    Instrument.CapacityRail {
      x: 17
      y: 351
      width: parent.width - 34
      label: "NVME MAX // DIMM MAX"
      valueText: root.temperature(root.telemetry.thermal.nvmeMaxC)
        + "  //  " + root.temperature(root.telemetry.thermal.dimmMaxC)
      fraction: Math.max(
        root.finite(root.telemetry.thermal.nvmeMaxC) ? root.telemetry.thermal.nvmeMaxC / 90 : 0,
        root.finite(root.telemetry.thermal.dimmMaxC) ? root.telemetry.thermal.dimmMaxC / 90 : 0)
      accent: Instrument.InstrumentPalette.nominal
    }

    Text {
      x: 17
      y: parent.height - 28
      text: "SENSOR BUS  " + root.freshness("thermal")
      color: root.freshness("thermal") === "NOMINAL"
        ? Instrument.InstrumentPalette.nominal : Instrument.InstrumentPalette.warning
      font {
        family: Instrument.InstrumentPalette.monoFamily
        pixelSize: 9
        letterSpacing: 1
      }
    }
  }

  Instrument.InstrumentFrame {
    x: root.gx(58)
    y: root.gy(6.6)
    width: root.gx(75)
    height: root.gy(39.4)
    title: "COMPUTE CHAMBER"
    code: "CPU-32"
    accent: Instrument.InstrumentPalette.compute

    Text {
      x: 18
      y: 14
      text: root.percent(root.telemetry.cpu.utilization)
      color: Instrument.InstrumentPalette.text
      font {
        family: Instrument.InstrumentPalette.monoFamily
        pixelSize: 64
        weight: Font.Light
      }
    }

    Text {
      x: 139
      y: 51
      text: "% LOAD"
      color: Instrument.InstrumentPalette.compute
      font {
        family: Instrument.InstrumentPalette.monoFamily
        pixelSize: 13
        letterSpacing: 1.5
      }
    }

    Text {
      x: 18
      y: 91
      text: root.decimal(root.telemetry.cpu.frequencyMhz, 0) + " MHz"
      color: Instrument.InstrumentPalette.signal
      font {
        family: Instrument.InstrumentPalette.monoFamily
        pixelSize: 16
      }
    }

    Text {
      x: 166
      y: 91
      text: root.temperature(root.telemetry.cpu.packageTempC)
      color: Instrument.InstrumentPalette.warning
      font {
        family: Instrument.InstrumentPalette.monoFamily
        pixelSize: 16
      }
    }

    Instrument.TraceCanvas {
      x: 286
      y: 18
      width: parent.width - 305
      height: 100
      values: root.cpuHistory
      secondaryValues: root.gpuHistory
      lineColor: Instrument.InstrumentPalette.compute
      secondaryColor: Instrument.InstrumentPalette.signal
      fillPrimary: true
    }

    Text {
      x: 286
      y: 124
      text: "60s ACTIVITY VECTOR  CPU // GPU"
      color: Instrument.InstrumentPalette.muted
      font {
        family: Instrument.InstrumentPalette.monoFamily
        pixelSize: 10
        letterSpacing: 1
      }
    }

    Instrument.CapacityRail {
      x: 18
      y: 157
      width: parent.width - 36
      label: "RAM RESERVOIR"
      valueText: root.capacity(root.telemetry.memory.ramUsedBytes, root.telemetry.memory.ramTotalBytes)
      fraction: root.ratio(root.telemetry.memory.ramUsedBytes, root.telemetry.memory.ramTotalBytes)
      accent: Instrument.InstrumentPalette.compute
    }

    Instrument.CapacityRail {
      x: 18
      y: 209
      width: parent.width - 36
      label: "SWAP RESERVOIR"
      valueText: root.capacity(root.telemetry.memory.swapUsedBytes, root.telemetry.memory.swapTotalBytes)
      fraction: root.ratio(root.telemetry.memory.swapUsedBytes, root.telemetry.memory.swapTotalBytes)
      accent: Instrument.InstrumentPalette.auxiliary
    }

    Text {
      x: 18
      y: 265
      text: "STALL PRESSURE // LINEAR AVG10"
      color: Instrument.InstrumentPalette.secondaryText
      font {
        family: Instrument.InstrumentPalette.monoFamily
        pixelSize: 11
        letterSpacing: 1.5
      }
    }

    Instrument.PressureCell {
      x: 18
      y: 292
      width: (parent.width - 52) / 3
      label: "CPU SOME"
      valueText: root.decimal(root.telemetry.cpu.pressureSome, 2)
      fraction: root.finite(root.telemetry.cpu.pressureSome) ? root.telemetry.cpu.pressureSome / 10 : 0
      accent: root.finite(root.telemetry.cpu.pressureSome) && root.telemetry.cpu.pressureSome > 1
        ? Instrument.InstrumentPalette.warning : Instrument.InstrumentPalette.nominal
    }

    Instrument.PressureCell {
      x: 26 + (parent.width - 52) / 3
      y: 292
      width: (parent.width - 52) / 3
      label: "MEM SOME"
      valueText: root.decimal(root.telemetry.memory.pressureSome, 2)
      fraction: root.finite(root.telemetry.memory.pressureSome) ? root.telemetry.memory.pressureSome / 10 : 0
      accent: root.finite(root.telemetry.memory.pressureSome) && root.telemetry.memory.pressureSome > 1
        ? Instrument.InstrumentPalette.warning : Instrument.InstrumentPalette.nominal
    }

    Instrument.PressureCell {
      x: 34 + 2 * (parent.width - 52) / 3
      y: 292
      width: (parent.width - 52) / 3
      label: "I/O SOME"
      valueText: root.decimal(root.telemetry.io.pressureSome, 2)
      fraction: root.finite(root.telemetry.io.pressureSome) ? root.telemetry.io.pressureSome / 10 : 0
      accent: root.finite(root.telemetry.io.pressureSome) && root.telemetry.io.pressureSome > 1
        ? Instrument.InstrumentPalette.warning : Instrument.InstrumentPalette.nominal
    }

    Text {
      x: 18
      y: parent.height - 28
      text: "CHAMBER STATE  " + root.freshness("cpu") + "  //  HISTORY LINKED"
      color: Instrument.InstrumentPalette.nominal
      font {
        family: Instrument.InstrumentPalette.monoFamily
        pixelSize: 9
        letterSpacing: 1
      }
    }
  }

  Instrument.InstrumentFrame {
    x: root.gx(136)
    y: root.gy(6.6)
    width: root.gx(47)
    height: root.gy(39.4)
    title: "GRAPHICS ARRAY"
    code: "GFX-01"
    accent: Instrument.InstrumentPalette.signal

    Text {
      x: 17
      y: 15
      text: root.percent(root.telemetry.gpu.utilization)
      color: Instrument.InstrumentPalette.text
      font {
        family: Instrument.InstrumentPalette.monoFamily
        pixelSize: 56
        weight: Font.Light
      }
    }

    Text {
      x: 121
      y: 48
      text: "% GPU"
      color: Instrument.InstrumentPalette.signal
      font {
        family: Instrument.InstrumentPalette.monoFamily
        pixelSize: 12
        letterSpacing: 1.5
      }
    }

    Text {
      anchors {
        right: parent.right
        rightMargin: 16
        top: parent.top
        topMargin: 22
      }
      text: root.temperature(root.telemetry.gpu.temperatureC)
      color: Instrument.InstrumentPalette.warning
      font {
        family: Instrument.InstrumentPalette.monoFamily
        pixelSize: 15
      }
    }

    Text {
      anchors {
        right: parent.right
        rightMargin: 16
        top: parent.top
        topMargin: 50
      }
      text: root.decimal(root.telemetry.gpu.powerW, 1) + " W"
      color: Instrument.InstrumentPalette.compute
      font {
        family: Instrument.InstrumentPalette.monoFamily
        pixelSize: 15
      }
    }

    Instrument.TraceCanvas {
      x: 17
      y: 93
      width: parent.width - 34
      height: 100
      values: root.gpuHistory
      lineColor: Instrument.InstrumentPalette.signal
      fillPrimary: true
    }

    Text {
      x: 17
      y: 199
      text: "ACTIVITY CARRIER // 60s"
      color: Instrument.InstrumentPalette.muted
      font {
        family: Instrument.InstrumentPalette.monoFamily
        pixelSize: 10
        letterSpacing: 1
      }
    }

    Instrument.CapacityRail {
      x: 17
      y: 225
      width: parent.width - 34
      label: "VRAM CAPACITANCE"
      valueText: root.decimal(root.telemetry.gpu.vramUsedMiB / 1024, 1)
        + " / " + root.decimal(root.telemetry.gpu.vramTotalMiB / 1024, 1) + " GiB"
      fraction: root.ratio(root.telemetry.gpu.vramUsedMiB, root.telemetry.gpu.vramTotalMiB)
      accent: Instrument.InstrumentPalette.signal
    }

    Rectangle {
      x: 17
      y: 287
      width: (parent.width - 43) / 2
      height: 73
      color: Instrument.InstrumentPalette.panelRaised
      border.color: Instrument.InstrumentPalette.borderDim

      Text {
        anchors {
          left: parent.left
          leftMargin: 10
          top: parent.top
          topMargin: 10
        }
        text: "GRAPHICS CLK"
        color: Instrument.InstrumentPalette.muted
        font { family: Instrument.InstrumentPalette.monoFamily; pixelSize: 9 }
      }

      Text {
        anchors {
          left: parent.left
          leftMargin: 10
          bottom: parent.bottom
          bottomMargin: 11
        }
        text: root.decimal(root.telemetry.gpu.graphicsClockMhz, 0) + " MHz"
        color: Instrument.InstrumentPalette.signal
        font { family: Instrument.InstrumentPalette.monoFamily; pixelSize: 15 }
      }
    }

    Rectangle {
      x: 26 + (parent.width - 43) / 2
      y: 287
      width: (parent.width - 43) / 2
      height: 73
      color: Instrument.InstrumentPalette.panelRaised
      border.color: Instrument.InstrumentPalette.borderDim

      Text {
        anchors {
          left: parent.left
          leftMargin: 10
          top: parent.top
          topMargin: 10
        }
        text: "MEMORY CLK"
        color: Instrument.InstrumentPalette.muted
        font { family: Instrument.InstrumentPalette.monoFamily; pixelSize: 9 }
      }

      Text {
        anchors {
          left: parent.left
          leftMargin: 10
          bottom: parent.bottom
          bottomMargin: 11
        }
        text: root.decimal(root.telemetry.gpu.memoryClockMhz, 0) + " MHz"
        color: Instrument.InstrumentPalette.compute
        font { family: Instrument.InstrumentPalette.monoFamily; pixelSize: 15 }
      }
    }
  }

  Instrument.InstrumentFrame {
    x: root.gx(186)
    y: root.gy(6.6)
    width: root.gx(50)
    height: root.gy(39.4)
    title: "I/O MANIFOLD"
    code: "BUS-04"
    accent: Instrument.InstrumentPalette.nominal

    Text {
      x: 17
      y: 15
      text: "NETWORK FLOW"
      color: Instrument.InstrumentPalette.secondaryText
      font {
        family: Instrument.InstrumentPalette.monoFamily
        pixelSize: 10
        letterSpacing: 1.5
      }
    }

    Text {
      x: 17
      y: 45
      text: "RX  " + root.rate(root.telemetry.io.networkRxBps)
      color: Instrument.InstrumentPalette.nominal
      font { family: Instrument.InstrumentPalette.monoFamily; pixelSize: 14 }
    }

    Text {
      anchors {
        right: parent.right
        rightMargin: 17
        top: parent.top
        topMargin: 45
      }
      text: "TX  " + root.rate(root.telemetry.io.networkTxBps)
      color: Instrument.InstrumentPalette.signal
      font { family: Instrument.InstrumentPalette.monoFamily; pixelSize: 14 }
    }

    Instrument.TraceCanvas {
      x: 17
      y: 78
      width: parent.width - 34
      height: 85
      values: root.networkHistory
      secondaryValues: root.diskHistory
      lineColor: Instrument.InstrumentPalette.nominal
      secondaryColor: Instrument.InstrumentPalette.warning
    }

    Text {
      x: 17
      y: 171
      text: "FLOW // STALL RECORDER"
      color: Instrument.InstrumentPalette.muted
      font { family: Instrument.InstrumentPalette.monoFamily; pixelSize: 10; letterSpacing: 1 }
    }

    Rectangle {
      x: 17
      y: 200
      width: parent.width - 34
      height: 88
      color: Instrument.InstrumentPalette.panelRaised
      border.color: Instrument.InstrumentPalette.borderDim

      Text {
        x: 11
        y: 10
        text: "STORAGE BUS"
        color: Instrument.InstrumentPalette.muted
        font { family: Instrument.InstrumentPalette.monoFamily; pixelSize: 9; letterSpacing: 1 }
      }

      Text {
        x: 11
        y: 35
        text: "READ   " + root.rate(root.telemetry.io.diskReadBps)
        color: Instrument.InstrumentPalette.warning
        font { family: Instrument.InstrumentPalette.monoFamily; pixelSize: 13 }
      }

      Text {
        x: 11
        y: 59
        text: "WRITE  " + root.rate(root.telemetry.io.diskWriteBps)
        color: Instrument.InstrumentPalette.signal
        font { family: Instrument.InstrumentPalette.monoFamily; pixelSize: 13 }
      }

      Text {
        anchors {
          right: parent.right
          rightMargin: 11
          verticalCenter: parent.verticalCenter
        }
        text: root.temperature(root.telemetry.thermal.nvmeMaxC)
        color: Instrument.InstrumentPalette.text
        font { family: Instrument.InstrumentPalette.monoFamily; pixelSize: 18 }
      }
    }

    Instrument.PressureCell {
      x: 17
      y: 305
      width: parent.width - 34
      height: 70
      label: "I/O PRESSURE SOME"
      valueText: root.decimal(root.telemetry.io.pressureSome, 2)
      fraction: root.finite(root.telemetry.io.pressureSome) ? root.telemetry.io.pressureSome / 10 : 0
      accent: root.finite(root.telemetry.io.pressureSome) && root.telemetry.io.pressureSome > 1
        ? Instrument.InstrumentPalette.warning : Instrument.InstrumentPalette.nominal
    }

    Text {
      x: 17
      y: parent.height - 28
      text: "MANIFOLD STATE  " + root.freshness("io")
      color: Instrument.InstrumentPalette.nominal
      font { family: Instrument.InstrumentPalette.monoFamily; pixelSize: 9; letterSpacing: 1 }
    }
  }

  Rectangle {
    x: root.gx(4)
    y: root.gy(48.3)
    width: root.gx(232)
    height: root.gy(13.3)
    color: Instrument.InstrumentPalette.panel
    border.color: {
      if (root.inputRejected) return Instrument.InstrumentPalette.critical
      if (root.capsLockActive) return Instrument.InstrumentPalette.warning
      return Instrument.InstrumentPalette.signal
    }
    border.width: 1

    Rectangle {
      anchors {
        left: parent.left
        top: parent.top
        bottom: parent.bottom
      }
      width: 5
      color: {
        if (root.inputRejected) return Instrument.InstrumentPalette.critical
        if (root.capsLockActive) return Instrument.InstrumentPalette.warning
        return Instrument.InstrumentPalette.signal
      }
    }

    Column {
      anchors {
        left: parent.left
        leftMargin: 21
        verticalCenter: parent.verticalCenter
      }
      spacing: 8

      Text {
        text: "SYNOPTIC CONTROL"
        color: Instrument.InstrumentPalette.signal
        font {
          family: Instrument.InstrumentPalette.monoFamily
          pixelSize: 11
          letterSpacing: 1.8
        }
      }

      Text {
        text: "ALL SYSTEMS LINKED"
        color: Instrument.InstrumentPalette.nominal
        font {
          family: Instrument.InstrumentPalette.monoFamily
          pixelSize: 16
          letterSpacing: 1.2
        }
      }
    }

    Column {
      anchors.centerIn: parent
      spacing: 10

      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: {
          if (root.lockMode && root.inputRejected)
            return "[ INPUT REJECTED // CLEAR AND RETRY ]"
          if (!root.lockMode) return "[ OPERATOR HANDSHAKE // STANDBY ]"
          if (root.lockState === "captured")
            return "[ AUTHENTICATION LINK // INPUT CAPTURED ]"
          if (root.lockState === "fallback")
            return "[ AUTHENTICATION LINK // FALLBACK TRANSFER ]"
          if (root.lockState === "failure")
            return "[ LOCK FAILURE // MANUAL RECOVERY REQUIRED ]"
          return "[ AUTHENTICATION LINK // ARMING INPUT CAPTURE ]"
        }
        color: root.inputRejected ? Instrument.InstrumentPalette.critical
          : Instrument.InstrumentPalette.text
        font {
          family: Instrument.InstrumentPalette.monoFamily
          pixelSize: 20
          letterSpacing: 2.5
          weight: Font.DemiBold
        }
      }

      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: {
          if (root.lockMode && root.inputRejected)
            return "PRESS ESC TO CLEAR // TYPE PASSWORD // ENTER TO AUTHENTICATE"
          if (!root.lockMode) return "PRESS ENTER TO ESTABLISH VISUAL RELEASE"
          if (root.lockState === "captured")
            return "TYPE PASSWORD // ENTER TO AUTHENTICATE"
          if (root.lockState === "failure")
            return "AUTHENTICATED INPUT LOCK IS NOT ACTIVE"
          return "STANDBY // INPUT CAPTURE PENDING"
        }
        color: root.inputRejected ? Instrument.InstrumentPalette.critical
          : Instrument.InstrumentPalette.muted
        font {
          family: Instrument.InstrumentPalette.monoFamily
          pixelSize: 10
          letterSpacing: 1.4
        }
      }

      Text {
        visible: root.lockMode && root.capsLockActive
        anchors.horizontalCenter: parent.horizontalCenter
        text: "[ CAPS LOCK // ACTIVE ]"
        color: Instrument.InstrumentPalette.warning
        font {
          family: Instrument.InstrumentPalette.monoFamily
          pixelSize: 11
          letterSpacing: 1.8
          weight: Font.DemiBold
        }
      }
    }

    Column {
      anchors {
        right: parent.right
        rightMargin: 21
        verticalCenter: parent.verticalCenter
      }
      spacing: 8

      Text {
        anchors.right: parent.right
        text: root.telemetry.power.onBattery ? "BATTERY BUS" : "EXTERNAL POWER"
        color: root.telemetry.power.onBattery
          ? Instrument.InstrumentPalette.warning : Instrument.InstrumentPalette.nominal
        font {
          family: Instrument.InstrumentPalette.monoFamily
          pixelSize: 11
          letterSpacing: 1.2
        }
      }

      Text {
        anchors.right: parent.right
        text: root.finite(root.telemetry.power.batteryPercent)
          ? root.telemetry.power.batteryPercent.toFixed(0) + "%  //  " + root.durationText
          : "--%  //  " + root.durationText
        color: Instrument.InstrumentPalette.secondaryText
        font {
          family: Instrument.InstrumentPalette.monoFamily
          pixelSize: 15
        }
      }
    }

    Rectangle {
      anchors.fill: parent
      z: 10
      color: "transparent"
      border.width: 2
      border.color: Instrument.InstrumentPalette.critical
      opacity: root.rejectionPulse
    }
  }

  Text {
    x: root.gx(4)
    y: root.gy(63.2)
    text: "PRIMARY FLIGHT INSTRUMENT  //  240 × 67 LOGICAL GRID  //  READ-ONLY MACHINE TELEMETRY"
    color: Instrument.InstrumentPalette.muted
    font {
      family: Instrument.InstrumentPalette.monoFamily
      pixelSize: 11
      letterSpacing: 1.3
    }
  }

  Text {
    anchors {
      right: parent.right
      rightMargin: root.gx(4)
    }
    y: root.gy(63.2)
    text: "NO PROCESS IDENTITY  //  NO NETWORK IDENTITY  //  LOCAL SENSOR BUS"
    color: Instrument.InstrumentPalette.muted
    font {
      family: Instrument.InstrumentPalette.monoFamily
      pixelSize: 11
      letterSpacing: 1.3
    }
  }
}
