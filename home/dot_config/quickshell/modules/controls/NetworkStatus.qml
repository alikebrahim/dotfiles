StatusText {
  property var service: null
  text: {
    if (!service || !service.connectionName) return String.fromCodePoint(0xF092E)
    if (service.connectionType.indexOf("ethernet") !== -1) return String.fromCodePoint(0xF0200)
    var icons = [0xF092F, 0xF091F, 0xF0922, 0xF0925, 0xF0928]
    var index = Math.max(0, Math.min(4, Math.ceil(Math.max(0, service.signalStrength) / 20) - 1))
    return String.fromCodePoint(icons[index])
  }
  tooltipText: service && service.connectionName
    ? service.connectionName + (service.signalStrength >= 0 ? " — " + service.signalStrength + "%" : "")
    : "Network disconnected"
  available: service !== null && service.state !== "unknown"
}
