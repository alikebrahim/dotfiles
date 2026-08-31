import QtQuick

StatusText {
  property var service: null
  text: {
    if (!service || !service.present) return ""
    var defaultIcons = [0xF007A, 0xF007B, 0xF007C, 0xF007D, 0xF007E, 0xF007F, 0xF0080, 0xF0081, 0xF0082, 0xF0079]
    var index = Math.max(0, Math.min(9, Math.floor(service.percentage / 10)))
    return String.fromCodePoint(defaultIcons[index])
  }
  tooltipText: service && service.present
    ? "Battery — " + service.percentage + "% " + service.state
    : "Battery unavailable"
  visible: service !== null && service.present
  available: service !== null && service.present
}
