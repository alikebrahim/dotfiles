import QtQuick
import "TailscaleLogic.js" as Logic

Item {
  id: root

  required property QtObject transport
  property bool refreshOnStart: true
  property int refreshInterval: 60000
  property int actionTimeoutMs: 15000
  property int maxPeers: 100
  property bool panelOpen: false

  property bool installed: false
  property bool hasSnapshot: false
  property bool refreshing: false
  property bool stale: false
  property string backendState: "Checking"
  property string tailnetName: ""
  property string selfName: ""
  property string selfDnsName: ""
  property string selfIpv4: ""
  property bool selfOnline: false
  property var peers: []
  property int onlinePeerCount: 0
  property var exitNodes: []
  property string currentExitNodeKey: ""
  property string currentExitNodeName: ""
  property int healthCount: 0
  property double lastUpdatedMs: 0
  property string error: ""

  property string pendingAction: ""
  property string pendingTarget: ""
  property bool awaitingConvergence: false
  property string actionMessage: ""

  readonly property string binaryPath: "/usr/sbin/tailscale"
  readonly property bool connected: backendState === "Running"
  readonly property bool needsLogin: backendState === "NeedsLogin"
  readonly property bool actionsEnabled: transport !== null && transport.allowMutations
  readonly property bool busy: refreshing || pendingAction !== ""
  readonly property int peerCount: peers.length

  visible: false

  signal actionFinished(string action, bool ok, string message)

  function peerForKey(key) {
    var requested = String(key || "")
    for (var i = 0; i < peers.length; i++)
      if (peers[i].key === requested) return peers[i]
    return null
  }

  function exitNodeForKey(key) {
    var requested = String(key || "")
    for (var i = 0; i < exitNodes.length; i++)
      if (exitNodes[i].key === requested) return exitNodes[i]
    return null
  }

  function refresh() {
    if (!transport) return false
    refreshing = true
    transport.request(
      "tailscale.status",
      [binaryPath, "status", "--json"],
      false,
      false
    )
    return true
  }

  function setPanelOpen(open) {
    panelOpen = open === true
    if (panelOpen) refresh()
  }

  function applyStatus(raw) {
    var parsed = Logic.parseStatus(raw, maxPeers)
    refreshing = false
    if (!parsed.ok) {
      stale = hasSnapshot
      error = parsed.error
      if (!hasSnapshot) {
        installed = true
        backendState = "Unavailable"
      }
      return false
    }

    installed = true
    hasSnapshot = true
    stale = false
    backendState = parsed.backendState
    tailnetName = parsed.tailnetName
    selfName = parsed.selfName
    selfDnsName = parsed.selfDnsName
    selfIpv4 = parsed.selfIpv4
    selfOnline = parsed.selfOnline
    peers = parsed.peers
    onlinePeerCount = parsed.onlineCount
    exitNodes = parsed.exitNodes
    currentExitNodeKey = parsed.currentExitNodeKey
    currentExitNodeName = parsed.currentExitNodeName
    healthCount = parsed.healthCount
    lastUpdatedMs = Date.now()
    error = ""
    checkConvergence()
    return true
  }

  function applyReadFailure(message) {
    refreshing = false
    var detail = String(message || "Tailscale status unavailable").trim()
    var missing = /not found|no such file|failed to start/i.test(detail)
    if (!hasSnapshot) {
      installed = !missing
      backendState = missing ? "Not installed" : "Unavailable"
    }
    stale = hasSnapshot
    error = detail || "Tailscale status unavailable"
  }

  function beginAction(action, target, command) {
    if (!actionsEnabled) {
      error = "Tailscale changes are disabled"
      return false
    }
    if (pendingAction !== "" || !Array.isArray(command) || command.length === 0) return false
    pendingAction = String(action || "")
    pendingTarget = String(target || "")
    awaitingConvergence = false
    actionMessage = "Applying " + pendingAction + "…"
    error = ""
    transport.request("tailscale.action." + pendingAction, command, true, false)
    return true
  }

  function toggleConnection() {
    if (connected) return beginAction("down", "", [binaryPath, "down"])
    if (needsLogin) {
      error = "Login is intentionally delegated to the Tailscale CLI"
      return false
    }
    return beginAction("up", "", [binaryPath, "up"])
  }

  function setExitNode(peerKey) {
    if (!connected) return false
    var requested = String(peerKey || "")
    if (requested === currentExitNodeKey && requested !== "")
      return beginAction("exit-clear", "", [binaryPath, "set", "--exit-node="])
    var peer = exitNodeForKey(requested)
    if (!peer || !peer.target) return false
    return beginAction(
      "exit-set",
      peer.key,
      [binaryPath, "set", "--exit-node=" + peer.target]
    )
  }

  function convergenceReached() {
    if (pendingAction === "up") return connected
    if (pendingAction === "down") return !connected && backendState !== "Checking"
    if (pendingAction === "exit-set") return currentExitNodeKey === pendingTarget
    if (pendingAction === "exit-clear") return currentExitNodeKey === ""
    return false
  }

  function checkConvergence() {
    if (!awaitingConvergence || !convergenceReached()) return false
    var action = pendingAction
    awaitingConvergence = false
    pendingAction = ""
    pendingTarget = ""
    actionMessage = ""
    convergenceTimeout.stop()
    convergenceRefresh.stop()
    actionFinished(action, true, "")
    return true
  }

  function failPending(message) {
    var action = pendingAction
    var detail = String(message || "Tailscale action failed").trim()
    awaitingConvergence = false
    pendingAction = ""
    pendingTarget = ""
    actionMessage = ""
    convergenceTimeout.stop()
    convergenceRefresh.stop()
    error = detail
    actionFinished(action, false, detail)
  }

  Connections {
    target: root.transport

    function onFinished(requestId, key, ok, output, message) {
      if (key === "tailscale.status") {
        if (ok) root.applyStatus(output)
        else root.applyReadFailure(message || output)
        return
      }
      if (key.indexOf("tailscale.action.") !== 0) return
      var action = key.substring("tailscale.action.".length)
      if (action !== root.pendingAction) return
      if (!ok) {
        root.failPending(message || output)
        return
      }
      root.awaitingConvergence = true
      root.actionMessage = "Waiting for Tailscale state…"
      convergenceTimeout.restart()
      convergenceRefresh.restart()
      root.refresh()
    }
  }

  Timer {
    interval: root.refreshInterval
    running: root.refreshOnStart && root.refreshInterval > 0
    repeat: true
    onTriggered: root.refresh()
  }

  Timer {
    id: convergenceRefresh
    interval: 750
    repeat: true
    running: false
    onTriggered: root.refresh()
  }

  Timer {
    id: convergenceTimeout
    interval: root.actionTimeoutMs
    repeat: false
    onTriggered: root.failPending("Tailscale state did not converge")
  }

  Component.onCompleted: if (refreshOnStart) refresh()
}
