import QtQuick
import Quickshell.Bluetooth

// BlueZ, exposed by Quickshell.Bluetooth, is the only Bluetooth-state
// authority. The command transport contributes only the existing per-login
// mutation gate; no bluetoothctl reads or writes are issued here.
Item {
  id: root

  required property QtObject transport
  property var backend: Bluetooth

  readonly property var adapter: backend ? backend.defaultAdapter : null
  readonly property var nativeDevices: deviceValues()
  readonly property bool backendReady: backend !== null && backend !== undefined
  readonly property bool available: adapter !== null && adapter !== undefined
  readonly property bool powered: available && Boolean(adapter.enabled)
  readonly property bool actionsEnabled: Boolean(transport && transport.allowMutations)
  readonly property int connectedCount: connectedDeviceValues().length
  readonly property string connectedName: firstConnectedName()
  readonly property bool discovering: available && Boolean(adapter.discovering)

  // Plain device snapshots exist only while Bluetooth owns the control popout.
  property bool detailOpen: false
  property var devices: []
  readonly property var connectedDevices: rowsForSection("connected")
  readonly property var knownDevices: rowsForSection("known")
  readonly property var availableDevices: rowsForSection("available")

  // Discovery is bounded and ownership-scoped. Starting discovery is gated;
  // stopping discovery owned by this service is unconditional cleanup.
  property var discoveryAdapter: null
  property bool discoveryOwned: false
  property int discoveryTimeoutMs: 15000

  // One native action may be pending at a time. Device identity is always its
  // stable BlueZ address; every stage is confirmed from observed native state.
  property string pendingKey: ""
  property string pendingKind: ""
  property string pendingStage: ""
  property string pendingAddress: ""
  property var pendingDeviceObject: null
  property var pendingExpected: null
  property double pendingDeadline: 0
  property int mutationTimeoutMs: 20000
  readonly property bool pending: pendingKey !== ""

  property string error: ""
  property string errorDeviceId: ""
  property int errorTimeoutMs: 15000

  visible: false

  function deviceValues() {
    if (!backend || !backend.devices) return []
    if (Array.isArray(backend.devices)) return backend.devices.slice()
    return backend.devices.values ? [...backend.devices.values] : []
  }

  function normalizedAddress(value) {
    return String(value || "").trim().toUpperCase()
  }

  function isAddressLike(value) {
    return /^([0-9A-F]{2}:){5}[0-9A-F]{2}$/i.test(String(value || "").trim())
  }

  function isUuidLike(value) {
    var text = String(value || "").trim()
    return /^[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}$/i.test(text)
      || /^[0-9A-F]{32}$/i.test(text)
      || /^0x[0-9A-F]{4,32}$/i.test(text)
  }

  function deviceLabel(device) {
    if (!device) return ""
    var primary = String(device.deviceName || "").trim()
    var fallback = String(device.name || "").trim()
    var label = primary || fallback
    return label && !isAddressLike(label) && !isUuidLike(label) ? label : ""
  }

  function findDevice(identity) {
    var requested = normalizedAddress(identity)
    for (var i = 0; i < nativeDevices.length; i++) {
      var candidate = nativeDevices[i]
      if (candidate && normalizedAddress(candidate.address) === requested) return candidate
    }
    return null
  }

  function connectedDeviceValues() {
    var result = []
    for (var i = 0; i < nativeDevices.length; i++) {
      var candidate = nativeDevices[i]
      if (candidate && candidate.connected && deviceLabel(candidate)) result.push(candidate)
    }
    result.sort(function(a, b) { return deviceLabel(a).localeCompare(deviceLabel(b)) })
    return result
  }

  function firstConnectedName() {
    var connected = connectedDeviceValues()
    return connected.length > 0 ? deviceLabel(connected[0]) : ""
  }

  function deviceSection(device) {
    if (device && device.connected) return "connected"
    if (device && (device.paired || device.bonded || device.trusted)) return "known"
    return "available"
  }

  function snapshotFor(device) {
    if (!device) return null
    var address = normalizedAddress(device.address)
    var label = deviceLabel(device)
    if (!address || !label) return null
    var batteryAvailable = Boolean(device.batteryAvailable)
    var battery = batteryAvailable
      ? Math.round(Math.max(0, Math.min(1, Number(device.battery))) * 100)
      : -1
    return {
      id: address,
      address: address,
      name: label,
      icon: String(device.icon || ""),
      section: deviceSection(device),
      connected: Boolean(device.connected),
      paired: Boolean(device.paired),
      bonded: Boolean(device.bonded),
      trusted: Boolean(device.trusted),
      pairing: Boolean(device.pairing),
      batteryAvailable: batteryAvailable,
      battery: battery
    }
  }

  function sectionOrder(section) {
    if (section === "connected") return 0
    if (section === "known") return 1
    return 2
  }

  function refreshDetailSnapshots() {
    if (!detailOpen) return
    var next = []
    for (var i = 0; i < nativeDevices.length; i++) {
      var row = snapshotFor(nativeDevices[i])
      if (row) next.push(row)
    }
    next.sort(function(a, b) {
      var sectionDelta = sectionOrder(a.section) - sectionOrder(b.section)
      return sectionDelta !== 0 ? sectionDelta : a.name.localeCompare(b.name)
    })
    devices = next
  }

  function rowsForSection(section) {
    var result = []
    for (var i = 0; i < devices.length; i++)
      if (devices[i].section === section) result.push(devices[i])
    return result
  }

  function scheduleDetailRefresh() {
    if (detailOpen) detailRefreshDelay.restart()
  }

  function clearDetailSnapshots() {
    detailRefreshDelay.stop()
    devices = []
  }

  function setDetailOpen(value) {
    var requested = Boolean(value)
    if (detailOpen === requested) {
      if (requested) {
        scheduleDetailRefresh()
        maybeStartDiscovery()
      }
      return
    }
    detailOpen = requested
  }

  function refresh() {
    scheduleDetailRefresh()
    checkPending()
  }

  function setError(message, deviceId) {
    error = String(message || "")
    errorDeviceId = normalizedAddress(deviceId)
    if (error) errorClearTimer.restart()
    else errorClearTimer.stop()
  }

  function clearError() {
    error = ""
    errorDeviceId = ""
    errorClearTimer.stop()
  }

  function clearPending() {
    pendingKey = ""
    pendingKind = ""
    pendingStage = ""
    pendingAddress = ""
    pendingDeviceObject = null
    pendingExpected = null
    pendingDeadline = 0
  }

  function finishPending() {
    var completedKind = pendingKind
    clearPending()
    clearError()
    scheduleDetailRefresh()
    if (completedKind === "discovery") discoveryStopTimer.restart()
    if (completedKind === "power" && powered && detailOpen) Qt.callLater(maybeStartDiscovery)
  }

  function failPending(message, deviceId) {
    var failedKind = pendingKind
    clearPending()
    if (failedKind === "discovery") stopOwnedDiscovery(false)
    setError(message, deviceId)
    scheduleDetailRefresh()
  }

  function requireStageWrite(deviceId) {
    if (actionsEnabled) return true
    failPending("Bluetooth controls were locked before the action completed", deviceId)
    return false
  }

  function invokePendingStage() {
    if (!pending || !requireStageWrite(pendingAddress)) return false
    var target = pendingAddress ? findDevice(pendingAddress) : null
    if (!target && pendingAddress) target = pendingDeviceObject

    try {
      if (pendingStage === "power") {
        adapter.enabled = Boolean(pendingExpected)
      } else if (pendingStage === "discovery") {
        discoveryAdapter = adapter
        discoveryOwned = true
        adapter.discovering = true
      } else if (!target) {
        failPending("Bluetooth device is no longer available", pendingAddress)
        return false
      } else if (pendingStage === "pair") {
        target.pair()
      } else if (pendingStage === "trust") {
        target.trusted = true
      } else if (pendingStage === "connect") {
        target.connect()
      } else if (pendingStage === "disconnect" || pendingStage === "forget-disconnect") {
        target.disconnect()
      } else if (pendingStage === "forget") {
        target.forget()
      }
    } catch (e) {
      failPending("Bluetooth action failed: " + String(e), pendingAddress)
      return false
    }

    Qt.callLater(checkPending)
    return true
  }

  function beginMutation(key, kind, stage, device, expected) {
    var deviceId = device ? normalizedAddress(device.address) : ""
    if (!actionsEnabled) {
      setError("Bluetooth controls are locked in read-only mode", deviceId)
      return false
    }
    if (!backendReady) {
      setError("BlueZ backend is unavailable", deviceId)
      return false
    }
    if (!available) {
      setError("No Bluetooth adapter is available", deviceId)
      return false
    }
    if (pending) {
      setError("Bluetooth action already pending: " + pendingKey, deviceId)
      return false
    }

    clearError()
    pendingKey = String(key)
    pendingKind = String(kind)
    pendingStage = String(stage)
    pendingAddress = deviceId
    pendingDeviceObject = device
    pendingExpected = expected
    pendingDeadline = Date.now() + mutationTimeoutMs
    return invokePendingStage()
  }

  function advanceDeviceActivation(target) {
    if (pendingStage === "pair") {
      if (!target.paired && !target.bonded) return
      pendingStage = "trust"
      invokePendingStage()
      return
    }
    if (pendingStage === "trust") {
      if (!target.trusted) return
      pendingStage = "connect"
      invokePendingStage()
      return
    }
    if (pendingStage === "connect" && target.connected) finishPending()
  }

  function checkPending() {
    if (!pending) return
    if (Date.now() >= pendingDeadline) {
      var timedOutKey = pendingKey
      var timedOutId = pendingAddress
      if (pendingStage === "pair")
        failPending("Pairing needs a system Bluetooth agent for PIN/passkey confirmation", timedOutId)
      else
        failPending("Bluetooth action timed out: " + timedOutKey, timedOutId)
      return
    }

    if (pendingStage === "power") {
      if (powered === Boolean(pendingExpected)) finishPending()
      return
    }
    if (pendingStage === "discovery") {
      if (discovering) finishPending()
      return
    }

    var liveTarget = findDevice(pendingAddress)
    if (pendingStage === "forget" && !liveTarget) {
      finishPending()
      return
    }
    var target = liveTarget || pendingDeviceObject
    if (!target) {
      failPending("Bluetooth device is no longer available", pendingAddress)
      return
    }

    if (pendingKind === "activate") {
      advanceDeviceActivation(target)
    } else if (pendingKind === "disconnect") {
      if (!target.connected) finishPending()
    } else if (pendingKind === "forget") {
      if (pendingStage === "forget-disconnect") {
        if (!target.connected) {
          pendingStage = "forget"
          invokePendingStage()
        }
      } else if (!target.connected && !target.paired && !target.bonded && !target.trusted) {
        finishPending()
      }
    }
  }

  function setPowered(value) {
    var expected = Boolean(value)
    if (!expected) stopOwnedDiscovery(false)
    return beginMutation("bluetooth:power:" + (expected ? "on" : "off"),
      "power", "power", null, expected)
  }

  function togglePower() {
    return setPowered(!powered)
  }

  function startDiscovery() {
    if (!detailOpen) {
      setError("Open Bluetooth controls before scanning", "")
      return false
    }
    if (!actionsEnabled) {
      setError("Bluetooth controls are locked in read-only mode", "")
      return false
    }
    if (!powered) {
      setError("Turn Bluetooth on before scanning", "")
      return false
    }
    if (discovering) return true
    if (!adapter) {
      setError("No Bluetooth adapter is available", "")
      return false
    }
    try {
      discoveryAdapter = adapter
      discoveryOwned = true
      adapter.discovering = true
      discoveryStopTimer.restart()
      return true
    } catch (e) {
      discoveryOwned = false
      discoveryAdapter = null
      setError("Failed to start Bluetooth discovery: " + String(e), "")
      return false
    }
  }

  function maybeStartDiscovery() {
    if (detailOpen && powered && actionsEnabled && !discovering && !pending)
      startDiscovery()
  }

  function stopOwnedDiscovery(reportFailure) {
    discoveryStopTimer.stop()
    if (pendingKind === "discovery") clearPending()
    var ownedAdapter = discoveryAdapter
    var wasOwned = discoveryOwned
    discoveryAdapter = null
    discoveryOwned = false
    if (!wasOwned || !ownedAdapter || !ownedAdapter.discovering) return true
    try {
      ownedAdapter.discovering = false
      return true
    } catch (e) {
      if (reportFailure) setError("Failed to stop Bluetooth discovery: " + String(e), "")
      return false
    }
  }

  function activateDevice(identity) {
    var target = findDevice(identity)
    if (!target) {
      setError("Bluetooth device is no longer available", identity)
      return false
    }
    if (!powered) {
      setError("Turn Bluetooth on before connecting devices", identity)
      return false
    }
    if (target.connected) return disconnectDevice(identity)
    var known = Boolean(target.paired || target.bonded || target.trusted)
    var stage = known ? (target.trusted ? "connect" : "trust") : "pair"
    return beginMutation("bluetooth:" + normalizedAddress(identity) + ":activate",
      "activate", stage, target, true)
  }

  function disconnectDevice(identity) {
    var target = findDevice(identity)
    if (!target || !target.connected) {
      setError("Connected Bluetooth device is no longer available", identity)
      return false
    }
    return beginMutation("bluetooth:" + normalizedAddress(identity) + ":disconnect",
      "disconnect", "disconnect", target, false)
  }

  function forgetDevice(identity) {
    var target = findDevice(identity)
    if (!target || (!target.connected && !target.paired && !target.bonded && !target.trusted)) {
      setError("Paired Bluetooth device is no longer available", identity)
      return false
    }
    var stage = target.connected ? "forget-disconnect" : "forget"
    return beginMutation("bluetooth:" + normalizedAddress(identity) + ":forget",
      "forget", stage, target, false)
  }

  function rowStatus(identity) {
    var requested = normalizedAddress(identity)
    if (pending && pendingAddress === requested) {
      if (pendingStage === "pair") return "Pairing…"
      if (pendingStage === "trust") return "Trusting…"
      if (pendingStage === "connect") return "Connecting…"
      if (pendingStage === "disconnect" || pendingStage === "forget-disconnect") return "Disconnecting…"
      if (pendingStage === "forget") return "Forgetting…"
    }
    if (error && errorDeviceId === requested) return error
    var target = findDevice(requested)
    if (target && target.connected) return "Connected"
    if (target && (target.paired || target.bonded || target.trusted)) return "Paired"
    return ""
  }

  onDetailOpenChanged: {
    if (detailOpen) {
      scheduleDetailRefresh()
      maybeStartDiscovery()
    } else {
      stopOwnedDiscovery(true)
      clearDetailSnapshots()
      if (!pending) clearError()
    }
  }
  onAdapterChanged: {
    stopOwnedDiscovery(false)
    scheduleDetailRefresh()
    checkPending()
  }
  onPoweredChanged: {
    if (!powered) stopOwnedDiscovery(false)
    scheduleDetailRefresh()
    checkPending()
    if (powered && detailOpen) Qt.callLater(maybeStartDiscovery)
  }
  onDiscoveringChanged: {
    if (!discovering && discoveryOwned) {
      discoveryAdapter = null
      discoveryOwned = false
      discoveryStopTimer.stop()
    }
    scheduleDetailRefresh()
    checkPending()
  }

  Timer {
    id: detailRefreshDelay
    interval: 75
    repeat: false
    onTriggered: root.refreshDetailSnapshots()
  }

  Timer {
    interval: 500
    running: root.detailOpen
    repeat: true
    onTriggered: root.refreshDetailSnapshots()
  }

  Timer {
    interval: 100
    running: root.pending
    repeat: true
    onTriggered: {
      root.refreshDetailSnapshots()
      root.checkPending()
    }
  }

  Timer {
    id: discoveryStopTimer
    interval: root.discoveryTimeoutMs
    repeat: false
    onTriggered: root.stopOwnedDiscovery(true)
  }

  Timer {
    id: errorClearTimer
    interval: root.errorTimeoutMs
    repeat: false
    onTriggered: root.clearError()
  }

  Connections {
    target: root.backend && root.backend.devices && !Array.isArray(root.backend.devices)
      ? root.backend.devices
      : null
    ignoreUnknownSignals: true
    function onValuesChanged() {
      root.scheduleDetailRefresh()
      root.checkPending()
    }
  }

  Connections {
    target: root.pendingDeviceObject
    ignoreUnknownSignals: true
    function onConnectedChanged() { root.checkPending() }
    function onPairedChanged() { root.checkPending() }
    function onBondedChanged() { root.checkPending() }
    function onTrustedChanged() { root.checkPending() }
    function onPairingChanged() { root.checkPending() }
  }

  Connections {
    target: root.transport
    ignoreUnknownSignals: true
    function onAllowMutationsChanged() {
      if (!root.actionsEnabled) root.stopOwnedDiscovery(true)
      else root.maybeStartDiscovery()
    }
  }

  Component.onCompleted: scheduleDetailRefresh()
  Component.onDestruction: {
    stopOwnedDiscovery(false)
    devices = []
  }
}
