import QtQuick
import Quickshell.Io

Item {
  id: root

  property string queuedText: ""
  property string lastCopiedLabel: ""
  property string error: ""
  property int timeoutMs: 1500
  property int terminateGraceMs: 250
  property var commandOverride: []
  property bool timedOut: false
  readonly property bool busy: copier.running

  visible: false

  signal copied(string label)

  function copyText(value, label) {
    var text = String(value || "").replace(/[\r\n]+/g, " ").trim()
    if (!text || text.length > 512 || copier.running) return false
    queuedText = text
    lastCopiedLabel = String(label || "Value")
    error = ""
    copier.command = Array.isArray(commandOverride) && commandOverride.length > 0
      ? commandOverride.slice()
      : [
      "/usr/bin/bash", "-c",
      "printf '%s' \"$1\" | /usr/sbin/xclip -selection clipboard -in",
      "quickshell-x11-copy", text
    ]
    timedOut = false
    copier.running = true
    return true
  }

  Process {
    id: copier
    stderr: StdioCollector { }

    onStarted: copyTimeout.restart()

    onExited: function(exitCode) {
      copyTimeout.stop()
      forceKill.stop()
      root.queuedText = ""
      if (root.timedOut) root.error = "Clipboard copy timed out"
      else if (exitCode === 0) root.copied(root.lastCopiedLabel)
      else root.error = String(stderr.text || "xclip failed").trim()
    }
  }

  Timer {
    id: copyTimeout
    interval: root.timeoutMs
    repeat: false
    onTriggered: {
      if (!copier.running) return
      root.timedOut = true
      copier.signal(15)
      forceKill.restart()
    }
  }

  Timer {
    id: forceKill
    interval: root.terminateGraceMs
    repeat: false
    onTriggered: if (copier.running) copier.signal(9)
  }
}
