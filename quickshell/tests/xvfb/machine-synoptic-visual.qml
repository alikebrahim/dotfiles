import QtQuick
import Quickshell
import Quickshell.Io
import modules.lockscreen as Lockscreen

ShellRoot {
  id: root

  readonly property string resultPath: Quickshell.env("QUATTRO_QS_TEST_RESULT")
  property string mode: Quickshell.env("MACHINE_SYNOPTIC_FIXTURE_MODE") || "primary"
  readonly property var telemetry: fixtureTelemetry()
  readonly property var history: fixtureHistory()

  function fixtureTelemetry() {
    return {
      cpu: {
        utilization: 47,
        frequencyMhz: 4217,
        packageTempC: 58.4,
        pressureSome: 0.18,
        pressureFull: 0
      },
      gpu: {
        utilization: 31,
        temperatureC: 47,
        powerW: 34.7,
        powerLimitW: 115,
        vramUsedMiB: 2310,
        vramTotalMiB: 8188,
        graphicsClockMhz: 2100,
        memoryClockMhz: 810
      },
      memory: {
        ramUsedBytes: 12777527705,
        ramTotalBytes: 32684452000,
        swapUsedBytes: 375809638,
        swapTotalBytes: 8589934592,
        pressureSome: 0.01,
        pressureFull: 0
      },
      io: {
        networkRxBps: 874213,
        networkTxBps: 218434,
        diskReadBps: 14470348,
        diskWriteBps: 3280341,
        pressureSome: 0.04,
        pressureFull: 0
      },
      thermal: {
        cpuFanRpm: 3428,
        gpuFanRpm: 3411,
        nvmeMaxC: 35.2,
        dimmMaxC: 47.8
      },
      power: {
        batteryPresent: true,
        batteryPercent: 76,
        batteryState: "charging",
        onBattery: false
      },
      time: {
        uptimeSeconds: 357184,
        visibleSeconds: 92
      },
      freshness: {
        cpu: { state: "nominal", ageMs: 212 },
        gpu: { state: "nominal", ageMs: 286 },
        memory: { state: "nominal", ageMs: 212 },
        io: { state: "nominal", ageMs: 212 },
        thermal: { state: "nominal", ageMs: 245 },
        power: { state: "nominal", ageMs: 620 },
        time: { state: "nominal", ageMs: 212 }
      }
    }
  }

  function fixtureHistory() {
    var result = []
    for (var index = 0; index < 300; index++) {
      var cpu = 43 + 17 * Math.sin(index * 0.17) + 8 * Math.sin(index * 0.051)
      var gpu = 28 + 19 * Math.sin(index * 0.11 + 1.1)
      var cpuTemp = 57 + 3.5 * Math.sin(index * 0.037)
      var gpuTemp = 46 + 3 * Math.sin(index * 0.043 + 0.8)
      var network = 540000 + 500000 * (0.5 + 0.5 * Math.sin(index * 0.29))
      var disk = 6200000 + 11000000 * Math.max(0, Math.sin(index * 0.097 - 0.7))
      result.push({
        sampledAtMs: 1000 + index * 1000,
        cpuUtilization: Math.max(5, Math.min(98, cpu)),
        gpuUtilization: Math.max(2, Math.min(95, gpu)),
        cpuTempC: cpuTemp,
        gpuTempC: gpuTemp,
        networkBps: network,
        diskBps: disk,
        ioPressure: index % 47 === 0 ? 1.2 : 0.04
      })
    }
    return result
  }

  function shellQuote(value) {
    return "'" + String(value).replace(/'/g, "'\\''") + "'"
  }

  function writeReady() {
    var payload = JSON.stringify({
      ok: panel.visible && panel.width > 0 && panel.height > 0,
      mode: root.mode,
      width: panel.width,
      height: panel.height,
      historySamples: root.history.length,
      telemetryHealth: "nominal"
    })
    Quickshell.execDetached([
      "bash", "-lc",
      "printf '%s' " + shellQuote(payload) + " > " + shellQuote(resultPath)
    ])
  }

  PanelWindow {
    id: panel

    visible: true
    screen: Quickshell.screens.length > 0 ? Quickshell.screens[0] : null
    color: Lockscreen.InstrumentPalette.background
    aboveWindows: true
    exclusionMode: ExclusionMode.Ignore
    exclusiveZone: 0
    focusable: false
    surfaceFormat.opaque: true

    anchors {
      left: true
      right: true
      top: true
      bottom: true
    }

    Loader {
      anchors.fill: parent
      sourceComponent: root.mode === "auxiliary" ? auxiliaryComponent : primaryComponent
    }
  }

  Component {
    id: primaryComponent

    Lockscreen.MachineSynopticPrimaryView {
      telemetry: root.telemetry
      history: root.history
      clockText: "23:41:08"
      durationText: "T+01:32"
      telemetryHealth: "nominal"
    }
  }

  Component {
    id: auxiliaryComponent

    Lockscreen.MachineSynopticAuxView {
      telemetry: root.telemetry
      history: root.history
      clockText: "23:41:08"
      durationText: "T+01:32"
      telemetryHealth: "nominal"
    }
  }

  IpcHandler {
    target: "machineSynopticFixture"

    function status(): string {
      return JSON.stringify({ mode: root.mode, visible: panel.visible, size: [panel.width, panel.height] })
    }

    function setMode(nextMode: string): string {
      root.mode = nextMode === "auxiliary" ? "auxiliary" : "primary"
      return root.mode
    }

    function quit(): void {
      Qt.quit()
    }
  }

  Timer {
    interval: 500
    running: true
    repeat: false
    onTriggered: root.writeReady()
  }

  Timer {
    interval: 60000
    running: true
    repeat: false
    onTriggered: Qt.quit()
  }
}
