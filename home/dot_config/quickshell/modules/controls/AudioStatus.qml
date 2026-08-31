import QtQuick

StatusText {
  id: root

  property var service: null
  text: {
    if (!service || service.muted) return "\ueee8"
    if (service.volume >= 67) return "\uf028"
    if (service.volume >= 34) return "\uf027"
    return "\uf026"
  }
  tooltipText: {
    if (!service) return "Audio unavailable"
    var base = "Audio — " + (service.muted ? "muted" : service.volume + "%")
    if (!service.actionsEnabled) return base + " · read-only"
    return base + " · scroll to change"
  }
  available: service !== null
  onMiddleActivated: if (service && service.actionsEnabled) service.toggleMute()

  WheelHandler {
    onWheel: function(event) {
      if (!root.service || !root.service.actionsEnabled) return
      if (event.angleDelta.y > 0) root.service.volumeUp()
      else if (event.angleDelta.y < 0) root.service.volumeDown()
    }
  }
}
