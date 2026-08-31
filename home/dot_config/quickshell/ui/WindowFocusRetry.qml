import QtQuick

// Bounded X11 activation retry. Request focus after the backing window is
// visible/focusable, then wait for QWindow.active. Bar popouts must not close
// themselves on failure; the launcher may.
Item {
  id: root

  property var panel: null
  property int attemptLimit: 8
  property int intervalMs: 60
  property int attemptCount: 0
  property bool running: false

  signal succeeded()
  signal failed()

  function begin() {
    attemptCount = 0
    running = true
    // Try immediately: if the window is already active (e.g. a sibling
    // switch that kept the overlay mapped/focused), succeed on this pass
    // instead of waiting one retry interval.
    attempt()
  }

  function stop() {
    running = false
    retryTimer.stop()
    attemptCount = 0
  }

  function attempt() {
    if (!running) return

    var windowObject = panel && panel.contentItem ? panel.contentItem.Window.window : null
    if (windowObject && panel.visible && panel.focusable) {
      if (windowObject.active) {
        stop()
        succeeded()
        return
      }
      windowObject.requestActivate()
    }

    attemptCount += 1
    if (attemptCount < attemptLimit) {
      retryTimer.restart()
      return
    }

    running = false
    failed()
  }

  Timer {
    id: retryTimer
    interval: Math.max(1, root.intervalMs)
    repeat: false
    onTriggered: root.attempt()
  }
}
