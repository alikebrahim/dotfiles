import QtQuick

Item {
  id: root

  property bool active: false
  property int staleAfterMs: 3200
  property int revision: 0
  property double sampledAtMs: 0
  property double sampleAgeMs: -1
  property string health: "acquiring"
  property var snapshot: emptySnapshot()
  property var history60: []
  property var history300: []
  property var sensorPaths: ({})
  property string lastError: ""
  property var sourceSampledAtMs: ({})

  visible: false

  function emptySnapshot() {
    return {
      cpu: {
        utilization: null,
        frequencyMhz: null,
        packageTempC: null,
        pressureSome: null,
        pressureFull: null
      },
      gpu: {
        utilization: null,
        temperatureC: null,
        powerW: null,
        powerLimitW: null,
        vramUsedMiB: null,
        vramTotalMiB: null,
        graphicsClockMhz: null,
        memoryClockMhz: null
      },
      memory: {
        ramUsedBytes: null,
        ramTotalBytes: null,
        swapUsedBytes: null,
        swapTotalBytes: null,
        pressureSome: null,
        pressureFull: null
      },
      io: {
        networkRxBps: null,
        networkTxBps: null,
        diskReadBps: null,
        diskWriteBps: null,
        pressureSome: null,
        pressureFull: null
      },
      thermal: {
        cpuFanRpm: null,
        gpuFanRpm: null,
        nvmeMaxC: null,
        dimmMaxC: null
      },
      power: {
        batteryPresent: null,
        batteryPercent: null,
        batteryState: "unknown",
        onBattery: null
      },
      time: {
        uptimeSeconds: null,
        visibleSeconds: null
      },
      freshness: ({})
    }
  }

  function numberOrNull(value, minimum, maximum) {
    if (value === null || value === undefined || value === "") return null
    var parsed = Number(value)
    if (!isFinite(parsed)) return null
    if (minimum !== null && parsed < minimum) return null
    if (maximum !== null && parsed > maximum) return null
    return parsed
  }

  function numberSchema() {
    return {
      cpu: {
        utilization: [0, 100],
        frequencyMhz: [0, 20000],
        packageTempC: [-100, 250],
        pressureSome: [0, 100],
        pressureFull: [0, 100]
      },
      gpu: {
        utilization: [0, 100],
        temperatureC: [-100, 250],
        powerW: [0, 2000],
        powerLimitW: [0, 2000],
        vramUsedMiB: [0, 1000000],
        vramTotalMiB: [0, 1000000],
        graphicsClockMhz: [0, 20000],
        memoryClockMhz: [0, 50000]
      },
      memory: {
        ramUsedBytes: [0, null],
        ramTotalBytes: [0, null],
        swapUsedBytes: [0, null],
        swapTotalBytes: [0, null],
        pressureSome: [0, 100],
        pressureFull: [0, 100]
      },
      io: {
        networkRxBps: [0, null],
        networkTxBps: [0, null],
        diskReadBps: [0, null],
        diskWriteBps: [0, null],
        pressureSome: [0, 100],
        pressureFull: [0, 100]
      },
      thermal: {
        cpuFanRpm: [0, 100000],
        gpuFanRpm: [0, 100000],
        nvmeMaxC: [-100, 250],
        dimmMaxC: [-100, 250]
      },
      time: {
        uptimeSeconds: [0, null],
        visibleSeconds: [0, null]
      }
    }
  }

  function mergeNumberGroup(groupName, input, nextSnapshot, nextTimes, atMs) {
    var fields = numberSchema()[groupName]
    var previous = snapshot[groupName]
    var candidate = input && typeof input === "object" && !Array.isArray(input) ? input : ({})
    var next = {}
    var valid = 0
    var names = Object.keys(fields)
    for (var index = 0; index < names.length; index++) {
      var name = names[index]
      var range = fields[name]
      var parsed = candidate.hasOwnProperty(name)
        ? numberOrNull(candidate[name], range[0], range[1])
        : null
      if (parsed !== null) {
        next[name] = parsed
        valid++
      } else {
        next[name] = previous[name]
      }
    }
    nextSnapshot[groupName] = next
    if (valid > 0) nextTimes[groupName] = atMs
    return valid
  }

  function mergePowerGroup(input, nextSnapshot, nextTimes, atMs) {
    var previous = snapshot.power
    var candidate = input && typeof input === "object" && !Array.isArray(input) ? input : ({})
    var next = {
      batteryPresent: previous.batteryPresent,
      batteryPercent: previous.batteryPercent,
      batteryState: previous.batteryState,
      onBattery: previous.onBattery
    }
    var valid = 0
    if (typeof candidate.batteryPresent === "boolean") {
      next.batteryPresent = candidate.batteryPresent
      valid++
    }
    var percentage = candidate.hasOwnProperty("batteryPercent")
      ? numberOrNull(candidate.batteryPercent, 0, 100)
      : null
    if (percentage !== null) {
      next.batteryPercent = percentage
      valid++
    }
    var allowedStates = [
      "unknown", "charging", "discharging", "empty", "fully-charged",
      "pending-charge", "pending-discharge"
    ]
    var state = String(candidate.batteryState || "").toLowerCase()
    if (allowedStates.indexOf(state) !== -1) {
      next.batteryState = state
      valid++
    }
    if (typeof candidate.onBattery === "boolean") {
      next.onBattery = candidate.onBattery
      valid++
    }
    nextSnapshot.power = next
    if (valid > 0) nextTimes.power = atMs
    return valid
  }

  function freshnessAt(nowMs, times) {
    var result = {}
    var names = ["cpu", "gpu", "memory", "io", "thermal", "power", "time"]
    for (var index = 0; index < names.length; index++) {
      var name = names[index]
      var sampled = Number(times[name] || 0)
      var age = sampled > 0 ? Math.max(0, nowMs - sampled) : -1
      result[name] = {
        sampledAtMs: sampled,
        ageMs: age,
        state: sampled <= 0 ? "unavailable" : (age > staleAfterMs ? "stale" : "nominal")
      }
    }
    return result
  }

  function withFreshness(value, nowMs, times) {
    return {
      cpu: value.cpu,
      gpu: value.gpu,
      memory: value.memory,
      io: value.io,
      thermal: value.thermal,
      power: value.power,
      time: value.time,
      freshness: freshnessAt(nowMs, times)
    }
  }

  function historyEntry(value, atMs) {
    return {
      sampledAtMs: atMs,
      cpuUtilization: value.cpu.utilization,
      gpuUtilization: value.gpu.utilization,
      cpuTempC: value.cpu.packageTempC,
      gpuTempC: value.gpu.temperatureC,
      networkBps: value.io.networkRxBps === null || value.io.networkTxBps === null
        ? null : value.io.networkRxBps + value.io.networkTxBps,
      diskBps: value.io.diskReadBps === null || value.io.diskWriteBps === null
        ? null : value.io.diskReadBps + value.io.diskWriteBps,
      ioPressure: value.io.pressureSome
    }
  }

  function appendBounded(list, value, maximum) {
    var next = Array.isArray(list) ? list.slice() : []
    next.push(value)
    if (next.length > maximum) next = next.slice(next.length - maximum)
    return next
  }

  function acceptSample(candidate, atMs) {
    if (!candidate || typeof candidate !== "object" || Array.isArray(candidate)) {
      lastError = "telemetry sample must be an object"
      return false
    }
    var sampled = numberOrNull(atMs, 1, null)
    if (sampled === null) {
      lastError = "telemetry timestamp is invalid"
      return false
    }

    var nextSnapshot = emptySnapshot()
    var nextTimes = {}
    var priorNames = Object.keys(sourceSampledAtMs)
    for (var priorIndex = 0; priorIndex < priorNames.length; priorIndex++)
      nextTimes[priorNames[priorIndex]] = sourceSampledAtMs[priorNames[priorIndex]]

    var valid = 0
    valid += mergeNumberGroup("cpu", candidate.cpu, nextSnapshot, nextTimes, sampled)
    valid += mergeNumberGroup("gpu", candidate.gpu, nextSnapshot, nextTimes, sampled)
    valid += mergeNumberGroup("memory", candidate.memory, nextSnapshot, nextTimes, sampled)
    valid += mergeNumberGroup("io", candidate.io, nextSnapshot, nextTimes, sampled)
    valid += mergeNumberGroup("thermal", candidate.thermal, nextSnapshot, nextTimes, sampled)
    valid += mergePowerGroup(candidate.power, nextSnapshot, nextTimes, sampled)
    valid += mergeNumberGroup("time", candidate.time, nextSnapshot, nextTimes, sampled)

    if (valid === 0) {
      lastError = "telemetry sample contains no valid values"
      return false
    }

    sourceSampledAtMs = nextTimes
    sampledAtMs = sampled
    snapshot = withFreshness(nextSnapshot, sampled, nextTimes)
    var entry = historyEntry(snapshot, sampled)
    history60 = appendBounded(history60, entry, 60)
    history300 = appendBounded(history300, entry, 300)
    revision++
    lastError = ""
    refreshHealth(sampled)
    return true
  }

  function refreshHealth(nowMs) {
    var now = numberOrNull(nowMs, 1, null)
    if (now === null) return
    sampleAgeMs = sampledAtMs > 0 ? Math.max(0, now - sampledAtMs) : -1
    snapshot = withFreshness(snapshot, now, sourceSampledAtMs)
    if (revision === 0) {
      health = "acquiring"
      return
    }
    if (sampleAgeMs > staleAfterMs) {
      health = "stale"
      return
    }
    var required = ["cpu", "gpu", "memory", "io", "thermal", "power", "time"]
    for (var index = 0; index < required.length; index++) {
      if (snapshot.freshness[required[index]].state !== "nominal") {
        health = "degraded"
        return
      }
    }
    health = "nominal"
  }

  function applyDiscoveryJson(raw) {
    try {
      var parsed = JSON.parse(String(raw || ""))
      if (!parsed || parsed.schemaVersion !== 1 || !parsed.sensors
          || !Array.isArray(parsed.cpufreq))
        throw new Error("telemetry discovery schema is invalid")
      sensorPaths = parsed
      lastError = ""
      return true
    } catch (error) {
      lastError = String(error)
      return false
    }
  }

  function reset() {
    revision = 0
    sampledAtMs = 0
    sampleAgeMs = -1
    health = "acquiring"
    snapshot = emptySnapshot()
    history60 = []
    history300 = []
    sensorPaths = ({})
    sourceSampledAtMs = ({})
    lastError = ""
  }

  Timer {
    interval: 1000
    repeat: true
    running: root.active
    onTriggered: root.refreshHealth(Date.now())
  }
}
