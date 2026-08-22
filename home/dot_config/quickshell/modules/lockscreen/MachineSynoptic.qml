import QtQuick
import Quickshell
import Quickshell.Io
import "." as Instrument

Item {
  id: root

  property var bridge: null
  property var telemetryService: null
  property var collector: null
  property var interpolation: null
  property var modalController: null
  property bool open: false
  property bool lockMode: false
  property string lockToken: ""
  property string lockWindowTag: ""
  property string lockState: "closed"
  property double openedAtMs: 0
  property string clockText: "--:--:--"
  property string surfaceName: "machine-synoptic"
  property bool capsLockActive: false
  property bool inputRejected: false
  property int rejectionSequence: 0

  readonly property var currentRoles: resolveRoles(
    screenNames(),
    bridge ? bridge.ready === true : false,
    bridge ? bridge.stale === true : true,
    bridge ? String(bridge.primaryOutput || "") : "",
    bridge && Array.isArray(bridge.outputs) ? bridge.outputs : []
  )
  readonly property bool routingDegraded: currentRoles.degraded
  readonly property string primaryScreenName: currentRoles.primaryName
  readonly property string telemetryHealth: telemetryService ? telemetryService.health : "acquiring"

  visible: false

  function screenNames() {
    var result = []
    for (var index = 0; index < Quickshell.screens.length; index++) {
      var screen = Quickshell.screens[index]
      if (screen) result.push(String(screen.name || ""))
    }
    return result
  }

  function outputNameForId(outputId, outputs) {
    var source = Array.isArray(outputs) ? outputs : []
    for (var index = 0; index < source.length; index++)
      if (String(source[index].id || "") === String(outputId || ""))
        return String(source[index].name || "")
    return ""
  }

  function resolveRoles(names, bridgeReady, bridgeStale, primaryOutputId, outputs) {
    var unique = []
    var source = Array.isArray(names) ? names : []
    for (var index = 0; index < source.length; index++) {
      var name = String(source[index] || "")
      if (name && unique.indexOf(name) === -1) unique.push(name)
    }
    if (unique.length === 0) return { primaryName: "", degraded: true, roles: [] }

    var primaryName = ""
    var degraded = !bridgeReady || bridgeStale
    if (!degraded) {
      var resolved = outputNameForId(primaryOutputId, outputs)
      if (unique.indexOf(resolved) !== -1) primaryName = resolved
      else degraded = true
    }
    if (primaryName === "") {
      if (unique.length === 1) primaryName = unique[0]
      else {
        var ordered = unique.slice().sort()
        primaryName = ordered[0]
      }
    }

    var roles = []
    for (var roleIndex = 0; roleIndex < unique.length; roleIndex++)
      roles.push({
        name: unique[roleIndex],
        role: unique[roleIndex] === primaryName ? "primary" : "auxiliary"
      })
    return { primaryName: primaryName, degraded: degraded, roles: roles }
  }

  function roleForScreenName(name) {
    var requested = String(name || "")
    var roles = currentRoles.roles
    for (var index = 0; index < roles.length; index++)
      if (roles[index].name === requested) return roles[index].role
    return "auxiliary"
  }

  function durationText() {
    var seconds = openedAtMs > 0 ? Math.max(0, Math.floor((Date.now() - openedAtMs) / 1000)) : 0
    return "T+" + String(Math.floor(seconds / 60)).padStart(2, "0")
      + ":" + String(seconds % 60).padStart(2, "0")
  }

  function updateClock() {
    clockText = Qt.formatDateTime(new Date(), "HH:mm:ss")
  }

  function resetInputFeedback() {
    capsLockActive = false
    inputRejected = false
    rejectionTimer.stop()
  }

  function applyXkbEvent(line) {
    if (!open || !lockMode || lockState !== "captured") return
    try {
      var event = JSON.parse(String(line || ""))
      if (event.type === "caps") {
        capsLockActive = event.active === true
      } else if (event.type === "rejected") {
        inputRejected = true
        rejectionSequence++
        rejectionTimer.restart()
      }
    } catch (error) {
      console.warn("Machine Synoptic ignored malformed XKB event:", error)
    }
  }

  function syncActivity() {
    if (collector) collector.active = open
    if (interpolation) interpolation.active = open
  }

  function openSurface(asLock, token, windowTag) {
    if (Quickshell.screens.length === 0) return false
    var requestedLock = asLock === true
    var requestedToken = String(token || "")
    var requestedWindowTag = String(windowTag || "")
    if (requestedLock && (requestedToken === "" || requestedWindowTag === "")) return false
    if (open && lockMode && (!requestedLock
        || requestedToken !== lockToken || requestedWindowTag !== lockWindowTag)) return false

    if (modalController) modalController.activate(surfaceName)
    resetInputFeedback()
    lockMode = requestedLock
    lockToken = requestedLock ? requestedToken : ""
    lockWindowTag = requestedLock ? requestedWindowTag : ""
    lockState = requestedLock ? "arming" : "closed"
    openedAtMs = Date.now()
    updateClock()
    open = true
    syncActivity()
    return true
  }

  function closeSurface(asLock, token) {
    var requestedLock = asLock === true
    if (requestedLock) {
      if (!lockMode || String(token || "") !== lockToken) return false
    } else if (lockMode) {
      return false
    }

    open = false
    lockMode = false
    lockToken = ""
    lockWindowTag = ""
    lockState = "closed"
    resetInputFeedback()
    syncActivity()
    if (modalController) modalController.release(surfaceName)
    return true
  }

  function openPreview() {
    return openSurface(false, "", "")
  }

  function closePreview() {
    return closeSurface(false, "")
  }

  function openLock(token, windowTag) {
    return openSurface(true, token, windowTag)
  }

  function closeLock(token) {
    return closeSurface(true, token)
  }

  function setLockState(token, state) {
    var requestedState = String(state || "")
    if (!lockMode || String(token || "") !== lockToken) return false
    if (["arming", "captured", "fallback", "failure"].indexOf(requestedState) === -1)
      return false
    lockState = requestedState
    if (requestedState !== "captured") resetInputFeedback()
    return true
  }

  function togglePreview() {
    return open ? closePreview() : openPreview()
  }

  function statusObject() {
    return {
      open: open,
      mode: lockMode ? "lock" : (open ? "preview" : "closed"),
      lockMode: lockMode,
      lockWindowTag: lockWindowTag,
      lockState: lockState,
      routingDegraded: routingDegraded,
      primaryScreen: primaryScreenName,
      roles: currentRoles.roles,
      expectedSurfaceCount: open ? currentRoles.roles.length : 0,
      telemetryHealth: telemetryHealth,
      telemetryRevision: telemetryService ? telemetryService.revision : 0,
      history60: telemetryService ? telemetryService.history60.length : 0,
      history300: telemetryService ? telemetryService.history300.length : 0,
      collectorActive: collector ? collector.active : false,
      gpuRunning: collector ? collector.gpuRunning : false,
      gpuStartCount: collector ? collector.gpuStartCount : 0,
      interpolationActive: interpolation ? interpolation.active : false,
      interpolationFrames: interpolation ? interpolation.frameCount : 0,
      capsLockActive: capsLockActive,
      inputRejected: inputRejected,
      inputWatcherRunning: xkbWatcher.running
    }
  }

  onOpenChanged: syncActivity()

  Connections {
    target: root.modalController
    enabled: root.modalController !== null
    function onCloseRequested(surface) {
      if (surface === root.surfaceName && !root.lockMode) root.closePreview()
    }
  }

  Process {
    id: xkbWatcher
    command: [
      "python3",
      Quickshell.shellDir + "/scripts/machine-synoptic-xkb-watch.py"
    ]
    running: root.open && root.lockMode && root.lockState === "captured"
    stdout: SplitParser {
      onRead: function(data) { root.applyXkbEvent(data) }
    }
    stderr: StdioCollector { id: xkbWatcherStderr }
    onExited: function(exitCode) {
      root.capsLockActive = false
      if (root.open && root.lockMode && root.lockState === "captured" && exitCode !== 0)
        console.warn("Machine Synoptic XKB watcher exited:", xkbWatcherStderr.text)
    }
  }

  Timer {
    id: rejectionTimer
    interval: 2200
    repeat: false
    onTriggered: root.inputRejected = false
  }

  Variants {
    model: Quickshell.screens

    delegate: Instrument.MachineSynopticSurface {
      required property var modelData
      screen: modelData
      open: root.open
      lockMode: root.lockMode
      lockWindowTag: root.lockWindowTag
      lockState: root.lockState
      capsLockActive: root.capsLockActive
      inputRejected: root.inputRejected
      rejectionSequence: root.rejectionSequence
      role: root.roleForScreenName(String(modelData.name || ""))
      routingDegraded: root.routingDegraded
      telemetry: root.interpolation ? root.interpolation.snapshot : ({})
      history: root.telemetryService ? root.telemetryService.history300 : []
      clockText: root.clockText
      durationText: root.durationText()
      telemetryHealth: root.telemetryHealth
      cpuRotorPhase: root.interpolation ? root.interpolation.cpuRotorPhase : 0
      gpuRotorPhase: root.interpolation ? root.interpolation.gpuRotorPhase : 0
      onCloseRequested: if (!root.lockMode) root.closePreview()
    }
  }

  IpcHandler {
    target: "machineSynoptic"

    function openPreview(): string {
      return root.openPreview() ? "open" : (root.lockMode ? "locked" : "unavailable")
    }

    function closePreview(): string {
      return root.closePreview() ? "closed" : (root.lockMode ? "locked" : "closed")
    }

    function togglePreview(): string {
      if (root.lockMode) return "locked"
      root.togglePreview()
      return root.open ? "open" : "closed"
    }

    function openLock(token: string, windowTag: string): string {
      return root.openLock(token, windowTag) ? "locked" : "unavailable"
    }

    function closeLock(token: string): string {
      return root.closeLock(token) ? "closed" : "denied"
    }

    function setLockState(token: string, state: string): string {
      return root.setLockState(token, state) ? "updated" : "denied"
    }

    function status(): string {
      return JSON.stringify(root.statusObject())
    }
  }

  Timer {
    interval: 1000
    repeat: true
    running: root.open
    triggeredOnStart: true
    onTriggered: root.updateClock()
  }
}
