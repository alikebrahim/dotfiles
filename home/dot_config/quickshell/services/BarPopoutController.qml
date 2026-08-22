import QtQuick

Item {
  id: root

  required property QtObject modalController
  property string activePopout: ""
  property bool activePopoutFocused: false
  property bool dismissImmediately: false

  visible: false

  readonly property string umbrellaSurface: "bar-popout"

  signal closeRequested(string popout)

  function activate(popout) {
    var requested = String(popout || "")
    if (!requested) return false

    if (activePopout === requested) {
      modalController.activate(umbrellaSurface)
      return true
    }

    var previous = activePopout
    activePopout = requested
    activePopoutFocused = false
    modalController.activate(umbrellaSurface)
    if (previous) closeRequested(previous)
    return true
  }

  function release(popout) {
    if (activePopout !== String(popout || "")) return false
    activePopout = ""
    activePopoutFocused = false
    modalController.release(umbrellaSurface)
    return true
  }

  function reportWindowActive(popout, active) {
    if (activePopout !== String(popout || "")) return false
    if (active) {
      activePopoutFocused = true
      return false
    }
    if (!activePopoutFocused) return false
    return closeActive(true)
  }

  function closeActive(immediate) {
    if (!activePopout) return false

    dismissImmediately = immediate === true
    var previous = activePopout
    activePopout = ""
    activePopoutFocused = false
    modalController.release(umbrellaSurface)
    closeRequested(previous)
    dismissImmediately = false
    return true
  }

  Connections {
    target: root.modalController

    function onCloseRequested(surface) {
      if (surface !== root.umbrellaSurface || !root.activePopout) return
      var previous = root.activePopout
      root.activePopout = ""
      root.activePopoutFocused = false
      root.closeRequested(previous)
    }
  }
}
