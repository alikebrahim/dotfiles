import QtQuick
import "../../services"

// ClockLabel.qml — date/time display.
//
// Uses a plain QtQuick Timer + JS Date rather than Quickshell's
// SystemClock type (mentioned as available in quickshell-research.md's
// glossary but not confirmed against this exact 0.3.0 install's type
// info) — avoids depending on an unverified API for something this
// simple. Revisit with SystemClock later if confirmed to reduce timer
// overhead once more bar instances/screens are involved.
Text {
    id: root

    property string currentTime: Qt.formatDateTime(new Date(), "ddd, dd MMM yyyy  HH:mm:ss")

    text: currentTime
    color: Theme.colors.foreground
    font.family: Theme.fontFamily
    font.pixelSize: 13

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: root.currentTime = Qt.formatDateTime(new Date(), "ddd, dd MMM yyyy  HH:mm:ss")
    }
}
