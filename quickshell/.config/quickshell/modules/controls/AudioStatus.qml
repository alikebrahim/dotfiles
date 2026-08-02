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
  tooltipText: service
    ? "Audio — " + (service.muted ? "muted" : service.volume + "%")
    : "Audio unavailable"
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
