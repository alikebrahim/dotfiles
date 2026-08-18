import QtQuick

Item {
  id: root

  property bool active: false
  property int frameIntervalMs: 33
  property int interpolationDurationMs: 850
  property var sourceSnapshot: ({})
  property int sourceRevision: 0
  property var snapshot: emptySnapshot()
  property real cpuRotorPhase: 0
  property real gpuRotorPhase: 0
  property real carrierPhase: 0
  property int frameCount: 0

  property var _fromSnapshot: emptySnapshot()
  property var _toSnapshot: emptySnapshot()
  property double _transitionStartedAtMs: 0
  property double _lastFrameAtMs: 0

  visible: false

  function emptySnapshot() {
    return {
      cpu: {},
      gpu: {},
      memory: {},
      io: {},
      thermal: {},
      power: {},
      time: {},
      freshness: {}
    }
  }

  function clone(value) {
    try {
      return JSON.parse(JSON.stringify(value || emptySnapshot()))
    } catch (error) {
      return emptySnapshot()
    }
  }

  function finite(value) {
    var parsed = Number(value)
    return value !== null && value !== undefined && value !== "" && isFinite(parsed)
  }

  function valueAt(value, groupName, fieldName) {
    if (!value || !value[groupName]) return null
    return value[groupName][fieldName]
  }

  function interpolateNumber(fromValue, toValue, progress) {
    if (!finite(toValue)) return progress >= 1 ? toValue : fromValue
    if (!finite(fromValue)) return Number(toValue)
    return Number(fromValue) + (Number(toValue) - Number(fromValue)) * progress
  }

  function blendGroup(groupName, fieldNames, progress) {
    var result = {}
    for (var index = 0; index < fieldNames.length; index++) {
      var fieldName = fieldNames[index]
      result[fieldName] = interpolateNumber(
        valueAt(_fromSnapshot, groupName, fieldName),
        valueAt(_toSnapshot, groupName, fieldName),
        progress
      )
    }
    return result
  }

  function eased(progress) {
    var clamped = Math.max(0, Math.min(1, progress))
    return 1 - Math.pow(1 - clamped, 3)
  }

  function interpolatedSnapshot(progress) {
    return {
      cpu: blendGroup("cpu", [
        "utilization", "frequencyMhz", "packageTempC", "pressureSome", "pressureFull"
      ], progress),
      gpu: blendGroup("gpu", [
        "utilization", "temperatureC", "powerW", "powerLimitW", "vramUsedMiB",
        "vramTotalMiB", "graphicsClockMhz", "memoryClockMhz"
      ], progress),
      memory: blendGroup("memory", [
        "ramUsedBytes", "ramTotalBytes", "swapUsedBytes", "swapTotalBytes",
        "pressureSome", "pressureFull"
      ], progress),
      io: blendGroup("io", [
        "networkRxBps", "networkTxBps", "diskReadBps", "diskWriteBps",
        "pressureSome", "pressureFull"
      ], progress),
      thermal: blendGroup("thermal", [
        "cpuFanRpm", "gpuFanRpm", "nvmeMaxC", "dimmMaxC"
      ], progress),
      power: _toSnapshot.power || {},
      time: blendGroup("time", ["uptimeSeconds", "visibleSeconds"], progress),
      freshness: _toSnapshot.freshness || {}
    }
  }

  function captureTarget() {
    _fromSnapshot = clone(snapshot)
    _toSnapshot = clone(sourceSnapshot)
    _transitionStartedAtMs = Date.now()
    if (!active) snapshot = clone(sourceSnapshot)
  }

  function compressedRotorRate(rpm) {
    if (!finite(rpm) || Number(rpm) <= 0) return 0
    return 0.08 + 0.92 * Math.min(1, Number(rpm) / 5000)
  }

  function advanceFrame(nowMs) {
    var elapsedMs = _lastFrameAtMs > 0 ? Math.max(0, Math.min(100, nowMs - _lastFrameAtMs)) : frameIntervalMs
    _lastFrameAtMs = nowMs
    var transitionElapsed = _transitionStartedAtMs > 0 ? nowMs - _transitionStartedAtMs : interpolationDurationMs
    var progress = interpolationDurationMs <= 0 ? 1 : transitionElapsed / interpolationDurationMs
    snapshot = interpolatedSnapshot(eased(progress))

    var cpuRate = compressedRotorRate(valueAt(snapshot, "thermal", "cpuFanRpm"))
    var gpuRate = compressedRotorRate(valueAt(snapshot, "thermal", "gpuFanRpm"))
    cpuRotorPhase = (cpuRotorPhase + cpuRate * elapsedMs / 1000) % 1
    gpuRotorPhase = (gpuRotorPhase + gpuRate * elapsedMs / 1000) % 1
    carrierPhase = (carrierPhase + elapsedMs / 12000) % 1
    frameCount++
  }

  onSourceRevisionChanged: if (sourceRevision > 0) captureTarget()
  onActiveChanged: {
    _lastFrameAtMs = Date.now()
    if (active && sourceRevision > 0) captureTarget()
    else if (!active) snapshot = clone(sourceSnapshot)
  }

  Timer {
    interval: Math.max(16, root.frameIntervalMs)
    repeat: true
    running: root.active
    onTriggered: root.advanceFrame(Date.now())
  }
}
