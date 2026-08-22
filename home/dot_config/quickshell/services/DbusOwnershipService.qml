import QtQuick
import Quickshell
import Quickshell.Io

// Read-only health probe for the two D-Bus names Quickshell must own. Object
// construction is not treated as ownership: busctl must report this exact PID.
Item {
  id: root

  property bool probeEnabled: true
  property int refreshIntervalMs: 30000
  readonly property int shellPid: Quickshell.processId

  property string notificationsState: "checking"
  property int notificationsOwnerPid: 0
  property string notificationsError: ""
  property string statusNotifierState: "checking"
  property int statusNotifierOwnerPid: 0
  property string statusNotifierError: ""
  property double lastRefreshAtMs: 0

  readonly property bool notificationsOwnedByShell: notificationsState === "owned"
  readonly property bool statusNotifierOwnedByShell: statusNotifierState === "owned"
  readonly property bool healthy: notificationsOwnedByShell && statusNotifierOwnedByShell

  visible: false

  function parseOwnerStatus(stdoutText, stderrText, exitCode, expectedPid) {
    var output = String(stdoutText || "")
    var errorText = String(stderrText || "").trim()
    if (Number(exitCode) !== 0) {
      var lower = errorText.toLowerCase()
      if (lower.indexOf("no such device or address") >= 0
          || lower.indexOf("has no owner") >= 0
          || lower.indexOf("was not provided") >= 0
          || lower.indexOf("name not found") >= 0) {
        return { state: "unowned", pid: 0, error: "" }
      }
      return {
        state: "unknown",
        pid: 0,
        error: errorText || ("busctl exited " + Number(exitCode))
      }
    }

    var match = output.match(/(?:^|\n)\s*PID=(\d+)\s*(?:\n|$)/)
    if (!match) {
      return { state: "unknown", pid: 0, error: "busctl returned no PID" }
    }

    var ownerPid = Number(match[1])
    return {
      state: ownerPid === Number(expectedPid) ? "owned" : "foreign",
      pid: ownerPid,
      error: ""
    }
  }

  function applyNotificationsResult(result) {
    notificationsState = String(result.state || "unknown")
    notificationsOwnerPid = Number(result.pid || 0)
    notificationsError = String(result.error || "")
    lastRefreshAtMs = Date.now()
  }

  function applyStatusNotifierResult(result) {
    statusNotifierState = String(result.state || "unknown")
    statusNotifierOwnerPid = Number(result.pid || 0)
    statusNotifierError = String(result.error || "")
    lastRefreshAtMs = Date.now()
  }

  function refresh() {
    if (!probeEnabled) return false
    if (!notificationsProbe.running) notificationsProbe.running = true
    if (!statusNotifierProbe.running) statusNotifierProbe.running = true
    return true
  }

  Process {
    id: notificationsProbe
    command: ["busctl", "--user", "--no-pager", "status", "org.freedesktop.Notifications"]
    stdout: StdioCollector { id: notificationsStdout }
    stderr: StdioCollector { id: notificationsStderr }
    onExited: (exitCode, exitStatus) => root.applyNotificationsResult(
      root.parseOwnerStatus(notificationsStdout.text, notificationsStderr.text,
                            exitCode, root.shellPid))
  }

  Process {
    id: statusNotifierProbe
    command: ["busctl", "--user", "--no-pager", "status", "org.kde.StatusNotifierWatcher"]
    stdout: StdioCollector { id: statusNotifierStdout }
    stderr: StdioCollector { id: statusNotifierStderr }
    onExited: (exitCode, exitStatus) => root.applyStatusNotifierResult(
      root.parseOwnerStatus(statusNotifierStdout.text, statusNotifierStderr.text,
                            exitCode, root.shellPid))
  }

  Timer {
    interval: root.refreshIntervalMs
    repeat: true
    running: root.probeEnabled
    onTriggered: root.refresh()
  }

  Timer {
    interval: 250
    running: root.probeEnabled
    repeat: false
    onTriggered: root.refresh()
  }
}
