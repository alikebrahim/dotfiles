import QtQuick

Item {
  id: root

  required property QtObject transport
  property bool refreshOnStart: true
  property int refreshInterval: 30000

  property bool present: false
  property int percentage: 0
  property string state: "unknown"
  property bool onBattery: false
  property string profile: ""
  property var profiles: []
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
    transport.request("power.upower", ["upower", "--dump"], false)
    transport.request("power.active", ["tuned-adm", "active"], false)
    transport.request("power.profiles", ["tuned-adm", "list"], false)
  }

  function valueFor(section, key) {
    var match = String(section || "").match(new RegExp("^[ \\t]*" + key + ":[ \\t]*(.*?)[ \\t]*$", "mi"))
    return match ? String(match[1]).trim() : ""
  }

  function applyUpower(raw) {
    var text = String(raw || "")
    var lines = text.split(/\r?\n/)
    var sections = []
    var current = []
    for (var lineIndex = 0; lineIndex < lines.length; lineIndex++) {
      if (/^Device:\s/.test(lines[lineIndex]) && current.length > 0) {
        sections.push(current.join("\n"))
        current = []
      }
      current.push(lines[lineIndex])
    }
    if (current.length > 0) sections.push(current.join("\n"))
    var selected = ""
    for (var i = 0; i < sections.length; i++) {
      var section = sections[i]
      var pathMatch = section.match(/^Device:\s*(\S+)/m)
      var path = pathMatch ? pathMatch[1] : ""
      var isBattery = /\/battery_/i.test(path) || /\/DisplayDevice$/i.test(path)
      if (!isBattery) continue
      if (valueFor(section, "power supply") !== "yes" || valueFor(section, "present") !== "yes") continue
      selected = section
      if (/\/DisplayDevice$/i.test(path)) break
    }
    if (!selected) {
      if (text.trim() !== "" && !/^Device:\s/m.test(text)) return false
      present = false
      percentage = 0
      state = "unknown"
      return true
    }

    var percentMatch = valueFor(selected, "percentage").match(/^(\d+(?:\.\d+)?)%$/)
    var stateValue = valueFor(selected, "state").toLowerCase()
    var allowedStates = ["unknown", "charging", "discharging", "empty", "fully-charged", "pending-charge", "pending-discharge"]
    if (!percentMatch || allowedStates.indexOf(stateValue) === -1) return false
    var parsed = Number(percentMatch[1])
    if (!isFinite(parsed) || parsed < 0 || parsed > 100) return false

    present = true
    percentage = Math.round(parsed)
    state = stateValue
    var batteryValue = valueFor(text, "on-battery")
    onBattery = batteryValue === "yes" || stateValue === "discharging"
    return true
  }

  function applyActive(raw) {
    var match = String(raw || "").match(/Current active profile:\s*([A-Za-z0-9][A-Za-z0-9._-]{0,127})/i)
    if (!match) return false
    profile = match[1]
    return true
  }

  function applyProfiles(raw) {
    var lines = String(raw || "").split(/\r?\n/)
    var next = []
    for (var i = 0; i < lines.length; i++) {
      var match = lines[i].match(/^\s*(?:-\s*)?([A-Za-z0-9][A-Za-z0-9._-]{0,127})(?:\s+-.*)?\s*$/)
      if (match && next.indexOf(match[1]) === -1) next.push(match[1])
    }
    if (next.length === 0) return false
    profiles = next
    return true
  }

  function setProfile(name) {
    var requested = String(name || "")
    if (!/^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$/.test(requested) || profiles.indexOf(requested) === -1) return false
    transport.request("power.set-profile", ["tuned-adm", "profile", requested], true)
    return true
  }

  Connections {
    target: root.transport
    function onFinished(requestId, key, ok, output, message) {
      if (!key.startsWith("power.")) return
      if (!ok) { root.setResponseError(key, message); return }
      var parsed = true
      if (key === "power.upower") parsed = root.applyUpower(output)
      else if (key === "power.active") parsed = root.applyActive(output)
      else if (key === "power.profiles") parsed = root.applyProfiles(output)
      else if (key === "power.set-profile") Qt.callLater(root.refresh)
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
