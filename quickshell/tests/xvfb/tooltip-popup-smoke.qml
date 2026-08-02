import QtQuick
import Quickshell
import ui as Ui

ShellRoot {
  id: root

  readonly property string resultPath: Quickshell.env("QUATTRO_QS_TEST_RESULT")
  property var failures: []

  function expect(condition, message) {
    if (!condition) failures.push(String(message))
  }

  function shellQuote(value) {
    return "'" + String(value).replace(/'/g, "'\\''") + "'"
  }

  PanelWindow {
    id: bar
    visible: Quickshell.screens.length > 0
    screen: Quickshell.screens.length > 0 ? Quickshell.screens[0] : null
    implicitWidth: 240
    implicitHeight: 26
    color: "#151515"
    focusable: false
    anchors { top: true; right: true }

    Item {
      id: statusIcon
      objectName: "tooltip-anchor"
      width: 27
      height: 26
      anchors.right: parent.right

      Ui.PopupToolTip {
        id: tooltip
        anchorItem: statusIcon
        text: "Brightness — 26%"
        shown: true
        delay: 0
      }
    }
  }

  Timer {
    interval: 250
    running: true
    repeat: false
    onTriggered: {
      root.expect(tooltip.popupVisible, "tooltip maps as an independent popup window")
      root.expect(tooltip.popupWindow !== null && tooltip.popupWindow.screen === bar.screen,
        "tooltip inherits the anchor window screen")
      root.expect(tooltip.popupWindow !== null && !tooltip.popupWindow.grabFocus,
        "passive tooltip never takes keyboard focus")
      root.expect(tooltip.popupWindow !== null && tooltip.popupWindow.implicitHeight > 0,
        "tooltip has content-sized geometry outside the bar surface")
      var payload = JSON.stringify({
        ok: failures.length === 0,
        failures: failures,
        popupVisible: tooltip.popupVisible,
        popupWidth: tooltip.popupWindow ? tooltip.popupWindow.implicitWidth : 0,
        popupHeight: tooltip.popupWindow ? tooltip.popupWindow.implicitHeight : 0,
        barHeight: bar.implicitHeight
      })
      Quickshell.execDetached(["bash", "-lc", "printf '%s' " + shellQuote(payload) + " > " + shellQuote(resultPath)])
      Qt.callLater(Qt.quit)
    }
  }
}
