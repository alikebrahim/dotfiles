import QtQuick
import Quickshell
import Quickshell.Io
import "../../style" as ShellStyle

Item {
  id: root

  required property QtObject bridge

  property bool opened: false
  property int eventSerial: 0
  property string eventType: ""
  property string iconKey: ""
  property string iconText: ""
  property string message: ""
  property int value: 0
  property int maxValue: 100
  property bool hasProgress: false
  property int duration: 1200

  readonly property string focusedOutputId: bridge ? String(bridge.focusedOutput || "") : ""
  readonly property string focusedOutputName: outputNameForId(focusedOutputId)
  readonly property string primaryOutputId: bridge ? String(bridge.primaryOutput || "") : ""
  readonly property string primaryOutputName: outputNameForId(primaryOutputId)
  readonly property var resolvedScreen: screenForName(focusedOutputName)
    || screenForName(primaryOutputName) || firstAvailableScreen()
  readonly property alias panel: panel

  visible: false

  function outputNameForId(outputId) {
    var outputs = bridge && Array.isArray(bridge.outputs) ? bridge.outputs : []
    for (var i = 0; i < outputs.length; i++) {
      if (String(outputs[i].id || "") === String(outputId || ""))
        return String(outputs[i].name || "")
    }
    return ""
  }

  function screenForName(name) {
    if (!name) return null
    var screens = Quickshell.screens
    for (var i = 0; i < screens.length; i++) {
      if (String(screens[i].name || "") === String(name)) return screens[i]
    }
    return null
  }

  function firstAvailableScreen() {
    for (var i = 0; i < Quickshell.screens.length; i++)
      if (Quickshell.screens[i]) return Quickshell.screens[i]
    return null
  }

  function normalizedType(value) {
    var type = String(value || "").toLowerCase()
    if (type === "mic") type = "microphone"
    if (type !== "volume" && type !== "brightness" && type !== "microphone") return ""
    return type
  }

  function iconFor(type, muted, percent) {
    if (type === "brightness") return { key: "brightness", text: String.fromCodePoint(0xF0379) }
    if (type === "microphone") return {
      key: muted ? "microphone-muted" : "microphone",
      text: String.fromCodePoint(muted ? 0xF036D : 0xF036C)
    }
    if (muted) return { key: "volume-muted", text: "\ueee8" }
    if (percent <= 33) return { key: "volume", text: "\uf026" }
    if (percent <= 66) return { key: "volume", text: "\uf027" }
    return { key: "volume", text: "\uf028" }
  }

  function showPayload(payload) {
    var source = payload
    if (typeof source === "string") {
      try { source = JSON.parse(source || "{}") }
      catch (e) { return false }
    }
    if (!source || typeof source !== "object") return false

    var type = normalizedType(source.type || source.icon)
    if (!type) return false

    var maximum = Number(source.max === undefined ? 100 : source.max)
    if (!isFinite(maximum) || maximum <= 0) maximum = 100
    maximum = Math.max(1, Math.min(1000, Math.round(maximum)))

    var muted = source.muted === true
    var suppliedValue = source.value !== undefined && source.value !== null && source.value !== ""
    var parsedValue = Number(suppliedValue ? source.value : 0)
    if (!isFinite(parsedValue)) parsedValue = 0
    parsedValue = Math.max(0, Math.min(maximum, Math.round(parsedValue)))
    var progress = suppliedValue && !muted
    var percent = progress ? Math.round(parsedValue * 100 / maximum) : 0

    var requestedDuration = Number(source.duration === undefined ? 1200 : source.duration)
    if (!isFinite(requestedDuration)) requestedDuration = 1200
    requestedDuration = Math.max(250, Math.min(5000, Math.round(requestedDuration)))

    var icon = iconFor(type, muted, percent)
    hideTimer.stop()
    eventType = type
    iconKey = icon.key
    iconText = icon.text
    maxValue = maximum
    value = progress ? parsedValue : 0
    hasProgress = progress
    message = String(source.message || (progress ? percent + "%" : (muted ? "Muted" : type)))
    duration = requestedDuration
    eventSerial += 1
    opened = true
    hideTimer.restart()
    return true
  }

  function close() {
    hideTimer.stop()
    opened = false
  }

  Timer {
    id: hideTimer
    interval: root.duration
    repeat: false
    onTriggered: root.opened = false
  }

  IpcHandler {
    target: "osd"
    function show(payloadJson: string): string { return root.showPayload(payloadJson) ? "ok" : "invalid" }
    function close(): string { root.close(); return "ok" }
    function state(): string { return root.opened ? "open" : "closed" }
    function ping(): string { return "ok" }
  }

  PanelWindow {
    id: panel

    visible: root.opened && root.resolvedScreen !== null
    screen: root.resolvedScreen
    anchors.bottom: true
    margins.bottom: 67
    implicitWidth: 284
    implicitHeight: 64
    color: "transparent"
    surfaceFormat.opaque: false
    focusable: false
    aboveWindows: true
    exclusionMode: ExclusionMode.Ignore
    exclusiveZone: 0
    mask: Region { }

    Rectangle {
      anchors.fill: parent
      radius: ShellStyle.Metrics.cornerRadius
      color: ShellStyle.Palette.panel
      border.width: 2
      border.color: ShellStyle.Palette.panelBorder

      Row {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 16

        Text {
          width: 24
          height: parent.height
          text: root.iconText
          textFormat: Text.PlainText
          color: ShellStyle.Palette.foreground
          font.family: ShellStyle.Metrics.fontFamily
          font.pixelSize: ShellStyle.Metrics.displayLargeSize
          horizontalAlignment: Text.AlignHCenter
          verticalAlignment: Text.AlignVCenter
        }

        Item {
          width: parent.width - 40
          height: parent.height

          Rectangle {
            visible: root.hasProgress
            anchors.left: parent.left
            anchors.right: valueLabel.left
            anchors.rightMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            height: 6
            radius: height / 2
            color: ShellStyle.Palette.controlBorder

            Rectangle {
              width: parent.width * (root.maxValue > 0 ? root.value / root.maxValue : 0)
              height: parent.height
              radius: parent.radius
              color: ShellStyle.Palette.accent
            }
          }

          Text {
            id: valueLabel
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: root.hasProgress ? 54 : parent.width
            text: root.message
            textFormat: Text.PlainText
            color: ShellStyle.Palette.foreground
            font.family: ShellStyle.Metrics.fontFamily
            font.pixelSize: ShellStyle.Metrics.titleSize
            font.bold: true
            horizontalAlignment: root.hasProgress ? Text.AlignRight : Text.AlignLeft
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
          }
        }
      }
    }
  }
}
