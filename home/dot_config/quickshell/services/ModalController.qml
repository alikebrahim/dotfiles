import QtQml

QtObject {
  id: root

  property string activeSurface: ""
  property bool activeSurfaceFocused: false
  property bool dismissImmediately: false

  signal closeRequested(string surface)

  function activate(surface) {
    var requested = String(surface || "")
    if (!requested) return false
    if (activeSurface === requested) return true

    var previous = activeSurface
    activeSurface = requested
    activeSurfaceFocused = false
    if (previous) closeRequested(previous)
    return true
  }

  function release(surface) {
    if (activeSurface !== String(surface || "")) return false
    activeSurface = ""
    activeSurfaceFocused = false
    return true
  }

  function reportWindowActive(surface, active) {
    if (activeSurface !== String(surface || "")) return false
    if (active) {
      activeSurfaceFocused = true
      return false
    }
    if (!activeSurfaceFocused) return false
    return closeActive(true)
  }

  function closeActive(immediate) {
    if (!activeSurface) return false
    dismissImmediately = immediate === true
    var previous = activeSurface
    activeSurface = ""
    activeSurfaceFocused = false
    closeRequested(previous)
    dismissImmediately = false
    return true
  }
}
