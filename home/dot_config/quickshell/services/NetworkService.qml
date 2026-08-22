import QtQuick
import Quickshell.Networking

// NetworkManager is the only network-state authority. The command transport
// contributes the existing per-login mutation gate and the explicit external
// editor fallback; it never polls or mirrors NetworkManager state.
Item {
  id: root

  required property QtObject transport
  property var backend: Networking

  readonly property var nativeDevices: deviceValues()
  readonly property var wifiDevice: findDevice(DeviceType.Wifi)
  readonly property var wiredDevice: findDevice(DeviceType.Wired)
  readonly property var connectedWifi: connectedWifiNetwork()
  readonly property var activeConnection: activeNetwork()
  readonly property bool backendReady: backend !== null && backend !== undefined
    && (backend.ready !== undefined
      ? Boolean(backend.ready)
      : backend.backend === NetworkBackendType.NetworkManager)
  readonly property bool available: backendReady && nativeDevices.length > 0
  readonly property bool actionsEnabled: Boolean(transport && transport.allowMutations)
  readonly property bool wifiEnabled: backendReady && Boolean(backend.wifiEnabled)
  readonly property bool wifiHardwareEnabled: backendReady
    && (backend.wifiHardwareEnabled === undefined || Boolean(backend.wifiHardwareEnabled))
  readonly property string state: activeConnection
    ? stateName(activeConnection.state)
    : (backendReady ? "disconnected" : "unknown")
  readonly property string connectivity: backendReady
    ? enumName(NetworkConnectivity, backend.connectivity, "unknown")
    : "unknown"
  readonly property string connectionName: activeConnection ? String(activeConnection.name || "") : ""
  readonly property string connectionType: wiredDevice && wiredDevice.connected
    ? "ethernet"
    : (connectedWifi ? "wifi" : "")
  readonly property string device: wiredDevice && wiredDevice.connected
    ? String(wiredDevice.name || "")
    : (wifiDevice ? String(wifiDevice.name || "") : "")
  readonly property int signalStrength: connectedWifi
    ? Math.round(clamp(Number(connectedWifi.signalStrength), 0, 1) * 100)
    : -1

  // Plain snapshots exist only while Network owns the control popout.
  property bool detailOpen: false
  property var networks: []
  property var scanningDevice: null

  // Credentials never cross argv, IPC, logs, or result payloads. The PSK is
  // held only while the inline editor is open and is wiped before native
  // action convergence begins.
  property string credentialNetworkId: ""
  property string credentialText: ""
  readonly property bool credentialOpen: credentialNetworkId !== ""
  signal panelFocusRequested()

  property string error: ""
  property string errorNetworkId: ""
  property string pendingKey: ""
  property string pendingKind: ""
  property string pendingNetworkId: ""
  property var pendingNetworkObject: null
  property var pendingExpected: null
  property double pendingDeadline: 0
  property int mutationTimeoutMs: 15000
  readonly property bool pending: pendingKey !== ""

  visible: false

  function clamp(value, minimum, maximum) {
    if (!isFinite(value)) return minimum
    return Math.max(minimum, Math.min(maximum, value))
  }

  function enumName(type, value, fallback) {
    try {
      var text = String(type.toString(value) || "")
      return text ? text.toLowerCase() : fallback
    } catch (e) {
      return fallback
    }
  }

  function stateName(value) {
    return enumName(ConnectionState, value, "unknown")
  }

  function deviceValues() {
    if (!backend || !backend.devices) return []
    if (Array.isArray(backend.devices)) return backend.devices.slice()
    return backend.devices.values ? [...backend.devices.values] : []
  }

  function findDevice(type) {
    for (var i = 0; i < nativeDevices.length; i++) {
      var candidate = nativeDevices[i]
      if (candidate && candidate.type === type) return candidate
    }
    return null
  }

  function wifiNetworkValues() {
    if (!wifiDevice || !wifiDevice.networks) return []
    if (Array.isArray(wifiDevice.networks)) return wifiDevice.networks.slice()
    return wifiDevice.networks.values ? [...wifiDevice.networks.values] : []
  }

  function connectedWifiNetwork() {
    var values = wifiNetworkValues()
    for (var i = 0; i < values.length; i++)
      if (values[i] && values[i].connected) return values[i]
    return null
  }

  function activeNetwork() {
    if (wiredDevice && wiredDevice.connected && wiredDevice.network) return wiredDevice.network
    return connectedWifi
  }

  function networkId(network) {
    if (!network) return ""
    return String(wifiDevice ? wifiDevice.name || "wifi" : "wifi")
      + "\u001f" + String(network.name || "")
      + "\u001f" + String(network.security)
  }

  function findNetwork(identity) {
    var requested = String(identity || "")
    var values = wifiNetworkValues()
    for (var i = 0; i < values.length; i++)
      if (networkId(values[i]) === requested) return values[i]
    return null
  }

  function isOpenSecurity(security) {
    return security === WifiSecurityType.Open || security === WifiSecurityType.Owe
  }

  function isEnterpriseSecurity(security) {
    return security === WifiSecurityType.WpaEap
      || security === WifiSecurityType.Wpa2Eap
      || security === WifiSecurityType.Wpa3SuiteB192
      || security === WifiSecurityType.DynamicWep
      || security === WifiSecurityType.Leap
  }

  function supportsPsk(security) {
    return security === WifiSecurityType.WpaPsk
      || security === WifiSecurityType.Wpa2Psk
      || security === WifiSecurityType.Sae
      || security === WifiSecurityType.StaticWep
  }

  function securityName(security) {
    if (security === WifiSecurityType.Open) return "Open"
    if (security === WifiSecurityType.Owe) return "Enhanced open"
    if (security === WifiSecurityType.Sae) return "WPA3"
    if (security === WifiSecurityType.Wpa2Psk) return "WPA2"
    if (security === WifiSecurityType.WpaPsk) return "WPA"
    if (security === WifiSecurityType.StaticWep) return "WEP"
    if (isEnterpriseSecurity(security)) return "Enterprise"
    return "Unknown security"
  }

  function nativeConnectionSupported(network) {
    return Boolean(network && (network.known || isOpenSecurity(network.security) || supportsPsk(network.security)))
  }

  function snapshotFor(network) {
    if (!network || !String(network.name || "")) return null
    return {
      id: networkId(network),
      ssid: String(network.name || ""),
      signal: Math.round(clamp(Number(network.signalStrength), 0, 1) * 100),
      security: securityName(network.security),
      protected: !isOpenSecurity(network.security),
      enterprise: isEnterpriseSecurity(network.security),
      supported: nativeConnectionSupported(network),
      connected: Boolean(network.connected),
      known: Boolean(network.known),
      stateChanging: Boolean(network.stateChanging)
    }
  }

  function refreshDetailSnapshots() {
    if (!detailOpen) return
    var next = []
    var values = wifiNetworkValues()
    for (var i = 0; i < values.length; i++) {
      var row = snapshotFor(values[i])
      if (row) next.push(row)
    }
    next.sort(function(a, b) {
      if (a.connected !== b.connected) return a.connected ? -1 : 1
      if (a.known !== b.known) return a.known ? -1 : 1
      if (a.signal !== b.signal) return b.signal - a.signal
      return a.ssid.localeCompare(b.ssid)
    })
    networks = next
    if (credentialOpen && !findNetwork(credentialNetworkId)) clearCredentials(false)
  }

  function scheduleDetailRefresh() {
    if (detailOpen) detailRefreshDelay.restart()
  }

  function clearDetailSnapshots() {
    detailRefreshDelay.stop()
    networks = []
  }

  function updateScanner() {
    if (scanningDevice && scanningDevice !== wifiDevice) {
      try { scanningDevice.scannerEnabled = false } catch (e) { }
    }
    scanningDevice = wifiDevice
    if (!scanningDevice || scanningDevice.scannerEnabled === undefined) return
    var requested = detailOpen && wifiEnabled && wifiHardwareEnabled
    try {
      if (Boolean(scanningDevice.scannerEnabled) !== requested)
        scanningDevice.scannerEnabled = requested
    } catch (e) {
      errorNetworkId = ""
      error = "Wi-Fi scan failed: " + String(e)
    }
  }

  function setDetailOpen(value) {
    var requested = Boolean(value)
    if (detailOpen === requested) {
      if (requested) scheduleDetailRefresh()
      return
    }
    detailOpen = requested
  }

  function refresh() {
    scheduleDetailRefresh()
    checkPending()
  }

  function clearCredentials(restoreFocus) {
    var wasOpen = credentialOpen
    credentialText = ""
    credentialNetworkId = ""
    if (wasOpen && restoreFocus) panelFocusRequested()
  }

  function requestCredentials(identity) {
    if (!actionsEnabled) {
      errorNetworkId = String(identity || "")
      error = "Network controls are locked in read-only mode"
      return false
    }
    if (pending) {
      errorNetworkId = String(identity || "")
      error = "Network action already pending: " + pendingKey
      return false
    }
    var network = findNetwork(identity)
    if (!network || network.known || !supportsPsk(network.security)) {
      errorNetworkId = String(identity || "")
      error = network && isEnterpriseSecurity(network.security)
        ? "Enterprise Wi-Fi requires the connection manager"
        : "This Wi-Fi security type requires the connection manager"
      return false
    }
    credentialText = ""
    credentialNetworkId = networkId(network)
    errorNetworkId = ""
    error = ""
    return true
  }

  function cancelCredentials() {
    errorNetworkId = ""
    error = ""
    clearCredentials(true)
  }

  function clearPending() {
    pendingKey = ""
    pendingKind = ""
    pendingNetworkId = ""
    pendingNetworkObject = null
    pendingExpected = null
    pendingDeadline = 0
  }

  function pendingSatisfied() {
    if (!pending) return true
    if (pendingKind === "wifi-toggle") return wifiEnabled === Boolean(pendingExpected)
    var network = findNetwork(pendingNetworkId)
    if (pendingKind === "connect") return Boolean(network && network.connected)
    if (pendingKind === "disconnect") return !network || (!network.connected && !network.stateChanging)
    if (pendingKind === "forget") return !network || (!network.known && !network.stateChanging)
    return false
  }

  function checkPending() {
    if (!pending) return
    if (pendingSatisfied()) {
      clearPending()
      errorNetworkId = ""
      error = ""
      scheduleDetailRefresh()
      return
    }
    if (Date.now() >= pendingDeadline) {
      var timedOutId = pendingNetworkId
      var timedOutKey = pendingKey
      clearPending()
      errorNetworkId = timedOutId
      error = "Network action timed out: " + timedOutKey
      scheduleDetailRefresh()
    }
  }

  function beginMutation(key, kind, network, expected, action) {
    if (!actionsEnabled) {
      errorNetworkId = network ? networkId(network) : ""
      error = "Network controls are locked in read-only mode"
      return false
    }
    if (!backendReady) {
      errorNetworkId = ""
      error = "NetworkManager backend is unavailable"
      return false
    }
    if (pending) {
      errorNetworkId = network ? networkId(network) : ""
      error = "Network action already pending: " + pendingKey
      return false
    }

    errorNetworkId = ""
    error = ""
    pendingKey = String(key)
    pendingKind = String(kind)
    pendingNetworkId = network ? networkId(network) : ""
    pendingNetworkObject = network
    pendingExpected = expected
    pendingDeadline = Date.now() + mutationTimeoutMs

    try {
      action(network)
    } catch (e) {
      var failedId = pendingNetworkId
      clearPending()
      errorNetworkId = failedId
      error = "Network action failed: " + String(e)
      return false
    }

    Qt.callLater(checkPending)
    return true
  }

  function setWifiEnabled(value) {
    var expected = Boolean(value)
    return beginMutation("wifi:" + (expected ? "on" : "off"), "wifi-toggle", null, expected,
      function() { backend.wifiEnabled = expected })
  }

  function toggleWifi() {
    return setWifiEnabled(!wifiEnabled)
  }

  function activateNetwork(identity) {
    var network = findNetwork(identity)
    if (!network) {
      errorNetworkId = String(identity || "")
      error = "Wi-Fi network is no longer available"
      return false
    }
    if (network.connected)
      return beginMutation("wifi:" + networkId(network) + ":disconnect", "disconnect", network, false,
        function(target) { target.disconnect() })
    if (!network.known && supportsPsk(network.security)) return requestCredentials(identity)
    if (!nativeConnectionSupported(network)) {
      errorNetworkId = networkId(network)
      error = isEnterpriseSecurity(network.security)
        ? "Enterprise Wi-Fi requires the connection manager"
        : "This Wi-Fi security type requires the connection manager"
      return false
    }
    return beginMutation("wifi:" + networkId(network) + ":connect", "connect", network, true,
      function(target) { target.connect() })
  }

  function submitCredentials() {
    var network = findNetwork(credentialNetworkId)
    if (!network || !supportsPsk(network.security) || credentialText.length === 0) return false

    var secret = credentialText
    var identity = networkId(network)
    credentialText = ""
    credentialNetworkId = ""
    panelFocusRequested()
    var started = beginMutation("wifi:" + identity + ":connect", "connect", network, true,
      function(target) { target.connectWithPsk(secret) })
    secret = ""
    return started
  }

  function forgetNetwork(identity) {
    var network = findNetwork(identity)
    if (!network || !network.known) {
      errorNetworkId = String(identity || "")
      error = "Saved Wi-Fi network is no longer available"
      return false
    }
    if (network.connected) {
      errorNetworkId = networkId(network)
      error = "Disconnect before forgetting this network"
      return false
    }
    return beginMutation("wifi:" + networkId(network) + ":forget", "forget", network, false,
      function(target) { target.forget() })
  }

  function failureReason(reason) {
    if (reason === ConnectionFailReason.NoSecrets) return "Passphrase required"
    if (reason === ConnectionFailReason.WifiAuthTimeout) return "Wrong passphrase"
    if (reason === ConnectionFailReason.WifiNetworkLost) return "Wi-Fi network lost"
    if (reason === ConnectionFailReason.WifiClientDisconnected) return "Disconnected"
    if (reason === ConnectionFailReason.WifiClientFailed) return "Connection failed"
    return "Failed to connect"
  }

  function handleConnectionFailure(reason) {
    if (!pending || pendingKind !== "connect") return
    var identity = pendingNetworkId
    var network = pendingNetworkObject
    clearPending()
    errorNetworkId = identity
    error = failureReason(reason)
    scheduleDetailRefresh()
    if (network && supportsPsk(network.security)
        && (reason === ConnectionFailReason.NoSecrets || reason === ConnectionFailReason.WifiAuthTimeout)) {
      credentialText = ""
      credentialNetworkId = identity
    }
  }

  function rowStatus(identity) {
    var requested = String(identity || "")
    if (pending && pendingNetworkId === requested) {
      if (pendingKind === "connect") return "Connecting…"
      if (pendingKind === "disconnect") return "Disconnecting…"
      if (pendingKind === "forget") return "Forgetting…"
    }
    if (error && errorNetworkId === requested) return error
    var network = findNetwork(requested)
    return network && network.connected ? "Connected" : ""
  }

  function openManager() {
    if (!actionsEnabled) {
      errorNetworkId = ""
      error = "Network controls are locked in read-only mode"
      return false
    }
    return transport.request("network.manage", ["nm-connection-editor"], true, true)
  }

  onDetailOpenChanged: {
    updateScanner()
    if (detailOpen) scheduleDetailRefresh()
    else {
      clearCredentials(false)
      clearDetailSnapshots()
      if (!pending) {
        errorNetworkId = ""
        error = ""
      }
    }
  }
  onWifiDeviceChanged: {
    updateScanner()
    scheduleDetailRefresh()
  }
  onWifiEnabledChanged: {
    updateScanner()
    scheduleDetailRefresh()
    checkPending()
  }
  onWifiHardwareEnabledChanged: updateScanner()

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

  Connections {
    target: root.backend && root.backend.devices && !Array.isArray(root.backend.devices)
      ? root.backend.devices
      : null
    function onValuesChanged() {
      root.updateScanner()
      root.scheduleDetailRefresh()
      root.checkPending()
    }
  }

  Connections {
    target: root.wifiDevice && root.wifiDevice.networks && !Array.isArray(root.wifiDevice.networks)
      ? root.wifiDevice.networks
      : null
    function onValuesChanged() {
      root.scheduleDetailRefresh()
      root.checkPending()
    }
  }

  Connections {
    target: root.pendingNetworkObject
    function onConnectionFailed(reason) { root.handleConnectionFailure(reason) }
    function onConnectedChanged() { root.checkPending() }
    function onKnownChanged() { root.checkPending() }
    function onStateChangingChanged() { root.checkPending() }
  }

  Connections {
    target: root.transport
    function onFinished(requestId, key, ok, output, message) {
      if (key !== "network.manage") return
      root.errorNetworkId = ""
      root.error = ok ? "" : String(message || "Failed to open connection manager")
    }
  }

  Component.onDestruction: {
    if (scanningDevice && scanningDevice.scannerEnabled !== undefined) {
      try { scanningDevice.scannerEnabled = false } catch (e) { }
    }
    credentialText = ""
  }
}
