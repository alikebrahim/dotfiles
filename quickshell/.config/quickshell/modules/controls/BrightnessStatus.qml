import QtQuick

StatusText {
  id: root
  property var service: null
  text: String.fromCodePoint(0xF0379)
  tooltipText: service && service.available ? "Brightness — " + service.percentage + "%" : "Brightness unavailable"
  available: service !== null && service.available

  WheelHandler {
    onWheel: function(event) {
      if (!root.service || !root.service.actionsEnabled) return
      if (event.angleDelta.y > 0) root.service.increase()
      else if (event.angleDelta.y < 0) root.service.decrease()
    }
  }
}
