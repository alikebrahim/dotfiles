import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../ui" as Ui
import "../../style" as ShellStyle

Item {
  id: root

  property var screen: null
  property var tailscaleService: null
  property var clipboardService: null
  property var popoutHost: null
  required property QtObject barPopoutController
  property int selectedIndex: 0
  property string copiedPeerKey: ""

  readonly property string surfaceName: "tailscale"
  readonly property var peerRows: tailscaleService ? tailscaleService.peers : []
  readonly property var exitRows: tailscaleService ? tailscaleService.exitNodes : []
  readonly property int peerCount: peerRows.length
  readonly property int exitCount: exitRows.length
  readonly property int selectionCount: 1 + peerCount + exitCount
  readonly property int visiblePeerRows: Math.min(exitCount > 0 ? 3 : 6, peerCount)
  readonly property int visibleExitRows: Math.min(3, exitCount)
  readonly property bool popupOpen: tailscalePopup.open
  readonly property alias panel: tailscalePopup
  readonly property string connectionLabel: !tailscaleService ? "Unavailable"
    : (tailscaleService.needsLogin ? "Needs login"
      : (tailscaleService.connected ? "Connected" : tailscaleService.backendState))
  readonly property int popupHeight: popupContent.implicitHeight + tailscalePopup.padding * 2

  implicitWidth: visible ? 28 : 0
  implicitHeight: ShellStyle.Metrics.barHeight
  visible: Boolean(tailscaleService && tailscaleService.installed)

  function selectionAvailable(index) {
    if (!tailscaleService || index < 0 || index >= selectionCount) return false
    if (index === 0) return tailscaleService.actionsEnabled
      && !tailscaleService.busy && !tailscaleService.needsLogin
    if (index <= peerCount) {
      var peer = peerRows[index - 1]
      return peer && Boolean(peer.ipv4 || peer.dnsName || peer.name)
    }
    return tailscaleService.actionsEnabled && tailscaleService.connected
  }

  function ensureSelection() {
    if (selectionAvailable(selectedIndex)) {
      positionSelection()
      return
    }
    for (var i = 0; i < selectionCount; i++) {
      if (selectionAvailable(i)) {
        selectedIndex = i
        positionSelection()
        return
      }
    }
    selectedIndex = 0
  }

  function positionSelection() {
    if (selectedIndex > 0 && selectedIndex <= peerCount && peerList.visible)
      peerList.positionViewAtIndex(selectedIndex - 1, ListView.Contain)
    else if (selectedIndex > peerCount && exitList.visible)
      exitList.positionViewAtIndex(selectedIndex - peerCount - 1, ListView.Contain)
  }

  function moveSelection(delta) {
    if (selectionCount <= 0) return false
    var direction = delta < 0 ? -1 : 1
    var candidate = selectedIndex
    for (var step = 0; step < selectionCount; step++) {
      candidate = (candidate + direction + selectionCount) % selectionCount
      if (selectionAvailable(candidate)) {
        selectedIndex = candidate
        positionSelection()
        return true
      }
    }
    return false
  }

  function copyPeer(peer) {
    if (!peer || !clipboardService) return false
    var value = String(peer.ipv4 || peer.dnsName || peer.name || "")
    if (!value) return false
    var accepted = clipboardService.copyText(value, peer.name + " address")
    if (accepted) {
      copiedPeerKey = peer.key
      copiedFeedback.restart()
    }
    return accepted
  }

  function activateIndex(index) {
    if (!selectionAvailable(index) || !tailscaleService) return false
    selectedIndex = index
    if (index === 0) return tailscaleService.toggleConnection()
    if (index <= peerCount) return copyPeer(peerRows[index - 1])
    return tailscaleService.setExitNode(exitRows[index - peerCount - 1].key)
  }

  function openPopup() {
    if (!visible || screen === null) return false
    barPopoutController.activate(surfaceName)
    tailscalePopup.open = true
    tailscaleService.setPanelOpen(true)
    ensureSelection()
    return true
  }

  function closePopup() {
    tailscalePopup.open = false
    if (tailscaleService) tailscaleService.setPanelOpen(false)
    barPopoutController.release(surfaceName)
    return true
  }

  function togglePopup() {
    return tailscalePopup.open ? closePopup() : openPopup()
  }

  function focusKeyboardItem() {
    if (tailscalePopup.open) keyboardNavigator.forceActiveFocus(Qt.ShortcutFocusReason)
  }

  function requestKeyboardFocus() {
    if (!tailscalePopup.open) return
    var windowObject = popoutHost && popoutHost.contentItem
      ? popoutHost.contentItem.Window.window
      : null
    if (!windowObject) return
    if (windowObject.active) focusKeyboardItem()
    else windowObject.requestActivate()
  }

  onVisibleChanged: if (!visible && popupOpen) closePopup()
  onScreenChanged: if (popupOpen) closePopup()

  Connections {
    target: root.tailscaleService
    function onPeersChanged() { if (tailscalePopup.open) Qt.callLater(root.ensureSelection) }
    function onExitNodesChanged() { if (tailscalePopup.open) Qt.callLater(root.ensureSelection) }
  }

  Rectangle {
    anchors.fill: parent
    radius: ShellStyle.Metrics.cornerRadius
    color: indicatorHover.hovered
      ? ShellStyle.Palette.hoverWash : ShellStyle.Palette.transparent
  }

  TailscaleIcon {
    anchors.centerIn: parent
    iconSize: 15
    iconColor: root.tailscaleService && root.tailscaleService.connected
      ? ShellStyle.Palette.foreground : ShellStyle.Palette.muted
    crossed: root.tailscaleService && !root.tailscaleService.connected
    warning: root.tailscaleService
      && (root.tailscaleService.stale || root.tailscaleService.needsLogin
        || root.tailscaleService.error !== "")
  }

  HoverHandler { id: indicatorHover }
  TapHandler {
    acceptedButtons: Qt.LeftButton
    onTapped: root.togglePopup()
  }

  Ui.PopupToolTip {
    anchorItem: root
    text: "Tailscale · " + root.connectionLabel
    shown: indicatorHover.hovered && !tailscalePopup.open
    barPopoutController: root.barPopoutController
    delay: 500
  }

  Timer {
    id: copiedFeedback
    interval: 1800
    repeat: false
    onTriggered: root.copiedPeerKey = ""
  }

  Connections {
    target: root.popoutHost
    enabled: root.popoutHost !== null
    function onFocusRequested() {
      if (tailscalePopup.open) root.focusKeyboardItem()
    }
  }

  Connections {
    target: root.barPopoutController
    function onCloseRequested(popout) {
      if (popout !== root.surfaceName) return
      tailscalePopup.open = false
      if (root.tailscaleService) root.tailscaleService.setPanelOpen(false)
    }
  }

  Ui.PopupCard {
    id: tailscalePopup
    host: root.popoutHost
    anchorItem: root
    placement: "anchor"
    animateTransitions: !root.barPopoutController.dismissImmediately
      && !root.barPopoutController.switching
    cardWidth: ShellStyle.Metrics.tailscalePopupWidth
    cardHeight: root.popupHeight
    cardRadius: ShellStyle.Metrics.cornerRadius
    cardColor: ShellStyle.Palette.panel
    borderColor: ShellStyle.Palette.panelBorder

    onOpenChanged: {
      if (open) {
        root.barPopoutController.activate(root.surfaceName)
        if (root.tailscaleService) root.tailscaleService.setPanelOpen(true)
        root.ensureSelection()
      } else {
        if (root.tailscaleService) root.tailscaleService.setPanelOpen(false)
        root.barPopoutController.release(root.surfaceName)
      }
    }

    Ui.KeyboardNavigator {
      id: keyboardNavigator
      anchors.fill: parent
      onCloseRequested: root.closePopup()
      onMoveRequested: function(dx, dy) { if (dy !== 0) root.moveSelection(dy) }
      onActivateRequested: root.activateIndex(root.selectedIndex)
      onTabRequested: function(direction) { root.moveSelection(direction) }
    }

    Column {
      id: popupContent
      width: parent.width
      spacing: ShellStyle.Metrics.panelGap

      Row {
        width: parent.width
        height: 54
        spacing: ShellStyle.Metrics.panelGap

        Rectangle {
          width: 54
          height: 54
          radius: ShellStyle.Metrics.cornerRadius
          color: ShellStyle.Palette.normalWash
          border.width: 1
          border.color: ShellStyle.Palette.controlBorder

          TailscaleIcon {
            anchors.centerIn: parent
            iconSize: 30
            iconColor: root.tailscaleService && root.tailscaleService.connected
              ? ShellStyle.Palette.foreground : ShellStyle.Palette.muted
            crossed: root.tailscaleService && !root.tailscaleService.connected
            warning: root.tailscaleService
              && (root.tailscaleService.stale || root.tailscaleService.needsLogin)
          }
        }

        Column {
          width: parent.width - 54 - toggleButton.width - parent.spacing * 2
          anchors.verticalCenter: parent.verticalCenter
          spacing: 3

          Text {
            width: parent.width
            text: "Tailscale"
            textFormat: Text.PlainText
            color: ShellStyle.Palette.foreground
            font.family: ShellStyle.Metrics.fontFamily
            font.pixelSize: ShellStyle.Metrics.titleSize
            font.bold: true
          }

          Text {
            width: parent.width
            text: root.connectionLabel
              + (root.tailscaleService && root.tailscaleService.stale ? " · stale" : "")
            textFormat: Text.PlainText
            color: root.tailscaleService && root.tailscaleService.connected
              ? ShellStyle.Palette.foreground : ShellStyle.Palette.muted
            font.family: ShellStyle.Metrics.fontFamily
            font.pixelSize: ShellStyle.Metrics.bodySmallSize
            elide: Text.ElideRight
          }
        }

        Rectangle {
          id: toggleButton
          width: 72
          height: ShellStyle.Metrics.controlHeight
          anchors.verticalCenter: parent.verticalCenter
          radius: ShellStyle.Metrics.cornerRadius
          color: root.selectedIndex === 0 || toggleHover.hovered
            ? ShellStyle.Palette.hoverWash : ShellStyle.Palette.normalWash
          border.width: 1
          border.color: root.selectedIndex === 0
            ? ShellStyle.Palette.panelBorder : ShellStyle.Palette.controlBorder
          opacity: root.selectionAvailable(0) ? 1 : 0.45

          Text {
            anchors.centerIn: parent
            text: root.tailscaleService && root.tailscaleService.connected ? "TURN OFF" : "TURN ON"
            textFormat: Text.PlainText
            color: ShellStyle.Palette.foreground
            font.family: ShellStyle.Metrics.fontFamily
            font.pixelSize: ShellStyle.Metrics.captionSize
            font.bold: true
          }

          HoverHandler { id: toggleHover }
          TapHandler {
            acceptedButtons: Qt.LeftButton
            enabled: root.selectionAvailable(0)
            onTapped: root.activateIndex(0)
          }
        }
      }

      Ui.PanelSeparator { width: parent.width }

      Rectangle {
        width: parent.width
        height: 58
        radius: ShellStyle.Metrics.cornerRadius
        color: ShellStyle.Palette.normalWash
        border.width: 1
        border.color: ShellStyle.Palette.controlBorder

        Column {
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.margins: 10
          anchors.verticalCenter: parent.verticalCenter
          spacing: 3

          Text {
            width: parent.width
            text: root.tailscaleService ? root.tailscaleService.selfName : "Unknown device"
            textFormat: Text.PlainText
            color: ShellStyle.Palette.foreground
            font.family: ShellStyle.Metrics.fontFamily
            font.pixelSize: ShellStyle.Metrics.bodySize
            font.bold: true
            elide: Text.ElideRight
          }

          Text {
            width: parent.width
            text: {
              if (!root.tailscaleService) return ""
              var parts = []
              if (root.tailscaleService.selfIpv4) parts.push(root.tailscaleService.selfIpv4)
              if (root.tailscaleService.tailnetName) parts.push(root.tailscaleService.tailnetName)
              parts.push(root.tailscaleService.currentExitNodeName
                ? "exit: " + root.tailscaleService.currentExitNodeName : "direct")
              return parts.join("  ·  ")
            }
            textFormat: Text.PlainText
            color: ShellStyle.Palette.muted
            font.family: ShellStyle.Metrics.fontFamily
            font.pixelSize: ShellStyle.Metrics.captionSize
            elide: Text.ElideRight
          }
        }
      }

      Column {
        width: parent.width
        spacing: ShellStyle.Metrics.labelGap
        visible: root.peerCount > 0

        Ui.PanelSectionHeader {
          label: "Peers · " + (root.tailscaleService ? root.tailscaleService.onlinePeerCount : 0)
            + " online"
        }

        ListView {
          id: peerList
          width: parent.width
          height: root.visiblePeerRows * ShellStyle.Metrics.tailscalePeerRowHeight
          clip: true
          model: root.peerRows
          currentIndex: Math.max(0, root.selectedIndex - 1)
          boundsBehavior: Flickable.StopAtBounds

          delegate: Item {
            id: peerRow
            required property var modelData
            required property int index
            readonly property bool hasCursor: root.selectedIndex === index + 1
            width: ListView.view.width
            height: ShellStyle.Metrics.tailscalePeerRowHeight

            Rectangle {
              anchors.fill: parent
              radius: ShellStyle.Metrics.cornerRadius
              color: peerRow.hasCursor || peerHover.hovered
                ? ShellStyle.Palette.hoverWash : ShellStyle.Palette.transparent
            }

            Rectangle {
              anchors.left: parent.left
              anchors.leftMargin: 8
              anchors.verticalCenter: parent.verticalCenter
              width: 7
              height: width
              radius: width / 2
              color: peerRow.modelData.online
                ? ShellStyle.Palette.foreground : ShellStyle.Palette.muted
              opacity: peerRow.modelData.online ? 1 : 0.5
            }

            Column {
              anchors.left: parent.left
              anchors.leftMargin: 26
              anchors.right: copyLabel.left
              anchors.rightMargin: 8
              anchors.verticalCenter: parent.verticalCenter
              spacing: 1

              Text {
                width: parent.width
                text: peerRow.modelData.name
                textFormat: Text.PlainText
                color: ShellStyle.Palette.foreground
                font.family: ShellStyle.Metrics.fontFamily
                font.pixelSize: ShellStyle.Metrics.bodySmallSize
                font.bold: peerRow.modelData.online
                elide: Text.ElideRight
              }

              Text {
                width: parent.width
                text: [peerRow.modelData.ipv4, peerRow.modelData.os]
                  .filter(function(value) { return Boolean(value) }).join(" · ")
                textFormat: Text.PlainText
                color: ShellStyle.Palette.muted
                font.family: ShellStyle.Metrics.fontFamily
                font.pixelSize: ShellStyle.Metrics.captionSize
                elide: Text.ElideRight
              }
            }

            Text {
              id: copyLabel
              anchors.right: parent.right
              anchors.rightMargin: 8
              anchors.verticalCenter: parent.verticalCenter
              text: root.copiedPeerKey === peerRow.modelData.key ? "COPIED" : "COPY"
              textFormat: Text.PlainText
              color: root.copiedPeerKey === peerRow.modelData.key
                ? ShellStyle.Palette.foreground : ShellStyle.Palette.muted
              font.family: ShellStyle.Metrics.fontFamily
              font.pixelSize: ShellStyle.Metrics.captionSize
            }

            HoverHandler { id: peerHover }
            TapHandler {
              acceptedButtons: Qt.LeftButton
              onTapped: root.activateIndex(peerRow.index + 1)
            }
          }
        }
      }

      Column {
        width: parent.width
        spacing: ShellStyle.Metrics.labelGap
        visible: root.exitCount > 0

        Ui.PanelSectionHeader { label: "Exit node" }

        ListView {
          id: exitList
          width: parent.width
          height: root.visibleExitRows * ShellStyle.Metrics.tailscalePeerRowHeight
          clip: true
          model: root.exitRows
          currentIndex: Math.max(0, root.selectedIndex - root.peerCount - 1)
          boundsBehavior: Flickable.StopAtBounds

          delegate: Item {
            id: exitRow
            required property var modelData
            required property int index
            readonly property int selectionIndex: root.peerCount + index + 1
            readonly property bool hasCursor: root.selectedIndex === selectionIndex
            readonly property bool current: root.tailscaleService
              && root.tailscaleService.currentExitNodeKey === modelData.key
            width: ListView.view.width
            height: ShellStyle.Metrics.tailscalePeerRowHeight

            Rectangle {
              anchors.fill: parent
              radius: ShellStyle.Metrics.cornerRadius
              color: exitRow.current ? ShellStyle.Palette.selectedWash
                : (exitRow.hasCursor || exitHover.hovered
                  ? ShellStyle.Palette.hoverWash : ShellStyle.Palette.transparent)
            }

            Text {
              anchors.left: parent.left
              anchors.leftMargin: 10
              anchors.right: exitState.left
              anchors.rightMargin: 8
              anchors.verticalCenter: parent.verticalCenter
              text: exitRow.modelData.name
              textFormat: Text.PlainText
              color: ShellStyle.Palette.foreground
              font.family: ShellStyle.Metrics.fontFamily
              font.pixelSize: ShellStyle.Metrics.bodySmallSize
              elide: Text.ElideRight
            }

            Text {
              id: exitState
              anchors.right: parent.right
              anchors.rightMargin: 10
              anchors.verticalCenter: parent.verticalCenter
              text: exitRow.current ? "ACTIVE" : "USE"
              textFormat: Text.PlainText
              color: exitRow.current ? ShellStyle.Palette.foreground : ShellStyle.Palette.muted
              font.family: ShellStyle.Metrics.fontFamily
              font.pixelSize: ShellStyle.Metrics.captionSize
            }

            HoverHandler { id: exitHover }
            TapHandler {
              acceptedButtons: Qt.LeftButton
              enabled: root.selectionAvailable(exitRow.selectionIndex)
              onTapped: root.activateIndex(exitRow.selectionIndex)
            }
          }
        }
      }

      Text {
        width: parent.width
        visible: text !== ""
        text: root.tailscaleService
          ? (root.tailscaleService.actionMessage || root.tailscaleService.error) : ""
        textFormat: Text.PlainText
        color: root.tailscaleService && root.tailscaleService.error
          ? ShellStyle.Palette.urgent : ShellStyle.Palette.muted
        font.family: ShellStyle.Metrics.fontFamily
        font.pixelSize: ShellStyle.Metrics.captionSize
        wrapMode: Text.Wrap
      }

      Text {
        width: parent.width
        text: root.tailscaleService && root.tailscaleService.actionsEnabled
          ? "ENTER ACTS · PEER ROWS COPY ADDRESS"
          : "CONTROLS LOCKED · PEER ROWS COPY ADDRESS"
        textFormat: Text.PlainText
        color: ShellStyle.Palette.muted
        font.family: ShellStyle.Metrics.fontFamily
        font.pixelSize: ShellStyle.Metrics.captionSize
        horizontalAlignment: Text.AlignHCenter
      }
    }
  }

  IpcHandler {
    target: "tailscale"

    function status(): string {
      return JSON.stringify({
        installed: root.tailscaleService ? root.tailscaleService.installed : false,
        connected: root.tailscaleService ? root.tailscaleService.connected : false,
        needsLogin: root.tailscaleService ? root.tailscaleService.needsLogin : false,
        stale: root.tailscaleService ? root.tailscaleService.stale : false,
        backendState: root.tailscaleService ? root.tailscaleService.backendState : "Unavailable",
        tailnetName: root.tailscaleService ? root.tailscaleService.tailnetName : "",
        selfName: root.tailscaleService ? root.tailscaleService.selfName : "",
        selfIpv4: root.tailscaleService ? root.tailscaleService.selfIpv4 : "",
        peerCount: root.peerCount,
        onlinePeerCount: root.tailscaleService ? root.tailscaleService.onlinePeerCount : 0,
        exitNodeCount: root.exitCount,
        currentExitNode: root.tailscaleService ? root.tailscaleService.currentExitNodeName : "",
        pendingAction: root.tailscaleService ? root.tailscaleService.pendingAction : "",
        actionsEnabled: root.tailscaleService ? root.tailscaleService.actionsEnabled : false,
        popupOpen: root.popupOpen
      })
    }

    function refresh(): string {
      return root.tailscaleService && root.tailscaleService.refresh() ? "refreshing" : "unavailable"
    }

    function openPanel(): string {
      return root.openPopup() ? status() : "unavailable"
    }

    function closePanel(): string {
      root.closePopup()
      return status()
    }
  }
}
