import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../ui" as Ui
import "../../style" as ShellStyle
import "../notifications" as Notifications

Item {
  id: root

  property var screen: null
  property var notificationService: null
  property var dbusOwnershipService: null
  property var barPopoutController: null
  property var popoutHost: null
  property int selectedTab: 0
  property int selectedIndex: 0

  readonly property string surfaceName: "notification-history"
  readonly property bool popupOpen: historyPopup.open
  readonly property alias panel: historyPopup
  readonly property var activeRows: selectedTab === 0
    ? (notificationService ? notificationService.unseenRows : [])
    : (notificationService ? notificationService.seenRows : [])
  readonly property int unseenCount: notificationService
    ? notificationService.unseenCount
    : 0

  readonly property bool ownedByShell: dbusOwnershipService
    ? dbusOwnershipService.notificationsOwnedByShell
    : Boolean(notificationService && notificationService.serverReady)

  implicitWidth: visible ? 30 : 0
  implicitHeight: ShellStyle.Metrics.barHeight
  visible: notificationService !== null
  opacity: ownedByShell ? 1 : 0.48

  function ensureSelection() {
    if (activeRows.length === 0) selectedIndex = 0
    else selectedIndex = Math.max(0, Math.min(selectedIndex, activeRows.length - 1))
    if (historyList.visible && activeRows.length > 0)
      historyList.positionViewAtIndex(selectedIndex, ListView.Contain)
  }

  function switchTab(index) {
    selectedTab = Math.max(0, Math.min(1, index))
    selectedIndex = 0
    Qt.callLater(ensureSelection)
  }

  function moveSelection(delta) {
    if (activeRows.length === 0) return false
    selectedIndex = (selectedIndex + (delta < 0 ? -1 : 1) + activeRows.length)
      % activeRows.length
    historyList.positionViewAtIndex(selectedIndex, ListView.Contain)
    return true
  }

  function activateSelection() {
    if (!notificationService || activeRows.length === 0) return false
    var row = activeRows[selectedIndex]
    if (!row) return false
    if (notificationService.invokeDefault(row.key)) return true
    if (!row.seen) return notificationService.markSeenKey(row.key)
    return false
  }

  function focusKeyboardItem() {
    if (historyPopup.open) keyboardNavigator.forceActiveFocus(Qt.ShortcutFocusReason)
  }

  function requestKeyboardFocus() {
    if (!historyPopup.open) return
    var windowObject = popoutHost && popoutHost.contentItem
      ? popoutHost.contentItem.Window.window
      : null
    if (!windowObject) return
    if (windowObject.active) focusKeyboardItem()
    else windowObject.requestActivate()
  }

  function acknowledgeViewed() {
    if (!notificationService || selectedTab !== 0 || notificationService.unseenCount <= 0)
      return false
    return notificationService.markAllSeen()
  }

  function openPopup() {
    if (!visible || screen === null) return false
    if (barPopoutController) barPopoutController.activate(surfaceName)
    historyPopup.open = true
    ensureSelection()
    return true
  }

  function closePopup() {
    if (historyPopup.open) acknowledgeViewed()
    historyPopup.open = false
    if (barPopoutController) barPopoutController.release(surfaceName)
    return true
  }

  function togglePopup() {
    return historyPopup.open ? closePopup() : openPopup()
  }

  onVisibleChanged: if (!visible && historyPopup.open) closePopup()
  onScreenChanged: if (historyPopup.open) closePopup()
  onActiveRowsChanged: if (historyPopup.open) Qt.callLater(ensureSelection)

  Rectangle {
    anchors.fill: parent
    radius: ShellStyle.Metrics.cornerRadius
    color: indicatorHover.hovered || historyPopup.open
      ? ShellStyle.Palette.hoverWash
      : ShellStyle.Palette.transparent
  }

  Text {
    anchors.centerIn: parent
    text: root.notificationService && root.notificationService.doNotDisturb
      ? "󰂛"
      : "󰂚"
    textFormat: Text.PlainText
    color: root.unseenCount > 0
      ? ShellStyle.Palette.foreground
      : ShellStyle.Palette.muted
    font.family: ShellStyle.Metrics.fontFamily
    font.pixelSize: ShellStyle.Metrics.titleSize
  }

  Rectangle {
    visible: root.unseenCount > 0
    anchors.top: parent.top
    anchors.right: parent.right
    anchors.topMargin: 1
    anchors.rightMargin: 1
    width: Math.max(12, countLabel.implicitWidth + 4)
    height: 12
    radius: 6
    color: ShellStyle.Palette.urgent

    Text {
      id: countLabel
      anchors.centerIn: parent
      text: root.unseenCount > 99 ? "99+" : String(root.unseenCount)
      textFormat: Text.PlainText
      color: ShellStyle.Palette.foreground
      font.family: ShellStyle.Metrics.fontFamily
      font.pixelSize: 8
      font.bold: true
    }
  }

  HoverHandler { id: indicatorHover }
  TapHandler {
    acceptedButtons: Qt.LeftButton
    onTapped: root.togglePopup()
  }

  Ui.PopupToolTip {
    anchorItem: root
    text: !root.ownedByShell
      ? "Notifications not owned by this shell"
      : (root.notificationService && root.notificationService.doNotDisturb
        ? "Notifications silenced"
        : (root.unseenCount > 0 ? root.unseenCount + " new notifications" : "Notifications"))
    shown: indicatorHover.hovered && !historyPopup.open
    barPopoutController: root.barPopoutController
    delay: 500
  }

  Connections {
    target: root.popoutHost
    enabled: root.popoutHost !== null
    function onFocusRequested() {
      if (historyPopup.open) root.focusKeyboardItem()
    }
  }

  Connections {
    target: root.barPopoutController
    enabled: root.barPopoutController !== null

    function onCloseRequested(popout) {
      if (popout !== root.surfaceName) return
      if (historyPopup.open) root.acknowledgeViewed()
      historyPopup.open = false
    }
  }

  Ui.PopupCard {
    id: historyPopup
    host: root.popoutHost
    anchorItem: root
    placement: "anchor"
    animateTransitions: !root.barPopoutController
      || (!root.barPopoutController.dismissImmediately
        && !root.barPopoutController.switching)
    cardWidth: ShellStyle.Metrics.notificationHistoryWidth
    cardHeight: ShellStyle.Metrics.notificationHistoryHeight
    cardRadius: ShellStyle.Metrics.cornerRadius
    cardColor: ShellStyle.Palette.panel
    borderColor: ShellStyle.Palette.panelBorder

    onOpenChanged: {
      if (open) {
        if (root.barPopoutController) root.barPopoutController.activate(root.surfaceName)
        root.ensureSelection()
      } else {
        if (root.selectedTab === 0) root.acknowledgeViewed()
        if (root.barPopoutController) root.barPopoutController.release(root.surfaceName)
      }
    }

    Ui.KeyboardNavigator {
      id: keyboardNavigator
      anchors.fill: parent
      onCloseRequested: root.closePopup()
      onMoveRequested: function(dx, dy) {
        if (dy !== 0) root.moveSelection(dy)
        else if (dx !== 0) root.switchTab(root.selectedTab + (dx < 0 ? -1 : 1))
      }
      onActivateRequested: root.activateSelection()
      onTabRequested: function(direction) {
        root.switchTab((root.selectedTab + direction + 2) % 2)
      }
      onTextKey: function(text) {
        var key = String(text || "").toLowerCase()
        if (!root.notificationService) return
        if (key === "s") root.notificationService.toggleDoNotDisturb()
        else if (key === "m") root.notificationService.markAllSeen()
      }
    }

    Item {
      anchors.fill: parent

      ColumnLayout {
        anchors.fill: parent
        spacing: ShellStyle.Metrics.panelGap

        Ui.PanelHero {
          Layout.fillWidth: true
          iconText: root.notificationService && root.notificationService.doNotDisturb
            ? "󰂛"
            : "󰂚"
          title: "Notifications"
          subtitle: root.notificationService && root.notificationService.doNotDisturb
            ? "Do not disturb"
            : "History"
          valueText: String(root.unseenCount)
          dimIcon: root.unseenCount === 0
        }

        RowLayout {
          Layout.fillWidth: true
          spacing: ShellStyle.Metrics.rowGap

          Ui.PanelButton {
            Layout.fillWidth: true
            text: root.notificationService && root.notificationService.doNotDisturb
              ? "Allow"
              : "Silence"
            iconText: "󰂛"
            current: root.notificationService
              ? root.notificationService.doNotDisturb
              : false
            onClicked: if (root.notificationService)
              root.notificationService.toggleDoNotDisturb()
          }

          Ui.PanelButton {
            Layout.fillWidth: true
            text: "Mark seen"
            enabled: root.unseenCount > 0
            onClicked: if (root.notificationService)
              root.notificationService.markAllSeen()
          }

          Ui.PanelButton {
            Layout.fillWidth: true
            text: "Clear"
            enabled: root.notificationService
              ? root.notificationService.historyCount > 0
              : false
            onClicked: if (root.notificationService)
              root.notificationService.clearHistory()
          }
        }

        Ui.PanelSeparator { Layout.fillWidth: true }

        RowLayout {
          Layout.fillWidth: true
          spacing: ShellStyle.Metrics.rowGap

          Ui.PanelButton {
            Layout.fillWidth: true
            text: "New " + String(root.unseenCount)
            current: root.selectedTab === 0
            onClicked: root.switchTab(0)
          }

          Ui.PanelButton {
            Layout.fillWidth: true
            text: "Past " + String(root.notificationService
              ? root.notificationService.seenRows.length
              : 0)
            current: root.selectedTab === 1
            onClicked: root.switchTab(1)
          }
        }

        ListView {
          id: historyList
          Layout.fillWidth: true
          Layout.fillHeight: true
          clip: true
          spacing: ShellStyle.Metrics.notificationHistoryGap
          boundsBehavior: Flickable.StopAtBounds
          model: root.activeRows
          currentIndex: root.selectedIndex

          delegate: Notifications.NotificationCard {
            required property var modelData
            required property int index

            width: ListView.view.width
            key: String(modelData.key || "")
            appName: String(modelData.appName || "")
            appIcon: String(modelData.appIcon || "")
            summary: String(modelData.summary || "")
            body: String(modelData.body || "")
            image: String(modelData.image || "")
            urgency: Number(modelData.urgency || 0)
            timestamp: Number(modelData.timestamp || 0)
            selected: index === root.selectedIndex
            actionable: {
              if (!root.notificationService) return false
              root.notificationService.liveActionRevision
              return root.notificationService.canInvokeDefault(key)
            }
            compact: true
            showClose: true
            onActivated: {
              root.selectedIndex = index
              root.activateSelection()
            }
            onDismissed: if (root.notificationService)
              root.notificationService.removeHistoryKey(key)
          }

          Text {
            anchors.centerIn: parent
            visible: root.activeRows.length === 0
            text: root.selectedTab === 0 ? "No new notifications" : "No notification history"
            textFormat: Text.PlainText
            color: ShellStyle.Palette.muted
            font.family: ShellStyle.Metrics.fontFamily
            font.pixelSize: ShellStyle.Metrics.bodySmallSize
          }
        }

        Text {
          Layout.fillWidth: true
          visible: text !== ""
          text: root.notificationService ? root.notificationService.lastError : ""
          textFormat: Text.PlainText
          color: ShellStyle.Palette.urgent
          font.family: ShellStyle.Metrics.fontFamily
          font.pixelSize: ShellStyle.Metrics.captionSize
          wrapMode: Text.Wrap
          maximumLineCount: 2
          elide: Text.ElideRight
        }
      }
    }
  }

  IpcHandler {
    target: "notifications"

    function status(): string {
      return JSON.stringify({
        loaded: root.notificationService ? root.notificationService.serverReady : false,
        ownership: root.dbusOwnershipService
          ? root.dbusOwnershipService.notificationsState
          : "unknown",
        ownerPid: root.dbusOwnershipService
          ? root.dbusOwnershipService.notificationsOwnerPid
          : 0,
        ownedByShell: root.dbusOwnershipService
          ? root.dbusOwnershipService.notificationsOwnedByShell
          : false,
        dnd: root.notificationService ? root.notificationService.doNotDisturb : false,
        popupCount: root.notificationService ? root.notificationService.popupCount : 0,
        historyCount: root.notificationService ? root.notificationService.historyCount : 0,
        unseenCount: root.unseenCount,
        historyOpen: root.popupOpen,
        latestSummary: root.notificationService && root.notificationService.popupCount > 0
          ? String(root.notificationService.popupModel.get(0).summary || "")
          : "",
        lastError: root.notificationService ? root.notificationService.lastError : ""
      })
    }

    function openPanel(): string {
      return root.openPopup() ? status() : "unavailable"
    }

    function closePanel(): string {
      root.closePopup()
      return status()
    }

    function setDnd(value: bool): string {
      if (root.notificationService) root.notificationService.setDoNotDisturb(value)
      return status()
    }

    function markSeen(): string {
      if (root.notificationService) root.notificationService.markAllSeen()
      return status()
    }

    function clearHistory(): string {
      if (root.notificationService) root.notificationService.clearHistory()
      return status()
    }

    function invokeLatest(): string {
      if (root.notificationService && root.notificationService.popupCount > 0)
        root.notificationService.invokeDefault(root.notificationService.popupModel.get(0).key)
      return status()
    }

    function dismissLatest(): string {
      if (root.notificationService && root.notificationService.popupCount > 0)
        root.notificationService.dismissPopup(root.notificationService.popupModel.get(0).key)
      return status()
    }
  }
}
