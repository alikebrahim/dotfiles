import QtQuick
import Quickshell
import "../../style" as ShellStyle

PanelWindow {
  id: root

  property var notificationService: null
  property var targetScreen: null
  property bool suppressed: false
  property int admissionDelayMs: 60
  property int finalUnmapDelayMs: ShellStyle.Metrics.animationMs
  property bool presentationVisible: false
  property real reservedHeight: 1
  readonly property bool hostReady: notificationService !== null
    && notificationService.serverReady
    && targetScreen !== null

  screen: targetScreen
  visible: hostReady && !suppressed && presentationVisible
  implicitWidth: ShellStyle.Metrics.notificationToastWidth
  implicitHeight: Math.max(1, reservedHeight)
  color: ShellStyle.Palette.transparent
  surfaceFormat.opaque: false
  focusable: false
  aboveWindows: true
  exclusionMode: ExclusionMode.Ignore
  exclusiveZone: 0
  anchors.top: true
  anchors.right: true
  margins.top: ShellStyle.Metrics.barHeight + ShellStyle.Metrics.edgeInset
  margins.right: ShellStyle.Metrics.edgeInset
  mask: Region { item: toastColumn }

  function hasPresentablePopups() {
    return hostReady && !suppressed && notificationService.popupCount > 0
  }

  function currentToastHeight() {
    return Math.max(1, Math.ceil(toastColumn.implicitHeight))
  }

  function presentSettled() {
    if (!hasPresentablePopups()) return
    reservedHeight = Math.max(reservedHeight, currentToastHeight())
    presentationVisible = true
  }

  function synchronizePresentation() {
    if (!hostReady || suppressed) {
      admissionTimer.stop()
      finalUnmapTimer.stop()
      presentationVisible = false
      reservedHeight = 1
      return
    }

    if (notificationService.popupCount > 0) {
      finalUnmapTimer.stop()
      if (presentationVisible)
        reservedHeight = Math.max(reservedHeight, currentToastHeight())
      else
        admissionTimer.restart()
      return
    }

    admissionTimer.stop()
    if (presentationVisible)
      finalUnmapTimer.restart()
    else
      reservedHeight = 1
  }

  onNotificationServiceChanged: synchronizePresentation()
  onTargetScreenChanged: synchronizePresentation()
  onSuppressedChanged: synchronizePresentation()
  Component.onCompleted: synchronizePresentation()

  Connections {
    target: root.notificationService
    function onPopupCountChanged() { root.synchronizePresentation() }
    function onServerReadyChanged() { root.synchronizePresentation() }
  }

  Timer {
    id: admissionTimer
    interval: root.admissionDelayMs
    repeat: false
    onTriggered: root.presentSettled()
  }

  Timer {
    id: finalUnmapTimer
    interval: root.finalUnmapDelayMs
    repeat: false
    onTriggered: {
      if (root.hasPresentablePopups()) {
        root.synchronizePresentation()
        return
      }
      root.presentationVisible = false
      root.reservedHeight = 1
    }
  }

  Binding {
    target: root.contentItem ? root.contentItem.Window.window : null
    property: "title"
    value: "quickshell-notification-toasts"
    when: target !== null
  }

  Column {
    id: toastColumn
    width: root.width
    spacing: ShellStyle.Metrics.notificationToastGap
    onImplicitHeightChanged: root.synchronizePresentation()

    Repeater {
      model: root.notificationService ? root.notificationService.popupModel : null

      delegate: Item {
        id: toastDelegate

        required property string key
        required property int nativeId
        required property string appName
        required property string appIcon
        required property string summary
        required property string body
        required property string image
        required property int urgency
        required property bool isTransient
        required property bool resident
        required property real expireTimeout
        required property double timestamp
        required property bool seen
        required property bool hasDefaultAction
        required property int revision

        property real remainingMs: 0
        property double lastTickAt: 0
        readonly property real configuredTimeout: root.notificationService
          ? root.notificationService.toastTimeout({
              urgency: urgency,
              expireTimeout: expireTimeout
            })
          : 0

        width: toastColumn.width
        height: notificationCard.implicitHeight

        function resetLifetime() {
          remainingMs = configuredTimeout
          lastTickAt = Date.now()
        }

        onRevisionChanged: resetLifetime()
        Component.onCompleted: resetLifetime()

        NotificationCard {
          id: notificationCard
          anchors.fill: parent
          key: toastDelegate.key
          appName: toastDelegate.appName
          appIcon: toastDelegate.appIcon
          summary: toastDelegate.summary
          body: toastDelegate.body
          image: toastDelegate.image
          urgency: toastDelegate.urgency
          timestamp: toastDelegate.timestamp
          actionable: root.notificationService
            ? root.notificationService.canInvokeDefault(toastDelegate.key)
            : false
          compact: false
          showClose: true
          onHoveredChanged: if (!hovered) toastDelegate.lastTickAt = Date.now()
          onActivated: {
            if (!root.notificationService) return
            if (!root.notificationService.invokeDefault(toastDelegate.key))
              root.notificationService.dismissPopup(toastDelegate.key)
          }
          onDismissed: {
            if (root.notificationService)
              root.notificationService.dismissPopup(toastDelegate.key)
          }
        }

        Timer {
          interval: 100
          repeat: true
          running: toastDelegate.configuredTimeout > 0
            && toastDelegate.remainingMs > 0
            && !notificationCard.hovered
          onRunningChanged: if (running) toastDelegate.lastTickAt = Date.now()
          onTriggered: {
            var now = Date.now()
            var elapsed = Math.max(0, now - toastDelegate.lastTickAt)
            toastDelegate.lastTickAt = now
            toastDelegate.remainingMs = Math.max(0, toastDelegate.remainingMs - elapsed)
            if (toastDelegate.remainingMs <= 0 && root.notificationService)
              root.notificationService.expirePopup(toastDelegate.key)
          }
        }
      }
    }
  }
}
