import QtQuick
// Narrow boundary for destructive desktop-session actions. Callers must arm an
// exact fixed action before execution; arbitrary commands are never accepted.
Item {
  id: root

  required property QtObject transport
  // Test fixtures may replace an allowlisted action with a harmless fixed
  // command. Production leaves this empty.
  property var commandOverrides: ({})
  property string armedAction: ""
  property string error: ""
  property bool busy: false
  property int pendingRequestId: 0
  property string pendingAction: ""

  signal actionStarted(string action)
  signal actionAccepted(string action)
  signal actionFailed(string action, string message)

  visible: false

  function isValidAction(action) {
    return action === "suspend"
      || action === "logout"
      || action === "restart"
      || action === "poweroff"
  }

  function actionLabel(action) {
    if (action === "suspend") return "Suspend"
    if (action === "logout") return "Logout"
    if (action === "restart") return "Restart"
    if (action === "poweroff") return "Power off"
    return ""
  }

  function commandFor(action) {
    var override = commandOverrides && commandOverrides[action]
    if (Array.isArray(override) && override.length > 0) return override.slice()
    if (action === "suspend") return ["/usr/sbin/systemctl", "--no-block", "suspend"]
    if (action === "logout") return [
      "/usr/sbin/awesome-client",
      "local ok, err = pcall(function() awesome.quit() end); "
        + "if not ok then return 'ERROR:' .. tostring(err) end; return 'ACCEPTED'"
    ]
    if (action === "restart") return ["/usr/sbin/systemctl", "--no-block", "reboot"]
    if (action === "poweroff") return ["/usr/sbin/systemctl", "--no-block", "poweroff"]
    return []
  }

  function arm(action) {
    var requested = String(action || "")
    if (busy || !isValidAction(requested)) return false
    armedAction = requested
    error = ""
    return true
  }

  function cancelConfirmation() {
    armedAction = ""
    error = ""
    return true
  }

  function executeConfirmed(action) {
    var requested = String(action || "")
    if (busy || requested === "" || requested !== armedAction) {
      error = "Action is not confirmed"
      return false
    }

    var command = commandFor(requested)
    if (command.length === 0) {
      error = "Unsupported session action"
      return false
    }

    var requestId = transport.request("session." + requested, command, true)
    if (requestId <= 0) {
      error = transport.lastError || "Session action could not be started"
      return false
    }

    armedAction = ""
    error = ""
    busy = true
    pendingRequestId = requestId
    pendingAction = requested
    actionStarted(requested)
    return true
  }

  Connections {
    target: root.transport

    function onFinished(requestId, key, success, output, errorMessage) {
      if (requestId !== root.pendingRequestId) return

      var completedAction = root.pendingAction
      var accepted = Boolean(success)
      var message = String(errorMessage || "")
      if (accepted && completedAction === "logout"
          && String(output || "").indexOf("ACCEPTED") < 0) {
        accepted = false
        message = "Awesome did not acknowledge logout"
      }

      root.pendingRequestId = 0
      root.pendingAction = ""
      root.busy = false
      if (accepted) {
        root.error = ""
        root.actionAccepted(completedAction)
      } else {
        root.error = message || (root.actionLabel(completedAction) + " failed")
        root.armedAction = completedAction
        root.actionFailed(completedAction, root.error)
      }
    }
  }
}
