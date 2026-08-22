import QtQuick

Item {
  id: root

  required property QtObject transport
  property bool refreshOnStart: true
  property int refreshInterval: 10000

  property string device: ""
  property string deviceClass: ""
  property int current: 0
  property int maximum: 0
  property int percentage: 0
  property bool available: false
  property string error: ""
  property var responseErrors: ({})
  readonly property bool actionsEnabled: transport && transport.allowMutations

  visible: false

  function setResponseError(key, message) {
    var next = {}
    var keys = Object.keys(responseErrors)
    for (var i = 0; i < keys.length; i++)
      if (keys[i] !== key) next[keys[i]] = responseErrors[keys[i]]
    if (message) next[key] = String(message)
    responseErrors = next
    keys = Object.keys(next)
    error = keys.length > 0 ? next[keys[0]] : ""
  }

  function refresh() {
    transport.request("brightness.state", ["brightnessctl", "-m"], false)
  }

  function applyState(raw) {
    var line = String(raw || "").trim().split(/\r?\n/)[0] || ""
    var fields = line.split(",")
    if (fields.length < 5) return false
    var parsedCurrent = Number(fields[2])
    var percentMatch = String(fields[3]).match(/^(\d+)%$/)
    var parsedMaximum = Number(fields[4])
    if (!fields[0] || !percentMatch || !isFinite(parsedCurrent) || !isFinite(parsedMaximum) || parsedMaximum <= 0) return false
    var parsedPercent = Number(percentMatch[1])
    if (parsedPercent < 0 || parsedPercent > 100) return false
    device = fields[0]
    deviceClass = fields[1]
    current = parsedCurrent
    maximum = parsedMaximum
    percentage = parsedPercent
    available = true
    return true
  }

  function increase() {
    if (!available) return false
    transport.request("brightness.increase", ["brightnessctl", "set", "+5%"], true)
    return true
  }

  function decrease() {
    if (!available) return false
    transport.request("brightness.decrease", ["brightnessctl", "set", "5%-"], true)
    return true
  }

  function setPercentage(percent) {
    if (!available) return false
    var requested = Math.max(1, Math.min(100, Math.round(Number(percent))))
    if (!isFinite(requested)) return false
    transport.request("brightness.set", ["brightnessctl", "set", requested + "%"], true)
    return true
  }

  Connections {
    target: root.transport
    function onFinished(requestId, key, ok, output, message) {
      if (!key.startsWith("brightness.")) return
      if (!ok) { root.setResponseError(key, message); return }
      var parsed = true
      if (key === "brightness.state") parsed = root.applyState(output)
      else if (["brightness.increase", "brightness.decrease", "brightness.set"].indexOf(key) !== -1)
        Qt.callLater(root.refresh)
      root.setResponseError(key, parsed ? "" : "invalid state response: " + key)
    }
  }

  Timer {
    interval: root.refreshInterval
    running: root.refreshOnStart && root.refreshInterval > 0
    repeat: true
    onTriggered: root.refresh()
  }

  Component.onCompleted: if (refreshOnStart) refresh()
}
