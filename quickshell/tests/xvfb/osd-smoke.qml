import QtQuick
import Quickshell
import services as Services
import modules.osd as Osd

ShellRoot {
  id: root

  readonly property string resultPath: Quickshell.env("QUATTRO_QS_TEST_RESULT")
  property var failures: []
  property bool expiryObserved: false

  Services.AwesomeBridge { id: bridge }

  Osd.Osd {
    id: osd
    bridge: bridge
  }

  function expect(condition, message) {
    if (!condition) failures.push(String(message))
  }

  function shellQuote(value) {
    return "'" + String(value).replace(/'/g, "'\\''") + "'"
  }

  function finish() {
    var payload = JSON.stringify({
      ok: failures.length === 0,
      failures: failures,
      expiryObserved: expiryObserved,
      eventSerial: osd.eventSerial,
      eventType: osd.eventType,
      iconKey: osd.iconKey,
      message: osd.message,
      duration: osd.duration,
      panelVisible: osd.panel.visible,
      panelExclusiveZone: osd.panel.exclusiveZone,
      panelFocusable: osd.panel.focusable,
      screenName: osd.panel.screen ? osd.panel.screen.name : ""
    })
    Quickshell.execDetached(["bash", "-lc", "printf '%s' " + shellQuote(payload) + " > " + shellQuote(resultPath)])
    Qt.callLater(Qt.quit)
  }

  Component.onCompleted: {
    var screenName = Quickshell.screens.length > 0 ? Quickshell.screens[0].name : ""
    bridge.applyRaw(JSON.stringify({
      primaryOutput: "primary",
      focusedOutput: "focused",
      outputs: [
        { id: "primary", name: "unused" },
        { id: "focused", name: screenName }
      ],
      tags: [],
      focusedClient: { title: "", class: "", screen: "focused" }
    }))

    expect(!osd.showPayload({ type: "power", value: 50 }), "unsupported OSD type is rejected")
    expect(osd.eventSerial === 0, "rejected payload does not replace state")
    expect(osd.showPayload({ type: "volume", value: 20, max: 100, duration: 300 }), "volume payload accepted")
  }

  Timer {
    interval: 50
    running: true
    repeat: false
    onTriggered: {
      root.expect(osd.opened && osd.eventSerial === 1 && osd.eventType === "volume", "first OSD event opens")
      var screenName = Quickshell.screens.length > 0 ? Quickshell.screens[0].name : ""
      root.expect(bridge.applyRaw(JSON.stringify({
        primaryOutput: "primary",
        focusedOutput: "focused",
        outputs: [
          { id: "primary", name: screenName },
          { id: "focused", name: "unmapped-focused-output" }
        ],
        tags: [],
        focusedClient: { title: "", class: "", screen: "focused" }
      })), "bridge accepts an authoritative primary output when the focused output is not mapped")
      root.expect(osd.showPayload({ type: "brightness", value: 80, max: 100, duration: 250 }), "brightness replacement accepted")
      Qt.callLater(function() {
        root.expect(osd.opened && osd.eventSerial === 2, "new OSD explicitly replaces the prior event")
        root.expect(osd.eventType === "brightness" && osd.value === 80 && osd.message === "80%", "replacement payload renders")
        root.expect(osd.panel.visible && osd.panel.screen === Quickshell.screens[0],
          "OSD falls back to the bridge-primary screen when the focused output cannot be resolved")
        root.expect(osd.panel.exclusiveZone === 0 && !osd.panel.focusable, "OSD is passive and reserves no workarea")
      })
    }
  }

  Timer {
    interval: 380
    running: true
    repeat: false
    onTriggered: {
      root.expect(!osd.opened && !osd.panel.visible, "bounded timer closes the replacement OSD")
      root.expiryObserved = !osd.opened
      root.expect(osd.showPayload({ type: "microphone", muted: true, duration: 0 }), "microphone payload accepted")
      root.expect(osd.duration >= 250 && osd.duration <= 5000, "duration is clamped to a bounded interval")
      root.expect(osd.iconKey === "microphone-muted", "muted microphone icon payload normalizes")
      Qt.callLater(root.finish)
    }
  }
}
