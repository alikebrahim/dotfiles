import QtQuick
import QtQml.Models
import Quickshell.Io

Item {
  id: root

  property var telemetryService: null
  property bool active: false
  property int sampleIntervalMs: 1000
  property int batchTimeoutMs: 650
  property string procRoot: "/proc"
  property string sysRoot: "/sys"
  property string discoveryScriptPath: ""
  property var powerService: null
  property bool gpuEnabled: true
  property int gpuRestartDelayMs: 5000

  property bool discoveryReady: false
  property int committedSamples: 0
  property int skippedCycles: 0
  property int gpuStartCount: 0
  property int gpuSamples: 0
  property double lastGpuAtMs: 0
  property var sourceErrors: ({})
  property var sensorFileSpecs: []

  readonly property bool gpuRunning: gpuProcess.running
  readonly property bool cycleOpen: _cycleOpen

  property bool _cycleOpen: false
  property double _cycleAtMs: 0
  property int _pendingCoreCount: 0
  property int _pendingSensorCount: 0
  property var _pendingCore: ({})
  property var _pendingSensors: ({})
  property var _pendingSample: ({})
  property var _sensorValues: ({})
  property string _pendingNetText: ""
  property string _pendingRouteText: ""
  property string _pendingDiskText: ""
  property var _previousCpu: null
  property var _previousNetwork: null
  property var _previousDisk: null
  property double _previousRateAtMs: 0
  property string _lastRouteInterface: ""
  property var _lastGpuSample: ({})
  property double _activeSinceMs: 0

  visible: false

  function finiteNumber(value) {
    var parsed = Number(value)
    return value !== null && value !== undefined && value !== "" && isFinite(parsed) ? parsed : null
  }

  function setSourceError(source, message) {
    var next = {}
    var keys = Object.keys(sourceErrors)
    for (var index = 0; index < keys.length; index++)
      if (keys[index] !== source) next[keys[index]] = sourceErrors[keys[index]]
    if (message) next[source] = String(message)
    sourceErrors = next
  }

  function ensureGroup(groupName) {
    if (!_pendingSample[groupName]) _pendingSample[groupName] = ({})
    return _pendingSample[groupName]
  }

  function parseProcStat(raw) {
    var line = String(raw || "").split(/\r?\n/)[0] || ""
    var fields = line.trim().split(/\s+/)
    if (fields.length < 9 || fields[0] !== "cpu") return null
    var values = []
    for (var index = 1; index <= 8; index++) {
      var value = finiteNumber(fields[index])
      if (value === null) return null
      values.push(value)
    }
    var idle = values[3] + values[4]
    var total = 0
    for (var valueIndex = 0; valueIndex < values.length; valueIndex++) total += values[valueIndex]
    var utilization = null
    if (_previousCpu !== null) {
      var totalDelta = total - _previousCpu.total
      var idleDelta = idle - _previousCpu.idle
      if (totalDelta > 0 && idleDelta >= 0)
        utilization = Math.max(0, Math.min(100, 100 * (totalDelta - idleDelta) / totalDelta))
    }
    _previousCpu = { total: total, idle: idle }
    return utilization
  }

  function parseMeminfo(raw) {
    var fields = {}
    var lines = String(raw || "").split(/\r?\n/)
    for (var index = 0; index < lines.length; index++) {
      var match = lines[index].match(/^([A-Za-z_()]+):\s+(\d+)\s+kB$/)
      if (match) fields[match[1]] = Number(match[2]) * 1024
    }
    var total = finiteNumber(fields.MemTotal)
    var available = finiteNumber(fields.MemAvailable)
    var swapTotal = finiteNumber(fields.SwapTotal)
    var swapFree = finiteNumber(fields.SwapFree)
    if (total === null || available === null) return null
    return {
      ramTotalBytes: total,
      ramUsedBytes: Math.max(0, total - available),
      swapTotalBytes: swapTotal,
      swapUsedBytes: swapTotal === null || swapFree === null ? null : Math.max(0, swapTotal - swapFree)
    }
  }

  function parsePressure(raw) {
    var result = { some: null, full: null }
    var lines = String(raw || "").split(/\r?\n/)
    for (var index = 0; index < lines.length; index++) {
      var match = lines[index].match(/^(some|full)\s+.*\bavg10=(\d+(?:\.\d+)?)/)
      if (match) result[match[1]] = Number(match[2])
    }
    return result
  }

  function parseUptime(raw) {
    var value = finiteNumber(String(raw || "").trim().split(/\s+/)[0])
    return value === null || value < 0 ? null : value
  }

  function parseDefaultRoute(raw) {
    var lines = String(raw || "").split(/\r?\n/)
    for (var index = 1; index < lines.length; index++) {
      var fields = lines[index].trim().split(/\s+/)
      if (fields.length >= 4 && fields[1] === "00000000") return fields[0]
    }
    return ""
  }

  function parseNetworkCounters(raw, preferredInterface) {
    var rx = 0
    var tx = 0
    var matched = false
    var fallbackRx = 0
    var fallbackTx = 0
    var fallbackMatched = false
    var lines = String(raw || "").split(/\r?\n/)
    for (var index = 2; index < lines.length; index++) {
      var colon = lines[index].indexOf(":")
      if (colon < 0) continue
      var interfaceName = lines[index].slice(0, colon).trim()
      var fields = lines[index].slice(colon + 1).trim().split(/\s+/)
      if (fields.length < 16) continue
      var currentRx = finiteNumber(fields[0])
      var currentTx = finiteNumber(fields[8])
      if (currentRx === null || currentTx === null) continue
      if (interfaceName !== "lo") {
        fallbackRx += currentRx
        fallbackTx += currentTx
        fallbackMatched = true
      }
      if (preferredInterface !== "" && interfaceName === preferredInterface) {
        rx = currentRx
        tx = currentTx
        matched = true
      }
    }
    if (matched) return { rx: rx, tx: tx }
    return fallbackMatched ? { rx: fallbackRx, tx: fallbackTx } : null
  }

  function parseDiskCounters(raw) {
    var readBytes = 0
    var writeBytes = 0
    var matched = false
    var lines = String(raw || "").split(/\r?\n/)
    for (var index = 0; index < lines.length; index++) {
      var fields = lines[index].trim().split(/\s+/)
      if (fields.length < 14) continue
      var name = fields[2]
      var wholeDevice = /^(?:nvme\d+n\d+|sd[a-z]+|vd[a-z]+|xvd[a-z]+|mmcblk\d+)$/.test(name)
      if (!wholeDevice) continue
      var readSectors = finiteNumber(fields[5])
      var writeSectors = finiteNumber(fields[9])
      if (readSectors === null || writeSectors === null) continue
      readBytes += readSectors * 512
      writeBytes += writeSectors * 512
      matched = true
    }
    return matched ? { readBytes: readBytes, writeBytes: writeBytes } : null
  }

  function rate(current, previous, elapsedSeconds) {
    if (current === null || previous === null || elapsedSeconds <= 0 || current < previous) return null
    return (current - previous) / elapsedSeconds
  }

  function mapBatteryState(raw) {
    var state = String(raw || "").trim().toLowerCase()
    if (state === "charging") return "charging"
    if (state === "discharging") return "discharging"
    if (state === "full") return "fully-charged"
    if (state === "not charging") return "pending-charge"
    if (state === "empty") return "empty"
    return "unknown"
  }

  function applyCoreResult(key, raw) {
    if (!_cycleOpen || _pendingCore[key] !== true) return
    _pendingCore[key] = false
    _pendingCoreCount--

    if (key === "stat") {
      var utilization = parseProcStat(raw)
      if (utilization !== null) ensureGroup("cpu").utilization = utilization
    } else if (key === "meminfo") {
      var memory = parseMeminfo(raw)
      if (memory) _pendingSample.memory = memory
    } else if (key === "netdev") {
      _pendingNetText = String(raw || "")
    } else if (key === "route") {
      _pendingRouteText = String(raw || "")
    } else if (key === "diskstats") {
      _pendingDiskText = String(raw || "")
    } else if (key === "psiCpu") {
      var cpuPressure = parsePressure(raw)
      ensureGroup("cpu").pressureSome = cpuPressure.some
      ensureGroup("cpu").pressureFull = cpuPressure.full
    } else if (key === "psiMemory") {
      var memoryPressure = parsePressure(raw)
      ensureGroup("memory").pressureSome = memoryPressure.some
      ensureGroup("memory").pressureFull = memoryPressure.full
    } else if (key === "psiIo") {
      var ioPressure = parsePressure(raw)
      ensureGroup("io").pressureSome = ioPressure.some
      ensureGroup("io").pressureFull = ioPressure.full
    } else if (key === "uptime") {
      ensureGroup("time").uptimeSeconds = parseUptime(raw)
    }
    maybeCommitCycle()
  }

  function failCoreResult(key, error) {
    setSourceError(key, String(error || "load failed"))
    applyCoreResult(key, "")
  }

  function applySensorResult(specId, kind, raw) {
    if (!_cycleOpen || _pendingSensors[specId] !== true) return
    _pendingSensors[specId] = false
    _pendingSensorCount--
    var text = String(raw || "").trim()
    if (kind === "batteryStatus") _sensorValues[kind] = text
    else {
      var value = finiteNumber(text)
      if (value !== null) {
        if (!_sensorValues[kind]) _sensorValues[kind] = []
        _sensorValues[kind].push(value)
      }
    }
    maybeCommitCycle()
  }

  function failSensorResult(specId, kind, error) {
    setSourceError("sensor:" + kind, String(error || "load failed"))
    applySensorResult(specId, kind, "")
  }

  function average(values, scale) {
    if (!Array.isArray(values) || values.length === 0) return null
    var total = 0
    for (var index = 0; index < values.length; index++) total += values[index]
    return total / values.length / scale
  }

  function maximum(values, scale) {
    if (!Array.isArray(values) || values.length === 0) return null
    var result = values[0]
    for (var index = 1; index < values.length; index++) result = Math.max(result, values[index])
    return result / scale
  }

  function firstValue(values, scale) {
    if (!Array.isArray(values) || values.length === 0) return null
    return values[0] / scale
  }

  function collectSensorGroups() {
    var frequency = average(_sensorValues.frequency, 1000)
    var cpuTemp = firstValue(_sensorValues.cpuTemperature, 1000)
    var cpuFan = firstValue(_sensorValues.cpuFan, 1)
    var gpuFan = firstValue(_sensorValues.gpuFan, 1)
    var nvme = maximum(_sensorValues.nvmeTemperature, 1000)
    var dimm = maximum(_sensorValues.dimmTemperature, 1000)

    if (frequency !== null) ensureGroup("cpu").frequencyMhz = frequency
    if (cpuTemp !== null) ensureGroup("cpu").packageTempC = cpuTemp
    if (cpuFan !== null) ensureGroup("thermal").cpuFanRpm = cpuFan
    if (gpuFan !== null) ensureGroup("thermal").gpuFanRpm = gpuFan
    if (nvme !== null) ensureGroup("thermal").nvmeMaxC = nvme
    if (dimm !== null) ensureGroup("thermal").dimmMaxC = dimm
  }

  function collectPowerGroup() {
    if (powerService) {
      _pendingSample.power = {
        batteryPresent: powerService.present === true,
        batteryPercent: powerService.percentage,
        batteryState: powerService.state,
        onBattery: powerService.onBattery === true
      }
      return
    }
    var present = firstValue(_sensorValues.batteryPresent, 1)
    var percentage = firstValue(_sensorValues.batteryPercent, 1)
    var mainsOnline = firstValue(_sensorValues.mainsOnline, 1)
    var status = mapBatteryState(_sensorValues.batteryStatus)
    if (present !== null || percentage !== null || mainsOnline !== null || status !== "unknown") {
      _pendingSample.power = {
        batteryPresent: present === null ? percentage !== null : present > 0,
        batteryPercent: percentage,
        batteryState: status,
        onBattery: mainsOnline === null ? status === "discharging" : mainsOnline <= 0
      }
    }
  }

  function collectRates() {
    var routeInterface = parseDefaultRoute(_pendingRouteText)
    if (routeInterface !== "") _lastRouteInterface = routeInterface
    var network = parseNetworkCounters(_pendingNetText, _lastRouteInterface)
    var disk = parseDiskCounters(_pendingDiskText)
    var elapsed = _previousRateAtMs > 0 ? (_cycleAtMs - _previousRateAtMs) / 1000 : 0

    if (network) {
      var networkGroup = ensureGroup("io")
      networkGroup.networkRxBps = _previousNetwork ? rate(network.rx, _previousNetwork.rx, elapsed) : null
      networkGroup.networkTxBps = _previousNetwork ? rate(network.tx, _previousNetwork.tx, elapsed) : null
      _previousNetwork = network
    }
    if (disk) {
      var diskGroup = ensureGroup("io")
      diskGroup.diskReadBps = _previousDisk ? rate(disk.readBytes, _previousDisk.readBytes, elapsed) : null
      diskGroup.diskWriteBps = _previousDisk ? rate(disk.writeBytes, _previousDisk.writeBytes, elapsed) : null
      _previousDisk = disk
    }
    _previousRateAtMs = _cycleAtMs
  }

  function collectGpuGroup() {
    if (lastGpuAtMs <= 0 || _cycleAtMs - lastGpuAtMs > Math.max(2500, sampleIntervalMs * 2.5)) return
    _pendingSample.gpu = _lastGpuSample
  }

  function commitCycle() {
    if (!_cycleOpen) return
    cycleTimeout.stop()
    if (!telemetryService) {
      setSourceError("sample", "telemetry service is unavailable")
      _cycleOpen = false
      return
    }
    collectRates()
    collectSensorGroups()
    collectPowerGroup()
    collectGpuGroup()
    ensureGroup("time").visibleSeconds = _activeSinceMs > 0 ? (_cycleAtMs - _activeSinceMs) / 1000 : 0
    var accepted = telemetryService.acceptSample(_pendingSample, _cycleAtMs)
    if (accepted) {
      committedSamples++
      setSourceError("sample", "")
    } else {
      setSourceError("sample", telemetryService.lastError)
    }
    _cycleOpen = false
  }

  function maybeCommitCycle() {
    if (_cycleOpen && _pendingCoreCount <= 0 && _pendingSensorCount <= 0) commitCycle()
  }

  function beginCoreRead(key, fileView) {
    _pendingCore[key] = true
    _pendingCoreCount++
    fileView.reload()
  }

  function beginCycle() {
    if (!active) return false
    if (_cycleOpen) {
      skippedCycles++
      return false
    }
    _cycleOpen = true
    _cycleAtMs = Date.now()
    _pendingCore = ({})
    _pendingSensors = ({})
    _pendingSample = ({})
    _sensorValues = ({})
    _pendingCoreCount = 0
    _pendingSensorCount = 0
    _pendingNetText = ""
    _pendingRouteText = ""
    _pendingDiskText = ""

    beginCoreRead("stat", statFile)
    beginCoreRead("meminfo", meminfoFile)
    beginCoreRead("netdev", netdevFile)
    beginCoreRead("route", routeFile)
    beginCoreRead("diskstats", diskstatsFile)
    beginCoreRead("psiCpu", psiCpuFile)
    beginCoreRead("psiMemory", psiMemoryFile)
    beginCoreRead("psiIo", psiIoFile)
    beginCoreRead("uptime", uptimeFile)

    for (var index = 0; index < sensorViews.count; index++) {
      var view = sensorViews.objectAt(index)
      if (!view) continue
      _pendingSensors[view.spec.id] = true
      _pendingSensorCount++
      view.reload()
    }
    cycleTimeout.restart()
    maybeCommitCycle()
    return true
  }

  function addSensorSpec(list, id, kind, path) {
    if (path) list.push({ id: id, kind: kind, path: String(path) })
  }

  function addChannelSpec(list, id, kind, channel) {
    if (channel && channel.input) addSensorSpec(list, id, kind, channel.input)
  }

  function buildSensorSpecs(discovery) {
    var specs = []
    var sensors = discovery.sensors || ({})
    addChannelSpec(specs, "cpu-package", "cpuTemperature", sensors.cpuPackage || sensors.cpuFallback)
    addChannelSpec(specs, "cpu-fan", "cpuFan", sensors.cpuFan)
    addChannelSpec(specs, "gpu-fan", "gpuFan", sensors.gpuFan)
    var nvme = Array.isArray(sensors.nvmeComposite) ? sensors.nvmeComposite : []
    var dimm = Array.isArray(sensors.dimmTemperature) ? sensors.dimmTemperature : []
    for (var nvmeIndex = 0; nvmeIndex < nvme.length; nvmeIndex++)
      addChannelSpec(specs, "nvme-" + nvmeIndex, "nvmeTemperature", nvme[nvmeIndex])
    for (var dimmIndex = 0; dimmIndex < dimm.length; dimmIndex++)
      addChannelSpec(specs, "dimm-" + dimmIndex, "dimmTemperature", dimm[dimmIndex])
    var cpufreq = Array.isArray(discovery.cpufreq) ? discovery.cpufreq : []
    for (var frequencyIndex = 0; frequencyIndex < cpufreq.length; frequencyIndex++)
      addSensorSpec(specs, "frequency-" + frequencyIndex, "frequency", cpufreq[frequencyIndex])
    var power = discovery.power || ({})
    var battery = power.battery || ({})
    var mains = power.mains || ({})
    addSensorSpec(specs, "battery-present", "batteryPresent", battery.present)
    addSensorSpec(specs, "battery-percent", "batteryPercent", battery.capacity)
    addSensorSpec(specs, "battery-status", "batteryStatus", battery.status)
    addSensorSpec(specs, "mains-online", "mainsOnline", mains.online)
    sensorFileSpecs = specs
  }

  function applyDiscoveryOutput(raw) {
    if (!telemetryService) {
      setSourceError("discovery", "telemetry service is unavailable")
      return false
    }
    if (!telemetryService.applyDiscoveryJson(raw)) {
      setSourceError("discovery", telemetryService.lastError)
      return false
    }
    buildSensorSpecs(telemetryService.sensorPaths)
    discoveryReady = true
    setSourceError("discovery", "")
    Qt.callLater(beginCycle)
    return true
  }

  function startDiscovery() {
    if (!active || discoveryScriptPath === "" || discoveryProcess.running) return
    discoveryProcess.command = ["python3", discoveryScriptPath, "--sysfs-root", sysRoot]
    discoveryProcess.running = true
  }

  function parseGpuLine(raw) {
    var line = String(raw || "").trim()
    if (line === "") return false
    var parts = line.split(",")
    if (parts.length !== 8) {
      setSourceError("gpu", "unexpected nvidia-smi field count")
      return false
    }
    var values = []
    for (var index = 0; index < parts.length; index++) values.push(finiteNumber(parts[index].trim()))
    if (values[0] === null && values[1] === null && values[2] === null && values[4] === null) {
      setSourceError("gpu", "nvidia-smi returned no usable values")
      return false
    }
    _lastGpuSample = {
      utilization: values[0],
      temperatureC: values[1],
      powerW: values[2],
      powerLimitW: values[3],
      vramUsedMiB: values[4],
      vramTotalMiB: values[5],
      graphicsClockMhz: values[6],
      memoryClockMhz: values[7]
    }
    lastGpuAtMs = Date.now()
    gpuSamples++
    setSourceError("gpu", "")
    return true
  }

  function startGpu() {
    if (active && gpuEnabled && !gpuProcess.running) gpuProcess.running = true
  }

  function start() {
    if (!active || !telemetryService) return
    if (_activeSinceMs <= 0) _activeSinceMs = Date.now()
    telemetryService.active = true
    startDiscovery()
    startGpu()
    beginCycle()
  }

  function stop() {
    sampleTimer.stop()
    cycleTimeout.stop()
    gpuRestart.stop()
    if (gpuProcess.running) gpuProcess.running = false
    if (discoveryProcess.running) discoveryProcess.running = false
    _cycleOpen = false
    if (telemetryService) telemetryService.active = false
  }

  onActiveChanged: {
    if (active) Qt.callLater(start)
    else stop()
  }

  Component.onCompleted: if (active) Qt.callLater(start)

  Instantiator {
    id: sensorViews
    model: root.sensorFileSpecs

    delegate: FileView {
      required property var modelData
      readonly property var spec: modelData
      path: spec.path
      preload: root.active
      printErrors: false
      onLoaded: root.applySensorResult(spec.id, spec.kind, text())
      onLoadFailed: function(error) { root.failSensorResult(spec.id, spec.kind, error) }
    }
  }

  FileView {
    id: statFile
    path: root.procRoot + "/stat"
    preload: root.active
    printErrors: false
    onLoaded: root.applyCoreResult("stat", text())
    onLoadFailed: function(error) { root.failCoreResult("stat", error) }
  }

  FileView {
    id: meminfoFile
    path: root.procRoot + "/meminfo"
    preload: root.active
    printErrors: false
    onLoaded: root.applyCoreResult("meminfo", text())
    onLoadFailed: function(error) { root.failCoreResult("meminfo", error) }
  }

  FileView {
    id: netdevFile
    path: root.procRoot + "/net/dev"
    preload: root.active
    printErrors: false
    onLoaded: root.applyCoreResult("netdev", text())
    onLoadFailed: function(error) { root.failCoreResult("netdev", error) }
  }

  FileView {
    id: routeFile
    path: root.procRoot + "/net/route"
    preload: root.active
    printErrors: false
    onLoaded: root.applyCoreResult("route", text())
    onLoadFailed: function(error) { root.failCoreResult("route", error) }
  }

  FileView {
    id: diskstatsFile
    path: root.procRoot + "/diskstats"
    preload: root.active
    printErrors: false
    onLoaded: root.applyCoreResult("diskstats", text())
    onLoadFailed: function(error) { root.failCoreResult("diskstats", error) }
  }

  FileView {
    id: psiCpuFile
    path: root.procRoot + "/pressure/cpu"
    preload: root.active
    printErrors: false
    onLoaded: root.applyCoreResult("psiCpu", text())
    onLoadFailed: function(error) { root.failCoreResult("psiCpu", error) }
  }

  FileView {
    id: psiMemoryFile
    path: root.procRoot + "/pressure/memory"
    preload: root.active
    printErrors: false
    onLoaded: root.applyCoreResult("psiMemory", text())
    onLoadFailed: function(error) { root.failCoreResult("psiMemory", error) }
  }

  FileView {
    id: psiIoFile
    path: root.procRoot + "/pressure/io"
    preload: root.active
    printErrors: false
    onLoaded: root.applyCoreResult("psiIo", text())
    onLoadFailed: function(error) { root.failCoreResult("psiIo", error) }
  }

  FileView {
    id: uptimeFile
    path: root.procRoot + "/uptime"
    preload: root.active
    printErrors: false
    onLoaded: root.applyCoreResult("uptime", text())
    onLoadFailed: function(error) { root.failCoreResult("uptime", error) }
  }

  Process {
    id: discoveryProcess
    stdout: StdioCollector { id: discoveryStdout }
    stderr: StdioCollector { id: discoveryStderr }
    onExited: function(exitCode) {
      if (exitCode === 0) root.applyDiscoveryOutput(discoveryStdout.text)
      else root.setSourceError("discovery", String(discoveryStderr.text || "discovery process failed").trim())
    }
  }

  Process {
    id: gpuProcess
    command: [
      "nvidia-smi",
      "--id=0",
      "--query-gpu=utilization.gpu,temperature.gpu,power.draw,enforced.power.limit,memory.used,memory.total,clocks.current.graphics,clocks.current.memory",
      "--format=csv,noheader,nounits",
      "--loop=1"
    ]
    stdout: SplitParser {
      onRead: function(data) { root.parseGpuLine(data) }
    }
    stderr: StdioCollector { id: gpuStderr }
    onStarted: root.gpuStartCount++
    onExited: function(exitCode) {
      if (!root.active || !root.gpuEnabled) return
      root.setSourceError("gpu", String(gpuStderr.text || "nvidia-smi exited with code " + exitCode).trim())
      gpuRestart.restart()
    }
  }

  Timer {
    id: sampleTimer
    interval: Math.max(250, root.sampleIntervalMs)
    repeat: true
    running: root.active
    onTriggered: root.beginCycle()
  }

  Timer {
    id: cycleTimeout
    interval: Math.max(100, root.batchTimeoutMs)
    repeat: false
    onTriggered: root.commitCycle()
  }

  Timer {
    id: gpuRestart
    interval: Math.max(1000, root.gpuRestartDelayMs)
    repeat: false
    onTriggered: root.startGpu()
  }
}
