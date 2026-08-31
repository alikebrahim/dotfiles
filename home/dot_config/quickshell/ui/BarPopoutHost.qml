import QtQuick
import Quickshell
import "../style" as ShellStyle

// Shared popout overlay. Placement follows the documented PanelWindow model:
// top+left+right anchors (not bottom — opposite anchors force screen height)
// and margins.top to sit below the bar. ExclusionMode.Ignore so we do not
// reserve more workarea. Cards are items in this window; their y is 0.
PanelWindow {
  id: root

  required property var barPopoutController
  property var targetScreen: null
  property Item activeCard: null
  property Item maskItem: null
  property bool holdUntilHidden: false
  property alias cardLayer: cardLayerItem

  readonly property int topGap: ShellStyle.Metrics.barHeight + ShellStyle.Metrics.edgeInset
  readonly property bool popoutOpen: barPopoutController
    && barPopoutController.activePopout !== ""
  readonly property bool switching: barPopoutController
    && barPopoutController.switching
  readonly property bool dismissImmediately: barPopoutController
    && barPopoutController.dismissImmediately

  signal focusRequested()

  screen: targetScreen
  visible: targetScreen !== null && maskItem !== null && (popoutOpen || holdUntilHidden)
  color: "transparent"
  surfaceFormat.opaque: false
  focusable: popoutOpen
  aboveWindows: true
  exclusionMode: ExclusionMode.Ignore
  mask: Region { item: root.maskItem }
  implicitHeight: targetScreen
    ? Math.max(1, targetScreen.height - topGap)
    : ShellStyle.Metrics.popupHostHeight

  anchors {
    top: true
    left: true
    right: true
  }
  margins.top: topGap

  function setActiveCard(card) {
    activeCard = card || null
    maskItem = card && card.cardBackground ? card.cardBackground : null
  }

  function windowObject() {
    return contentItem ? contentItem.Window.window : null
  }

  Binding {
    target: root.contentItem.Window.window
    property: "title"
    value: "quickshell-bar-popout"
    when: root.contentItem.Window.window !== null
  }

  Item {
    id: cardLayerItem
    anchors.fill: parent
  }

  onVisibleChanged: if (visible && popoutOpen) focusRetry.begin()

  WindowFocusRetry {
    id: focusRetry
    panel: root
    onSucceeded: {
      // Sibling switches keep the overlay mapped and focused, so no
      // activeChanged transition fires. Arm the focus flag here so a later
      // click-away still closes (otherwise activePopoutFocused stays false
      // and focus loss is ignored).
      var controller = root.barPopoutController
      if (controller && controller.activePopout !== "")
        controller.reportWindowActive(controller.activePopout, true)
      root.focusRequested()
    }
  }

  Connections {
    target: root.barPopoutController

    function onActivePopoutChanged() {
      if (root.popoutOpen) {
        root.holdUntilHidden = true
        hideTimer.stop()
        focusRetry.begin()
        return
      }

      focusRetry.stop()
      if (root.dismissImmediately) {
        hideTimer.stop()
        root.holdUntilHidden = false
        root.setActiveCard(null)
        return
      }

      hideTimer.restart()
    }
  }

  Connections {
    id: hostActivation
    target: root.contentItem ? root.contentItem.Window.window : null

    function onActiveChanged() {
      var windowObject = hostActivation.target
      if (!root.popoutOpen || !windowObject || !root.barPopoutController) return
      root.barPopoutController.reportWindowActive(
        root.barPopoutController.activePopout,
        windowObject.active
      )
      if (windowObject.active) Qt.callLater(root.focusRequested)
    }
  }

  Timer {
    id: hideTimer
    interval: ShellStyle.Metrics.animationMs
    repeat: false
    onTriggered: {
      if (root.popoutOpen) return
      root.holdUntilHidden = false
      root.setActiveCard(null)
    }
  }
}
