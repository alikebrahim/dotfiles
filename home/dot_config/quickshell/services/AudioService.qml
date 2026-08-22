import QtQuick
import Quickshell.Services.Pipewire

// PipeWire is the only audio state authority. The command transport contributes
// the existing per-login mutation gate, but never polls or mirrors audio state.
Item {
  id: root

  required property QtObject transport
  property var backend: Pipewire
  // Isolated fixtures inject plain QObject nodes and disable native trackers.
  property bool useNativeBackend: true

  readonly property var defaultOutputNode: backend ? backend.defaultAudioSink : null
  readonly property var defaultInputNode: backend ? backend.defaultAudioSource : null
  readonly property var nativeNodes: nodeValues()
  readonly property bool available: defaultOutputNode !== null && defaultOutputNode.audio !== null
  readonly property bool inputAvailable: defaultInputNode !== null && defaultInputNode.audio !== null
  readonly property bool backendReady: backend && backend.ready !== undefined ? Boolean(backend.ready) : backend !== null
  readonly property bool actionsEnabled: Boolean(transport && transport.allowMutations)

  readonly property int volume: available ? Math.round(clamp(defaultOutputNode.audio.volume, 0, 1) * 100) : 0
  readonly property bool muted: available ? Boolean(defaultOutputNode.audio.muted) : true
  readonly property string currentOutput: nodeName(defaultOutputNode)
  readonly property string currentOutputLabel: nodeLabel(defaultOutputNode)
  readonly property int inputVolume: inputAvailable ? Math.round(clamp(defaultInputNode.audio.volume, 0, 1) * 100) : 0
  readonly property bool inputMuted: inputAvailable ? Boolean(defaultInputNode.audio.muted) : true
  readonly property string currentInput: nodeName(defaultInputNode)
  readonly property string currentInputLabel: nodeLabel(defaultInputNode)
  readonly property bool microphoneInUse: microphoneIsActive()
  readonly property int captureStreamCount: activeCaptureStreamCount()
  readonly property real inputPeak: detailOpen && inputPeakMonitor.enabled
    ? clamp(inputPeakMonitor.peak, 0, 1)
    : 0

  // Plain row snapshots are populated only while Audio owns the popout.
  property bool detailOpen: false
  property var outputs: []
  property var inputs: []
  property var streams: []

  property string error: ""
  property string pendingKey: ""
  property string pendingKind: ""
  property string pendingNodeId: ""
  property var pendingExpected: null
  property double pendingDeadline: 0
  readonly property bool pending: pendingKey !== ""
  property int mutationTimeoutMs: 1800

  visible: false

  function clamp(value, minimum, maximum) {
    var number = Number(value)
    if (!isFinite(number)) return minimum
    return Math.max(minimum, Math.min(maximum, number))
  }

  function nodeValues() {
    if (!backend || !backend.nodes) return []
    if (Array.isArray(backend.nodes)) return backend.nodes.slice()
    var values = backend.nodes.values
    return values ? [...values] : []
  }

  function nodeId(node) {
    return node && node.id !== undefined ? String(node.id) : ""
  }

  function nodeName(node) {
    return node ? String(node.name || "") : ""
  }

  function nodeLabel(node) {
    if (!node) return "Unavailable"
    var label = String(node.nickname || node.description || node.name || "Unknown device").trim()
    label = label.replace(/^built-?in audio\s+/i, "")
    label = label.replace(/\s+(Output|Input)$/i, "")
    return label || "Unknown device"
  }

  function nodeProperties(node) {
    if (!node || !node.ready || !node.properties) return ({})
    return node.properties
  }

  function outputGlyph(node) {
    var properties = nodeProperties(node)
    var text = String([
      nodeName(node), node ? node.description : "", node ? node.nickname : "",
      properties["device.icon-name"] || "", properties["device.product.name"] || ""
    ].join(" ")).toLowerCase()
    if (text.indexOf("headphone") !== -1 || text.indexOf("headset") !== -1) return String.fromCodePoint(0xF02CB)
    if (text.indexOf("bluetooth") !== -1 || text.indexOf("bluez") !== -1) return String.fromCodePoint(0xF00AF)
    if (text.indexOf("hdmi") !== -1 || text.indexOf("display") !== -1) return String.fromCodePoint(0xF0379)
    return String.fromCodePoint(0xF057E)
  }

  function inputGlyph(node) {
    var text = String([nodeName(node), node ? node.description : "", node ? node.nickname : ""].join(" ")).toLowerCase()
    if (text.indexOf("headset") !== -1 || text.indexOf("headphone") !== -1) return String.fromCodePoint(0xF02CB)
    if (text.indexOf("webcam") !== -1 || text.indexOf("camera") !== -1) return String.fromCodePoint(0xF0100)
    return String.fromCodePoint(0xF036C)
  }

  function streamLabel(node) {
    var properties = nodeProperties(node)
    var label = String(properties["application.name"] || node.description || properties["media.name"] || node.name || "Application").trim()
    return label || "Application"
  }

  function isOutputDevice(node) {
    return Boolean(node && node.isSink === true && node.isStream !== true)
  }

  function isInputDevice(node) {
    if (!node || node.isSink === true || node.isStream === true) return false
    if (nodeName(node) === "quickshell") return false
    if (node.audio) return true
    try {
      var typeName = String(PwNodeType.toString(node.type))
      return typeName.indexOf("AudioSource") !== -1 || typeName.indexOf("AudioDuplex") !== -1
    } catch (e) {
      return false
    }
  }

  function isPlaybackStream(node) {
    return Boolean(node && node.isStream === true && node.isSink === true
      && nodeName(node).indexOf("omarchy_speaker_tuning") !== 0)
  }

  function isCaptureStream(node) {
    if (!node || node.isStream !== true || node.isSink === true) return false
    var name = nodeName(node).toLowerCase()
    return name !== "quickshell" && name.indexOf("quickshell-") !== 0
  }

  function activeCaptureStreamCount() {
    var count = 0
    for (var i = 0; i < nativeNodes.length; i++) {
      var node = nativeNodes[i]
      if (isCaptureStream(node) && (!node.audio || !node.audio.muted)) count++
    }
    return count
  }

  function microphoneIsActive() {
    return inputAvailable && !inputMuted && activeCaptureStreamCount() > 0
  }

  function trackedDetailNodes() {
    if (!detailOpen) return []
    var tracked = []
    for (var i = 0; i < nativeNodes.length; i++) {
      var node = nativeNodes[i]
      if (isOutputDevice(node) || isInputDevice(node) || isPlaybackStream(node)) tracked.push(node)
    }
    return tracked
  }

  function findNodeById(id) {
    var requested = String(id || "")
    for (var i = 0; i < nativeNodes.length; i++) {
      if (nodeId(nativeNodes[i]) === requested) return nativeNodes[i]
    }
    return null
  }

  function findOutput(identity) {
    var requested = String(identity || "")
    for (var i = 0; i < nativeNodes.length; i++) {
      var node = nativeNodes[i]
      if (isOutputDevice(node) && (nodeId(node) === requested || nodeName(node) === requested)) return node
    }
    return null
  }

  function findInput(identity) {
    var requested = String(identity || "")
    for (var i = 0; i < nativeNodes.length; i++) {
      var node = nativeNodes[i]
      if (isInputDevice(node) && (nodeId(node) === requested || nodeName(node) === requested)) return node
    }
    return null
  }

  function refreshDetailSnapshots() {
    if (!detailOpen) return
    var nextOutputs = []
    var nextInputs = []
    var nextStreams = []

    for (var i = 0; i < nativeNodes.length; i++) {
      var node = nativeNodes[i]
      if (!node) continue
      if (isOutputDevice(node) && node.audio) {
        nextOutputs.push({
          id: nodeId(node), name: nodeName(node), description: nodeLabel(node),
          icon: outputGlyph(node), current: nodeId(node) === nodeId(defaultOutputNode)
        })
      } else if (isInputDevice(node) && node.audio) {
        nextInputs.push({
          id: nodeId(node), name: nodeName(node), description: nodeLabel(node),
          icon: inputGlyph(node), current: nodeId(node) === nodeId(defaultInputNode)
        })
      } else if (isPlaybackStream(node) && node.audio) {
        nextStreams.push({
          id: nodeId(node), name: nodeName(node), description: streamLabel(node),
          volume: Math.round(clamp(node.audio.volume, 0, 1.5) * 100), muted: Boolean(node.audio.muted)
        })
      }
    }

    nextOutputs.sort(function(a, b) {
      if (a.current !== b.current) return a.current ? -1 : 1
      return a.description.localeCompare(b.description)
    })
    nextInputs.sort(function(a, b) {
      if (a.current !== b.current) return a.current ? -1 : 1
      return a.description.localeCompare(b.description)
    })
    nextStreams.sort(function(a, b) { return a.description.localeCompare(b.description) })
    outputs = nextOutputs
    inputs = nextInputs
    streams = nextStreams
  }

  function scheduleDetailRefresh() {
    if (detailOpen) detailRefreshDelay.restart()
  }

  function clearDetailSnapshots() {
    detailRefreshDelay.stop()
    outputs = []
    inputs = []
    streams = []
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

  function clearPending() {
    pendingKey = ""
    pendingKind = ""
    pendingNodeId = ""
    pendingExpected = null
    pendingDeadline = 0
  }

  function pendingSatisfied() {
    if (!pending) return true
    if (pendingKind === "default-output") return nodeId(defaultOutputNode) === pendingNodeId
    if (pendingKind === "default-input") return nodeId(defaultInputNode) === pendingNodeId

    var node = findNodeById(pendingNodeId)
    if (!node || !node.audio) return false
    if (pendingKind === "output-volume" || pendingKind === "input-volume" || pendingKind === "stream-volume")
      return Math.abs(Number(node.audio.volume) - Number(pendingExpected)) <= 0.011
    if (pendingKind === "output-muted" || pendingKind === "input-muted" || pendingKind === "stream-muted")
      return Boolean(node.audio.muted) === Boolean(pendingExpected)
    return false
  }

  function checkPending() {
    if (!pending) return
    if (pendingSatisfied()) {
      clearPending()
      error = ""
      scheduleDetailRefresh()
      return
    }
    if (Date.now() >= pendingDeadline) {
      var timedOutKey = pendingKey
      clearPending()
      error = "Audio action timed out: " + timedOutKey
      scheduleDetailRefresh()
    }
  }

  function beginMutation(key, kind, node, expected, action) {
    if (!actionsEnabled) {
      error = "Audio controls are locked in read-only mode"
      return false
    }
    if (!node) {
      error = "Audio target is no longer available"
      return false
    }
    if (pending) {
      error = "Audio action already pending: " + pendingKey
      return false
    }

    error = ""
    pendingKey = String(key)
    pendingKind = String(kind)
    pendingNodeId = nodeId(node)
    pendingExpected = expected
    pendingDeadline = Date.now() + mutationTimeoutMs

    try {
      action(node)
    } catch (e) {
      clearPending()
      error = "Audio action failed: " + String(e)
      return false
    }

    Qt.callLater(checkPending)
    return true
  }

  function setVolume(percent) {
    var requested = Number(percent)
    if (!isFinite(requested)) return false
    var node = defaultOutputNode
    var value = clamp(Math.round(requested) / 100, 0, 1)
    return beginMutation("output:" + nodeId(node) + ":volume", "output-volume", node, value,
      function(target) { target.audio.volume = value })
  }

  function volumeUp() { return setVolume(volume + 5) }
  function volumeDown() { return setVolume(volume - 5) }

  function toggleMute() {
    var node = defaultOutputNode
    var expected = node && node.audio ? !Boolean(node.audio.muted) : false
    return beginMutation("output:" + nodeId(node) + ":mute", "output-muted", node, expected,
      function(target) { target.audio.muted = expected })
  }

  function setInputVolume(percent) {
    var requested = Number(percent)
    if (!isFinite(requested)) return false
    var node = defaultInputNode
    var value = clamp(Math.round(requested) / 100, 0, 1)
    return beginMutation("input:" + nodeId(node) + ":volume", "input-volume", node, value,
      function(target) { target.audio.volume = value })
  }

  function toggleInputMute() {
    var node = defaultInputNode
    var expected = node && node.audio ? !Boolean(node.audio.muted) : false
    return beginMutation("input:" + nodeId(node) + ":mute", "input-muted", node, expected,
      function(target) { target.audio.muted = expected })
  }

  function setOutput(identity) {
    var node = findOutput(identity)
    return beginMutation("output:" + nodeId(node) + ":default", "default-output", node, nodeId(node),
      function(target) { backend.preferredDefaultAudioSink = target })
  }

  function setInput(identity) {
    var node = findInput(identity)
    return beginMutation("input:" + nodeId(node) + ":default", "default-input", node, nodeId(node),
      function(target) { backend.preferredDefaultAudioSource = target })
  }

  function setStreamVolume(identity, percent) {
    var requested = Number(percent)
    if (!isFinite(requested)) return false
    var node = findNodeById(identity)
    if (!isPlaybackStream(node)) node = null
    var value = clamp(Math.round(requested) / 100, 0, 1.5)
    return beginMutation("stream:" + nodeId(node) + ":volume", "stream-volume", node, value,
      function(target) { target.audio.volume = value })
  }

  function toggleStreamMute(identity) {
    var node = findNodeById(identity)
    if (!isPlaybackStream(node)) node = null
    var expected = node && node.audio ? !Boolean(node.audio.muted) : false
    return beginMutation("stream:" + nodeId(node) + ":mute", "stream-muted", node, expected,
      function(target) { target.audio.muted = expected })
  }

  onDetailOpenChanged: {
    if (detailOpen) scheduleDetailRefresh()
    else clearDetailSnapshots()
  }
  onNativeNodesChanged: {
    scheduleDetailRefresh()
    checkPending()
  }
  onDefaultOutputNodeChanged: {
    scheduleDetailRefresh()
    checkPending()
  }
  onDefaultInputNodeChanged: {
    scheduleDetailRefresh()
    checkPending()
  }

  PwObjectTracker {
    objects: root.useNativeBackend
      ? [root.defaultOutputNode, root.defaultInputNode].filter(function(node) { return node !== null })
      : []
  }

  PwObjectTracker {
    objects: root.useNativeBackend && root.detailOpen ? root.trackedDetailNodes() : []
  }

  PwNodePeakMonitor {
    id: inputPeakMonitor
    node: root.useNativeBackend && root.detailOpen ? root.defaultInputNode : null
    enabled: root.useNativeBackend && root.detailOpen && node !== null
  }

  Timer {
    id: detailRefreshDelay
    interval: 75
    repeat: false
    onTriggered: root.refreshDetailSnapshots()
  }

  Timer {
    interval: 400
    running: root.detailOpen
    repeat: true
    onTriggered: root.refreshDetailSnapshots()
  }

  Timer {
    interval: 100
    running: root.pending
    repeat: true
    onTriggered: root.checkPending()
  }

  Connections {
    target: root.defaultOutputNode && root.defaultOutputNode.audio ? root.defaultOutputNode.audio : null
    function onMutedChanged() { root.checkPending() }
    function onVolumesChanged() { root.checkPending() }
  }

  Connections {
    target: root.defaultInputNode && root.defaultInputNode.audio ? root.defaultInputNode.audio : null
    function onMutedChanged() { root.checkPending() }
    function onVolumesChanged() { root.checkPending() }
  }
}
