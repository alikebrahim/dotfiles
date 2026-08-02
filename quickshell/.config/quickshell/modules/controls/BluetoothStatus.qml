StatusText {
  property var service: null
  text: !service || !service.powered
    ? String.fromCodePoint(0xF00B2)
    : (service.connectedName ? String.fromCodePoint(0xF00B1) : String.fromCodePoint(0xF00AF))
  tooltipText: service && service.connectedName
    ? "Bluetooth — " + service.connectedName
    : (service && service.powered ? "Bluetooth on" : "Bluetooth off")
  available: service !== null && service.available
}
