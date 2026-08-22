import QtQuick
import Quickshell
import Quickshell.Io

Item {
  id: root

  property bool fixtureMode: false
  // Reads are always available. Native writes require an explicit production
  // gate or a test fixture that opts in.
  property bool allowMutations: false
  property int timeoutMs: 8000
  property int terminateGraceMs: 1000
  property int maxQueued: 32
  property var fixtureResponses: ({})
  property var recordedActions: []
  readonly property bool busy: runner.running || activeJob !== null || queue.length > 0

  property int nextRequestId: 1
  property var queue: []
  property var activeJob: null
  property bool activeTimedOut: false

  signal finished(int requestId, string key, bool ok, string output, string error)

  visible: false

  function request(key, command, mutating, detached) {
    var requestId = nextRequestId++
    var safeCommand = Array.isArray(command) ? command.slice() : []
    var validCommand = safeCommand.length > 0
    for (var commandIndex = 0; commandIndex < safeCommand.length; commandIndex++)
      if (typeof safeCommand[commandIndex] !== "string" || safeCommand[commandIndex] === "") validCommand = false
    if (!key || !validCommand || (detached && !mutating)) {
      Qt.callLater(function() { root.finished(requestId, String(key || ""), false, "", "invalid request") })
      return requestId
    }

    if (mutating && !allowMutations) {
      Qt.callLater(function() { root.finished(requestId, key, false, "", "mutations disabled") })
      return requestId
    }

    if (fixtureMode) {
      if (mutating) {
        var actions = recordedActions.slice()
        actions.push({ key: key, command: safeCommand, detached: !!detached })
        recordedActions = actions
        Qt.callLater(function() { root.finished(requestId, key, true, "", "") })
        return requestId
      }

      var response = fixtureResponses[key]
      var ok = response !== undefined
      var output = ""
      var error = ok ? "" : "missing fixture: " + key
      if (response && typeof response === "object") {
        ok = response.ok !== false
        output = String(response.output || "")
        error = String(response.error || "")
      } else if (ok) {
        output = String(response)
      }
      Qt.callLater(function() { root.finished(requestId, key, ok, output, error) })
      return requestId
    }

    if (detached) {
      try {
        Quickshell.execDetached(safeCommand)
        Qt.callLater(function() { root.finished(requestId, key, true, "", "") })
      } catch (error) {
        Qt.callLater(function() { root.finished(requestId, key, false, "", String(error)) })
      }
      return requestId
    }

    if (!mutating) {
      if (activeJob !== null && !activeJob.mutating && activeJob.key === key) return activeJob.id
      for (var queueIndex = 0; queueIndex < queue.length; queueIndex++)
        if (!queue[queueIndex].mutating && queue[queueIndex].key === key) return queue[queueIndex].id
    }
    if (queue.length >= Math.max(1, maxQueued)) {
      Qt.callLater(function() { root.finished(requestId, key, false, "", "command queue full") })
      return requestId
    }

    var pending = queue.slice()
    var job = { id: requestId, key: key, command: safeCommand, mutating: !!mutating }
    if (mutating) {
      var insertionIndex = 0
      while (insertionIndex < pending.length && pending[insertionIndex].mutating) insertionIndex++
      pending.splice(insertionIndex, 0, job)
    } else {
      pending.push(job)
    }
    queue = pending
    pump()
    return requestId
  }

  function pump() {
    if (runner.running || activeJob !== null || queue.length === 0) return
    activeJob = queue[0]
    queue = queue.slice(1)
    if (activeJob.mutating && !allowMutations) {
      var rejected = activeJob
      activeJob = null
      Qt.callLater(function() {
        root.finished(rejected.id, rejected.key, false, "", "mutations disabled")
        root.pump()
      })
      return
    }
    activeTimedOut = false
    runner.command = activeJob.command
    runner.running = true
  }

  Timer {
    id: requestTimeout
    interval: Math.max(1, root.timeoutMs)
    repeat: false
    onTriggered: {
      if (!runner.running || root.activeJob === null) return
      root.activeTimedOut = true
      runner.signal(15)
      terminateGrace.restart()
    }
  }

  Timer {
    id: terminateGrace
    interval: Math.max(1, root.terminateGraceMs)
    repeat: false
    onTriggered: if (runner.running) runner.signal(9)
  }

  Process {
    id: runner
    stdout: StdioCollector { }
    stderr: StdioCollector { }

    onStarted: requestTimeout.restart()

    onExited: function(exitCode) {
      requestTimeout.stop()
      terminateGrace.stop()
      var job = root.activeJob
      var output = stdout.text
      var timedOut = root.activeTimedOut
      var succeeded = !timedOut && exitCode === 0
      var error = timedOut ? "timed out after " + root.timeoutMs + " ms" : stderr.text
      if (!succeeded && !error) error = "command exited with code " + exitCode
      root.activeJob = null
      root.activeTimedOut = false
      if (job) root.finished(job.id, job.key, succeeded, output, error)
      Qt.callLater(root.pump)
    }
  }
}
