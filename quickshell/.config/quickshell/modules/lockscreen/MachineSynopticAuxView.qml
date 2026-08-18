import QtQuick
import "." as Instrument

Item {
  id: root

  property var telemetry: emptyTelemetry()
  property var history: []
  property string clockText: "--:--:--"
  property string durationText: "T+00:00"
  property string telemetryHealth: "acquiring"
  property real cpuRotorPhase: 0.28
  property real gpuRotorPhase: 0.86

  readonly property var cpuThermalHistory: normalizedHistory("cpuTempC", 100)
  readonly property var gpuThermalHistory: normalizedHistory("gpuTempC", 100)

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

  function temperature(value) {
    return finite(value) ? value.toFixed(1) + "°C" : "--.-°C"
  }

  function normalizedHistory(field, maximum) {
    if (!Array.isArray(history)) return []
    var result = []
    for (var index = 0; index < history.length; index++) {
      var value = Number(history[index][field])
      if (isFinite(value)) result.push(Math.max(0, Math.min(1, value / maximum)))
    }
    return result
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

  Rectangle {
    anchors.fill: parent
    color: Instrument.InstrumentPalette.background
  }

  Instrument.SynopticBackdrop {
    anchors.fill: parent
    busSegments: [
      [0.335, 0.345, 0.420, 0.345],
      [0.665, 0.345, 0.580, 0.345],
      [0.500, 0.440, 0.500, 0.535]
    ]
  }

  Rectangle {
    x: root.gx(4)
    y: root.gy(1.4)
    width: root.gx(232)
    height: root.gy(4.1)
    color: Instrument.InstrumentPalette.panelRaised
    border.color: Instrument.InstrumentPalette.border

    Rectangle {
      anchors {
        left: parent.left
        top: parent.top
        bottom: parent.bottom
      }
      width: 5
      color: Instrument.InstrumentPalette.auxiliary
    }

    Text {
      anchors {
        left: parent.left
        leftMargin: 18
        verticalCenter: parent.verticalCenter
      }
      text: "MACHINE SYNOPTIC  //  AUXILIARY THERMAL LOOP"
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
        text: "CARRIER " + root.telemetryHealth.toUpperCase()
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
      color: Instrument.InstrumentPalette.auxiliary
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
    width: root.gx(77)
    height: root.gy(31)
    title: "PORT IMPELLER // CPU"
    code: "FAN-A"
    accent: Instrument.InstrumentPalette.signal

    Instrument.FanInstrument {
      anchors {
        left: parent.left
        leftMargin: 28
        top: parent.top
        topMargin: 18
        bottom: parent.bottom
        bottomMargin: 18
      }
      width: parent.width * 0.53
      label: "CPU COOLANT DRIVE"
      rpm: root.finite(root.telemetry.thermal.cpuFanRpm) ? root.telemetry.thermal.cpuFanRpm : 0
      temperatureC: root.finite(root.telemetry.cpu.packageTempC) ? root.telemetry.cpu.packageTempC : 0
      rotorPhase: root.cpuRotorPhase
      accent: Instrument.InstrumentPalette.signal
    }

    Column {
      anchors {
        right: parent.right
        rightMargin: 25
        verticalCenter: parent.verticalCenter
      }
      width: parent.width * 0.32
      spacing: 18

      Text {
        text: root.temperature(root.telemetry.cpu.packageTempC)
        color: Instrument.InstrumentPalette.text
        font {
          family: Instrument.InstrumentPalette.monoFamily
          pixelSize: 36
          weight: Font.Light
        }
      }

      Text {
        text: "PACKAGE THERMAL"
        color: Instrument.InstrumentPalette.muted
        font {
          family: Instrument.InstrumentPalette.monoFamily
          pixelSize: 11
          letterSpacing: 1.2
        }
      }

      Instrument.CapacityRail {
        width: parent.width
        label: "ENVELOPE"
        valueText: root.temperature(root.telemetry.cpu.packageTempC)
        fraction: root.finite(root.telemetry.cpu.packageTempC) ? root.telemetry.cpu.packageTempC / 100 : 0
        accent: Instrument.InstrumentPalette.signal
      }

      Text {
        text: "SENSOR  " + root.freshness("cpu")
        color: root.freshness("cpu") === "NOMINAL"
          ? Instrument.InstrumentPalette.nominal : Instrument.InstrumentPalette.warning
        font {
          family: Instrument.InstrumentPalette.monoFamily
          pixelSize: 11
          letterSpacing: 1
        }
      }
    }
  }

  Instrument.InstrumentFrame {
    x: root.gx(159)
    y: root.gy(6.6)
    width: root.gx(77)
    height: root.gy(31)
    title: "STARBOARD IMPELLER // GPU"
    code: "FAN-B"
    accent: Instrument.InstrumentPalette.compute

    Instrument.FanInstrument {
      anchors {
        right: parent.right
        rightMargin: 28
        top: parent.top
        topMargin: 18
        bottom: parent.bottom
        bottomMargin: 18
      }
      width: parent.width * 0.53
      label: "GPU COOLANT DRIVE"
      rpm: root.finite(root.telemetry.thermal.gpuFanRpm) ? root.telemetry.thermal.gpuFanRpm : 0
      temperatureC: root.finite(root.telemetry.gpu.temperatureC) ? root.telemetry.gpu.temperatureC : 0
      rotorPhase: root.gpuRotorPhase
      accent: Instrument.InstrumentPalette.compute
    }

    Column {
      anchors {
        left: parent.left
        leftMargin: 25
        verticalCenter: parent.verticalCenter
      }
      width: parent.width * 0.32
      spacing: 18

      Text {
        text: root.temperature(root.telemetry.gpu.temperatureC)
        color: Instrument.InstrumentPalette.text
        font {
          family: Instrument.InstrumentPalette.monoFamily
          pixelSize: 36
          weight: Font.Light
        }
      }

      Text {
        text: "DIE THERMAL"
        color: Instrument.InstrumentPalette.muted
        font {
          family: Instrument.InstrumentPalette.monoFamily
          pixelSize: 11
          letterSpacing: 1.2
        }
      }

      Instrument.CapacityRail {
        width: parent.width
        label: "ENVELOPE"
        valueText: root.temperature(root.telemetry.gpu.temperatureC)
        fraction: root.finite(root.telemetry.gpu.temperatureC) ? root.telemetry.gpu.temperatureC / 100 : 0
        accent: Instrument.InstrumentPalette.compute
      }

      Text {
        text: "SENSOR  " + root.freshness("gpu")
        color: root.freshness("gpu") === "NOMINAL"
          ? Instrument.InstrumentPalette.nominal : Instrument.InstrumentPalette.warning
        font {
          family: Instrument.InstrumentPalette.monoFamily
          pixelSize: 11
          letterSpacing: 1
        }
      }
    }
  }

  Instrument.InstrumentFrame {
    x: root.gx(84)
    y: root.gy(6.6)
    width: root.gx(72)
    height: root.gy(31)
    title: "THERMAL EXCHANGER"
    code: "LOOP-X"
    accent: Instrument.InstrumentPalette.nominal

    Text {
      anchors {
        horizontalCenter: parent.horizontalCenter
        top: parent.top
        topMargin: 24
      }
      text: "COOLANT BUS // COHERENT"
      color: Instrument.InstrumentPalette.nominal
      font {
        family: Instrument.InstrumentPalette.monoFamily
        pixelSize: 12
        letterSpacing: 1.6
      }
    }

    Instrument.TraceCanvas {
      x: 22
      y: 67
      width: parent.width - 44
      height: 112
      values: root.cpuThermalHistory
      secondaryValues: root.gpuThermalHistory
      lineColor: Instrument.InstrumentPalette.signal
      secondaryColor: Instrument.InstrumentPalette.compute
      fillPrimary: true
    }

    Text {
      x: 22
      y: 187
      text: "THERMAL CARRIER // CPU + GPU"
      color: Instrument.InstrumentPalette.muted
      font {
        family: Instrument.InstrumentPalette.monoFamily
        pixelSize: 10
        letterSpacing: 1
      }
    }

    Instrument.CapacityRail {
      x: 22
      y: 222
      width: parent.width - 44
      label: "NVME COMPOSITE MAX"
      valueText: root.temperature(root.telemetry.thermal.nvmeMaxC)
      fraction: root.finite(root.telemetry.thermal.nvmeMaxC) ? root.telemetry.thermal.nvmeMaxC / 90 : 0
      accent: Instrument.InstrumentPalette.nominal
    }

    Instrument.CapacityRail {
      x: 22
      y: 276
      width: parent.width - 44
      label: "DIMM THERMAL MAX"
      valueText: root.temperature(root.telemetry.thermal.dimmMaxC)
      fraction: root.finite(root.telemetry.thermal.dimmMaxC) ? root.telemetry.thermal.dimmMaxC / 90 : 0
      accent: Instrument.InstrumentPalette.auxiliary
    }

    Text {
      anchors {
        horizontalCenter: parent.horizontalCenter
        bottom: parent.bottom
        bottomMargin: 15
      }
      text: "Δ FAN  " + (root.finite(root.telemetry.thermal.cpuFanRpm)
        && root.finite(root.telemetry.thermal.gpuFanRpm)
        ? Math.abs(root.telemetry.thermal.cpuFanRpm - root.telemetry.thermal.gpuFanRpm).toFixed(0) + " RPM"
        : "-- RPM")
      color: Instrument.InstrumentPalette.secondaryText
      font {
        family: Instrument.InstrumentPalette.monoFamily
        pixelSize: 11
        letterSpacing: 1
      }
    }
  }

  Instrument.InstrumentFrame {
    x: root.gx(4)
    y: root.gy(39.5)
    width: root.gx(174)
    height: root.gy(21.8)
    title: "FIVE-MINUTE THERMAL RECORDER"
    code: "REC-300"
    accent: Instrument.InstrumentPalette.auxiliary

    Instrument.TraceCanvas {
      x: 20
      y: 20
      width: parent.width - 40
      height: parent.height - 78
      values: root.cpuThermalHistory
      secondaryValues: root.gpuThermalHistory
      lineColor: Instrument.InstrumentPalette.signal
      secondaryColor: Instrument.InstrumentPalette.compute
      fillPrimary: true
    }

    Row {
      anchors {
        left: parent.left
        leftMargin: 20
        bottom: parent.bottom
        bottomMargin: 14
      }
      spacing: 30

      Text {
        text: "CPU  " + root.temperature(root.telemetry.cpu.packageTempC)
        color: Instrument.InstrumentPalette.signal
        font { family: Instrument.InstrumentPalette.monoFamily; pixelSize: 13 }
      }

      Text {
        text: "GPU  " + root.temperature(root.telemetry.gpu.temperatureC)
        color: Instrument.InstrumentPalette.compute
        font { family: Instrument.InstrumentPalette.monoFamily; pixelSize: 13 }
      }

      Text {
        text: "NVME  " + root.temperature(root.telemetry.thermal.nvmeMaxC)
        color: Instrument.InstrumentPalette.nominal
        font { family: Instrument.InstrumentPalette.monoFamily; pixelSize: 13 }
      }

      Text {
        text: "DIMM  " + root.temperature(root.telemetry.thermal.dimmMaxC)
        color: Instrument.InstrumentPalette.auxiliary
        font { family: Instrument.InstrumentPalette.monoFamily; pixelSize: 13 }
      }
    }
  }

  Instrument.InstrumentFrame {
    x: root.gx(181)
    y: root.gy(39.5)
    width: root.gx(55)
    height: root.gy(21.8)
    title: "POWER LOOP"
    code: "PWR-AC"
    accent: root.telemetry.power.onBattery
      ? Instrument.InstrumentPalette.warning : Instrument.InstrumentPalette.nominal

    Text {
      anchors {
        horizontalCenter: parent.horizontalCenter
        top: parent.top
        topMargin: 27
      }
      text: root.telemetry.power.onBattery ? "BATTERY BUS" : "EXTERNAL POWER"
      color: root.telemetry.power.onBattery
        ? Instrument.InstrumentPalette.warning : Instrument.InstrumentPalette.nominal
      font {
        family: Instrument.InstrumentPalette.monoFamily
        pixelSize: 13
        letterSpacing: 1.5
      }
    }

    Text {
      anchors {
        horizontalCenter: parent.horizontalCenter
        top: parent.top
        topMargin: 70
      }
      text: root.finite(root.telemetry.power.batteryPercent)
        ? root.telemetry.power.batteryPercent.toFixed(0) + "%" : "--%"
      color: Instrument.InstrumentPalette.text
      font {
        family: Instrument.InstrumentPalette.monoFamily
        pixelSize: 58
        weight: Font.Light
      }
    }

    Instrument.CapacityRail {
      x: 23
      y: 151
      width: parent.width - 46
      label: "INTERNAL CELL"
      valueText: String(root.telemetry.power.batteryState || "unknown").toUpperCase()
      fraction: root.finite(root.telemetry.power.batteryPercent)
        ? root.telemetry.power.batteryPercent / 100 : 0
      accent: root.telemetry.power.onBattery
        ? Instrument.InstrumentPalette.warning : Instrument.InstrumentPalette.nominal
    }

    Text {
      anchors {
        horizontalCenter: parent.horizontalCenter
        bottom: parent.bottom
        bottomMargin: 27
      }
      text: "VISIBLE  " + root.durationText
      color: Instrument.InstrumentPalette.secondaryText
      font {
        family: Instrument.InstrumentPalette.monoFamily
        pixelSize: 12
        letterSpacing: 1
      }
    }
  }

  Text {
    x: root.gx(4)
    y: root.gy(63.2)
    text: "AUXILIARY THERMAL INSTRUMENT  //  PROMOTES TO COMPLETE SYNOPTIC WHEN SOLE DISPLAY"
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
    text: "CPU + GPU COOLANT LOOP  //  NVME + DIMM THERMAL BUS"
    color: Instrument.InstrumentPalette.muted
    font {
      family: Instrument.InstrumentPalette.monoFamily
      pixelSize: 11
      letterSpacing: 1.3
    }
  }
}
