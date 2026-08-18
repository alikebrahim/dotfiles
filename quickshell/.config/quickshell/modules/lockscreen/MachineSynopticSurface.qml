import QtQuick
import Quickshell
import "." as Instrument

PanelWindow {
  id: root

  property bool open: false
  property bool lockMode: false
  property string lockWindowTag: ""
  property string lockState: "closed"
  property string role: "auxiliary"
  property bool routingDegraded: false
  property var telemetry: ({})
  property var history: []
  property string clockText: "--:--:--"
  property string durationText: "T+00:00"
  property string telemetryHealth: "acquiring"
  property bool capsLockActive: false
  property bool inputRejected: false
  property int rejectionSequence: 0
  property real cpuRotorPhase: 0
  property real gpuRotorPhase: 0

  signal closeRequested()

  visible: open
  color: Instrument.InstrumentPalette.background
  aboveWindows: true
  exclusionMode: ExclusionMode.Ignore
  exclusiveZone: 0
  focusable: open && role === "primary" && !lockMode
  surfaceFormat.opaque: true

  anchors {
    left: true
    right: true
    top: true
    bottom: true
  }

  function focusKeyboardCapture() {
    if (open && role === "primary" && !lockMode)
      keyboardCapture.forceActiveFocus(Qt.ShortcutFocusReason)
  }

  function requestKeyboardFocus() {
    if (!open || role !== "primary" || lockMode) return
    var windowObject = root.contentItem ? root.contentItem.Window.window : null
    if (!windowObject) return
    if (windowObject.active) focusKeyboardCapture()
    else windowObject.requestActivate()
  }

  onVisibleChanged: if (visible && role === "primary" && !lockMode) focusRetry.restart()
  onRoleChanged: if (open && role === "primary" && !lockMode) focusRetry.restart()

  Binding {
    target: root.contentItem ? root.contentItem.Window.window : null
    property: "title"
    value: "quickshell-machine-synoptic-" + root.role
      + (root.lockMode ? "-" + root.lockWindowTag : "")
    when: target !== null
    restoreMode: Binding.RestoreBindingOrValue
  }

  Timer {
    id: focusRetry
    interval: 80
    repeat: false
    onTriggered: root.requestKeyboardFocus()
  }

  Connections {
    id: activation
    target: root.contentItem ? root.contentItem.Window.window : null

    function onActiveChanged() {
      var windowObject = activation.target
      if (!root.open || root.role !== "primary" || root.lockMode || !windowObject) return
      if (windowObject.active) Qt.callLater(root.focusKeyboardCapture)
    }
  }

  FocusScope {
    id: keyboardCapture
    anchors.fill: parent
    focus: root.open && root.role === "primary" && !root.lockMode

    Keys.priority: Keys.BeforeItem
    Keys.onPressed: function(event) {
      if (!root.lockMode && event.key === Qt.Key_Escape) {
        root.closeRequested()
        event.accepted = true
      }
    }

    Loader {
      anchors.fill: parent
      sourceComponent: root.role === "primary" ? primaryComponent : auxiliaryComponent
    }

    Rectangle {
      visible: root.routingDegraded
      anchors {
        right: parent.right
        rightMargin: 34
        top: parent.top
        topMargin: 52
      }
      width: degradedLabel.implicitWidth + 24
      height: 28
      color: Instrument.InstrumentPalette.background
      border.width: 1
      border.color: Instrument.InstrumentPalette.warning

      Text {
        id: degradedLabel
        anchors.centerIn: parent
        text: "OUTPUT ROUTING DEGRADED"
        color: Instrument.InstrumentPalette.warning
        font {
          family: Instrument.InstrumentPalette.monoFamily
          pixelSize: 11
          letterSpacing: 1.2
        }
      }
    }
  }

  Component {
    id: primaryComponent

    Instrument.MachineSynopticPrimaryView {
      telemetry: root.telemetry
      history: root.history
      clockText: root.clockText
      durationText: root.durationText
      telemetryHealth: root.telemetryHealth
      lockMode: root.lockMode
      lockState: root.lockState
      capsLockActive: root.capsLockActive
      inputRejected: root.inputRejected
      rejectionSequence: root.rejectionSequence
      cpuRotorPhase: root.cpuRotorPhase
      gpuRotorPhase: root.gpuRotorPhase
    }
  }

  Component {
    id: auxiliaryComponent

    Instrument.MachineSynopticAuxView {
      telemetry: root.telemetry
      history: root.history
      clockText: root.clockText
      durationText: root.durationText
      telemetryHealth: root.telemetryHealth
      cpuRotorPhase: root.cpuRotorPhase
      gpuRotorPhase: root.gpuRotorPhase
    }
  }
}
