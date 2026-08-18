import QtQuick
import Quickshell
import Quickshell.Io
import modules.lockscreen as Lockscreen

ShellRoot {
  id: root

  readonly property string resultPath: Quickshell.env("QUATTRO_QS_TEST_RESULT")
  property string mode: Quickshell.env("MACHINE_SYNOPTIC_FIXTURE_MODE") || "primary"
  property bool wired: false
  property bool resultWritten: false
  property string clockText: "--:--:--"
  readonly property var telemetryService: serviceLoader.item
  readonly property var collector: collectorLoader.item
  readonly property var interpolation: interpolationLoader.item
  readonly property var renderedTelemetry: interpolation ? interpolation.snapshot : ({})
  readonly property var renderedHistory: telemetryService ? telemetryService.history300 : []
  readonly property string telemetryHealth: telemetryService ? telemetryService.health : "acquiring"

  Loader {
    id: serviceLoader
    source: "file://" + Quickshell.env("QUATTRO_TELEMETRY_SERVICE")
    onLoaded: root.maybeWire()
  }

  Loader {
    id: collectorLoader
    source: "file://" + Quickshell.env("QUATTRO_TELEMETRY_COLLECTOR")
    onLoaded: root.maybeWire()
  }

  Loader {
    id: interpolationLoader
    source: "file://" + Quickshell.env("QUATTRO_TELEMETRY_INTERPOLATION")
    onLoaded: root.maybeWire()
  }

  function maybeWire() {
    if (wired || !telemetryService || !collector || !interpolation) return
    wired = true
    collector.telemetryService = telemetryService
    collector.discoveryScriptPath = Quickshell.env("QUATTRO_TELEMETRY_DISCOVERY")
    interpolation.sourceSnapshot = telemetryService.snapshot
    interpolation.sourceRevision = telemetryService.revision
    interpolation.active = true
    collector.active = true
  }

  Connections {
    target: root.telemetryService
    enabled: root.telemetryService !== null
    function onRevisionChanged() {
      if (!root.interpolation || !root.telemetryService) return
      root.interpolation.sourceSnapshot = root.telemetryService.snapshot
      root.interpolation.sourceRevision = root.telemetryService.revision
    }
  }

  function finite(value) {
    var parsed = Number(value)
    return value !== null && value !== undefined && value !== "" && isFinite(parsed)
  }

  function durationText() {
    var seconds = renderedTelemetry && renderedTelemetry.time && finite(renderedTelemetry.time.visibleSeconds)
      ? Math.max(0, Math.floor(renderedTelemetry.time.visibleSeconds)) : 0
    var minutes = Math.floor(seconds / 60)
    var remainder = seconds % 60
    return "T+" + String(minutes).padStart(2, "0") + ":" + String(remainder).padStart(2, "0")
  }

  function updateClock() {
    clockText = Qt.formatDateTime(new Date(), "HH:mm:ss")
  }

  function shellQuote(value) {
    return "'" + String(value).replace(/'/g, "'\\''") + "'"
  }

  function snapshotPayload() {
    var snapshot = telemetryService.snapshot
    return {
      cpu: snapshot.cpu,
      gpu: snapshot.gpu,
      memory: snapshot.memory,
      io: snapshot.io,
      thermal: snapshot.thermal,
      power: snapshot.power,
      freshness: snapshot.freshness
    }
  }

  function snapshotReady() {
    if (!telemetryService) return false
    var snapshot = telemetryService.snapshot
    return telemetryService.health === "nominal"
      && finite(snapshot.cpu.utilization)
      && finite(snapshot.cpu.frequencyMhz)
      && finite(snapshot.cpu.packageTempC)
      && finite(snapshot.gpu.utilization)
      && finite(snapshot.memory.ramUsedBytes)
      && finite(snapshot.io.networkRxBps)
      && finite(snapshot.io.diskReadBps)
      && finite(snapshot.thermal.cpuFanRpm)
      && finite(snapshot.thermal.gpuFanRpm)
      && finite(snapshot.power.batteryPercent)
  }

  function readyForProof() {
    return wired && telemetryService && collector && interpolation
      && telemetryService.revision >= 4
      && collector.committedSamples >= 4
      && collector.discoveryReady
      && collector.gpuSamples >= 2
      && collector.gpuStartCount === 1
      && interpolation.frameCount >= 60
      && snapshotReady()
      && panel.visible && panel.width === 1920 && panel.height === 1080
  }

  function writeResult(ok, failure) {
    if (resultWritten) return
    resultWritten = true
    var payload = JSON.stringify({
      ok: ok,
      failure: failure || "",
      mode: mode,
      width: panel.width,
      height: panel.height,
      revision: telemetryService ? telemetryService.revision : 0,
      health: telemetryService ? telemetryService.health : "missing",
      history60: telemetryService ? telemetryService.history60.length : 0,
      history300: telemetryService ? telemetryService.history300.length : 0,
      committedSamples: collector ? collector.committedSamples : 0,
      skippedCycles: collector ? collector.skippedCycles : 0,
      discoveryReady: collector ? collector.discoveryReady : false,
      sensorFiles: collector ? collector.sensorFileSpecs.length : 0,
      gpuRunning: collector ? collector.gpuRunning : false,
      gpuStartCount: collector ? collector.gpuStartCount : 0,
      gpuSamples: collector ? collector.gpuSamples : 0,
      interpolationFrames: interpolation ? interpolation.frameCount : 0,
      cpuRotorPhase: interpolation ? interpolation.cpuRotorPhase : 0,
      gpuRotorPhase: interpolation ? interpolation.gpuRotorPhase : 0,
      sourceErrors: collector ? collector.sourceErrors : {},
      snapshot: telemetryService ? snapshotPayload() : {}
    })
    Quickshell.execDetached([
      "bash", "-lc",
      "printf '%s' " + shellQuote(payload) + " > " + shellQuote(resultPath)
    ])
  }

  function shutdown() {
    if (collector) collector.active = false
    if (interpolation) interpolation.active = false
    Qt.quit()
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
      telemetry: root.renderedTelemetry
      history: root.renderedHistory
      clockText: root.clockText
      durationText: root.durationText()
      telemetryHealth: root.telemetryHealth
      cpuRotorPhase: root.interpolation ? root.interpolation.cpuRotorPhase : 0
      gpuRotorPhase: root.interpolation ? root.interpolation.gpuRotorPhase : 0
    }
  }

  Component {
    id: auxiliaryComponent

    Lockscreen.MachineSynopticAuxView {
      telemetry: root.renderedTelemetry
      history: root.renderedHistory
      clockText: root.clockText
      durationText: root.durationText()
      telemetryHealth: root.telemetryHealth
      cpuRotorPhase: root.interpolation ? root.interpolation.cpuRotorPhase : 0
      gpuRotorPhase: root.interpolation ? root.interpolation.gpuRotorPhase : 0
    }
  }

  IpcHandler {
    target: "machineSynopticLiveFixture"

    function status(): string {
      return JSON.stringify({
        mode: root.mode,
        ready: root.readyForProof(),
        health: root.telemetryHealth,
        revision: root.telemetryService ? root.telemetryService.revision : 0,
        gpuStartCount: root.collector ? root.collector.gpuStartCount : 0
      })
    }

    function setMode(nextMode: string): string {
      root.mode = nextMode === "auxiliary" ? "auxiliary" : "primary"
      return root.mode
    }

    function quit(): void {
      root.shutdown()
    }
  }

  Timer {
    interval: 1000
    repeat: true
    running: true
    triggeredOnStart: true
    onTriggered: root.updateClock()
  }

  Timer {
    interval: 100
    repeat: true
    running: !root.resultWritten
    onTriggered: if (root.readyForProof()) root.writeResult(true, "")
  }

  Timer {
    interval: 15000
    running: true
    repeat: false
    onTriggered: root.writeResult(false, "live telemetry readiness timeout")
  }
}
