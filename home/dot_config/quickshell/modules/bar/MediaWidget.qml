import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../ui" as Ui
import "../../style" as ShellStyle

Item {
  id: root

  property var screen: null
  property var mediaService: null
  required property QtObject barPopoutController
  property int selectedIndex: 1

  readonly property string surfaceName: "media"
  readonly property var activePlayer: mediaService ? mediaService.activePlayer : null
  readonly property var sourcePlayers: mediaService ? mediaService.sourcePlayers : []
  readonly property int sourceCount: sourcePlayers.length
  readonly property int sourceSelectionCount: sourceCount > 1 ? sourceCount : 0
  readonly property int selectionCount: 3 + sourceSelectionCount
  readonly property string displayLabel: mediaService ? mediaService.barLabel : ""
  readonly property bool popupOpen: mediaPopup.open
  readonly property int visibleSourceRows: Math.min(
    ShellStyle.Metrics.mediaSourceMaxRows,
    sourceCount
  )
  readonly property int popupHeight: popupContent.implicitHeight
    + mediaPopup.padding * 2
  readonly property real labelWidth: mediaLabel.width
  readonly property alias panel: mediaPopup

  implicitWidth: visible ? indicatorRow.implicitWidth + 12 : 0
  implicitHeight: ShellStyle.Metrics.barHeight
  visible: Boolean(mediaService && mediaService.available)

  function controlAvailable(index) {
    if (!mediaService || !activePlayer) return false
    var key = mediaService.activePlayerKey
    if (index === 0) return mediaService.actionAvailable("previous", key)
    if (index === 1) return mediaService.actionAvailable("playPause", key)
    if (index === 2) return mediaService.actionAvailable("next", key)
    return false
  }

  function selectionAvailable(index) {
    if (index < 0 || index >= selectionCount) return false
    if (index < 3) return controlAvailable(index)
    return sourceCount > 1 && index - 3 < sourceCount
  }

  function ensureSelection() {
    if (selectionAvailable(selectedIndex)) {
      positionSelectedSource()
      return
    }
    for (var i = 0; i < selectionCount; i++) {
      if (selectionAvailable(i)) {
        selectedIndex = i
        positionSelectedSource()
        return
      }
    }
    selectedIndex = 0
  }

  function positionSelectedSource() {
    if (selectedIndex >= 3 && sourceList.visible)
      sourceList.positionViewAtIndex(selectedIndex - 3, ListView.Contain)
  }

  function moveSelection(delta) {
    if (selectionCount <= 0) return false
    var direction = delta < 0 ? -1 : 1
    var candidate = selectedIndex
    for (var step = 0; step < selectionCount; step++) {
      candidate = (candidate + direction + selectionCount) % selectionCount
      if (selectionAvailable(candidate)) {
        selectedIndex = candidate
        positionSelectedSource()
        return true
      }
    }
    return false
  }

  function moveTransport(delta) {
    if (selectedIndex >= 3) return false
    var direction = delta < 0 ? -1 : 1
    var candidate = selectedIndex
    for (var step = 0; step < 3; step++) {
      candidate = (candidate + direction + 3) % 3
      if (controlAvailable(candidate)) {
        selectedIndex = candidate
        return true
      }
    }
    return false
  }

  function activateIndex(index) {
    if (!selectionAvailable(index) || !mediaService) return false
    selectedIndex = index
    if (index === 0) return mediaService.runAction("previous", mediaService.activePlayerKey)
    if (index === 1) return mediaService.runAction("playPause", mediaService.activePlayerKey)
    if (index === 2) return mediaService.runAction("next", mediaService.activePlayerKey)
    return mediaService.selectPlayer(mediaService.playerKey(sourcePlayers[index - 3]))
  }

  function activateSelection() {
    return activateIndex(selectedIndex)
  }

  function focusKeyboardItem() {
    if (mediaPopup.open) keyboardNavigator.forceActiveFocus(Qt.ShortcutFocusReason)
  }

  function requestKeyboardFocus() {
    if (!mediaPopup.open) return
    var windowObject = mediaPopup.contentItem ? mediaPopup.contentItem.Window.window : null
    if (!windowObject) return
    if (windowObject.active) focusKeyboardItem()
    else windowObject.requestActivate()
  }

  function openPopup() {
    if (!visible || screen === null) return false
    barPopoutController.activate(surfaceName)
    mediaPopup.open = true
    ensureSelection()
    focusRetry.restart()
    return true
  }

  function closePopup() {
    mediaPopup.open = false
    focusRetry.stop()
    barPopoutController.release(surfaceName)
    return true
  }

  function togglePopup() {
    return mediaPopup.open ? closePopup() : openPopup()
  }

  onVisibleChanged: if (!visible && mediaPopup.open) closePopup()
  onScreenChanged: if (mediaPopup.open) closePopup()

  Connections {
    target: root.mediaService

    function onSourcePlayersChanged() {
      if (mediaPopup.open) Qt.callLater(root.ensureSelection)
    }
  }

  Rectangle {
    anchors.fill: parent
    radius: ShellStyle.Metrics.cornerRadius
    color: indicatorHover.hovered
      ? ShellStyle.Palette.hoverWash
      : ShellStyle.Palette.transparent
  }

  Row {
    id: indicatorRow
    anchors.centerIn: parent
    spacing: ShellStyle.Metrics.labelGap

    Text {
      anchors.verticalCenter: parent.verticalCenter
      text: root.activePlayer && root.activePlayer.isPlaying ? "󰏤" : "󰐊"
      textFormat: Text.PlainText
      color: root.activePlayer && root.activePlayer.isPlaying
        ? ShellStyle.Palette.foreground
        : ShellStyle.Palette.muted
      font.family: ShellStyle.Metrics.fontFamily
      font.pixelSize: ShellStyle.Metrics.bodySize
    }

    Text {
      id: mediaLabel
      anchors.verticalCenter: parent.verticalCenter
      width: Math.min(implicitWidth, ShellStyle.Metrics.mediaLabelMaxWidth)
      text: root.displayLabel
      textFormat: Text.PlainText
      color: ShellStyle.Palette.foreground
      font.family: ShellStyle.Metrics.fontFamily
      font.pixelSize: ShellStyle.Metrics.bodySize
      font.weight: Font.Medium
      elide: Text.ElideRight
      maximumLineCount: 1
    }
  }

  HoverHandler { id: indicatorHover }

  TapHandler {
    acceptedButtons: Qt.LeftButton
    onTapped: root.togglePopup()
  }

  Ui.PopupToolTip {
    anchorItem: root
    text: root.displayLabel
    shown: indicatorHover.hovered && !mediaPopup.open
    delay: 500
  }

  Timer {
    id: focusRetry
    interval: 80
    repeat: false
    onTriggered: root.requestKeyboardFocus()
  }

  Connections {
    id: mediaActivation
    target: mediaPopup.contentItem ? mediaPopup.contentItem.Window.window : null

    function onActiveChanged() {
      var windowObject = mediaActivation.target
      if (!mediaPopup.open || !windowObject) return
      root.barPopoutController.reportWindowActive(root.surfaceName, windowObject.active)
      if (windowObject.active) Qt.callLater(root.focusKeyboardItem)
    }
  }

  Connections {
    target: root.barPopoutController

    function onCloseRequested(popout) {
      if (popout !== root.surfaceName) return
      mediaPopup.open = false
      focusRetry.stop()
    }
  }

  Ui.PopupCard {
    id: mediaPopup
    screen: root.screen
    animateTransitions: !root.barPopoutController
      || !root.barPopoutController.dismissImmediately
    cardWidth: ShellStyle.Metrics.mediaPopupWidth
    cardHeight: root.popupHeight
    cardRadius: ShellStyle.Metrics.cornerRadius
    cardColor: ShellStyle.Palette.panel
    borderColor: ShellStyle.Palette.panelBorder

    margins {
      top: ShellStyle.Metrics.barHeight + 8
      right: ShellStyle.Metrics.edgeInset
    }

    onOpenChanged: {
      if (open) {
        root.barPopoutController.activate(root.surfaceName)
        root.ensureSelection()
        focusRetry.restart()
      } else {
        focusRetry.stop()
        root.barPopoutController.release(root.surfaceName)
      }
    }

    Ui.KeyboardNavigator {
      id: keyboardNavigator
      anchors.fill: parent
      onCloseRequested: root.closePopup()
      onMoveRequested: function(dx, dy) {
        if (dy !== 0) root.moveSelection(dy)
        else if (dx !== 0) root.moveTransport(dx)
      }
      onActivateRequested: root.activateSelection()
      onTabRequested: function(direction) { root.moveSelection(direction) }
    }

    Column {
      id: popupContent
      width: parent.width
      spacing: ShellStyle.Metrics.panelGap

      Row {
        width: parent.width
        height: ShellStyle.Metrics.mediaArtworkSize
        spacing: ShellStyle.Metrics.panelGap

        Rectangle {
          id: artworkFrame
          width: ShellStyle.Metrics.mediaArtworkSize
          height: width
          radius: ShellStyle.Metrics.cornerRadius
          color: ShellStyle.Palette.normalWash
          border.width: 1
          border.color: ShellStyle.Palette.controlBorder
          clip: true

          Image {
            id: artwork
            anchors.fill: parent
            anchors.margins: 2
            source: mediaPopup.open && root.mediaService
              ? root.mediaService.artUrl
              : ""
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            smooth: true
            visible: source !== "" && status !== Image.Error
          }

          Text {
            anchors.centerIn: parent
            visible: !artwork.visible
            text: "󰝚"
            textFormat: Text.PlainText
            color: ShellStyle.Palette.foreground
            font.family: ShellStyle.Metrics.fontFamily
            font.pixelSize: ShellStyle.Metrics.displayLargeSize
          }
        }

        Column {
          width: parent.width - artworkFrame.width - parent.spacing
          anchors.verticalCenter: parent.verticalCenter
          spacing: 3

          Text {
            width: parent.width
            text: root.mediaService ? (root.mediaService.title || root.mediaService.identity || "Media") : "Media"
            textFormat: Text.PlainText
            color: ShellStyle.Palette.foreground
            font.family: ShellStyle.Metrics.fontFamily
            font.pixelSize: ShellStyle.Metrics.titleSize
            font.bold: true
            elide: Text.ElideRight
            maximumLineCount: 1
          }

          Text {
            width: parent.width
            visible: text !== ""
            text: root.mediaService ? root.mediaService.artist : ""
            textFormat: Text.PlainText
            color: ShellStyle.Palette.muted
            font.family: ShellStyle.Metrics.fontFamily
            font.pixelSize: ShellStyle.Metrics.bodySmallSize
            elide: Text.ElideRight
            maximumLineCount: 1
          }

          Text {
            width: parent.width
            visible: text !== ""
            text: root.mediaService ? root.mediaService.album : ""
            textFormat: Text.PlainText
            color: ShellStyle.Palette.muted
            font.family: ShellStyle.Metrics.fontFamily
            font.pixelSize: ShellStyle.Metrics.captionSize
            elide: Text.ElideRight
            maximumLineCount: 1
          }
        }
      }

      Row {
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: ShellStyle.Metrics.rowGap

        Ui.OmarchyButton {
          width: 48
          iconText: "󰒮"
          enabled: root.controlAvailable(0)
          hasCursor: root.selectedIndex === 0
          onClicked: root.activateIndex(0)
        }

        Ui.OmarchyButton {
          width: 56
          iconText: root.activePlayer && root.activePlayer.isPlaying ? "󰏤" : "󰐊"
          enabled: root.controlAvailable(1)
          hasCursor: root.selectedIndex === 1
          onClicked: root.activateIndex(1)
        }

        Ui.OmarchyButton {
          width: 48
          iconText: "󰒭"
          enabled: root.controlAvailable(2)
          hasCursor: root.selectedIndex === 2
          onClicked: root.activateIndex(2)
        }
      }

      Ui.PanelSeparator {
        width: parent.width
        visible: root.sourceCount > 1
      }

      Column {
        width: parent.width
        spacing: ShellStyle.Metrics.labelGap
        visible: root.sourceCount > 1

        Ui.PanelSectionHeader { label: "Players" }

        ListView {
          id: sourceList
          width: parent.width
          height: root.visibleSourceRows * ShellStyle.Metrics.mediaSourceRowHeight
          clip: true
          model: root.sourcePlayers
          currentIndex: Math.max(0, root.selectedIndex - 3)
          boundsBehavior: Flickable.StopAtBounds

          delegate: Item {
            id: sourceRow
            required property var modelData
            required property int index

            readonly property bool current: root.mediaService
              && root.mediaService.activePlayerKey === root.mediaService.playerKey(modelData)
            readonly property bool hasCursor: root.selectedIndex === index + 3

            width: ListView.view.width
            height: ShellStyle.Metrics.mediaSourceRowHeight

            Rectangle {
              anchors.fill: parent
              radius: ShellStyle.Metrics.cornerRadius
              color: sourceRow.current
                ? ShellStyle.Palette.selectedWash
                : (sourceHover.hovered || sourceRow.hasCursor
                  ? ShellStyle.Palette.hoverWash
                  : ShellStyle.Palette.transparent)
            }

            Text {
              id: sourceGlyph
              anchors.left: parent.left
              anchors.leftMargin: 8
              anchors.verticalCenter: parent.verticalCenter
              width: 20
              horizontalAlignment: Text.AlignHCenter
              text: sourceRow.modelData && sourceRow.modelData.isPlaying ? "󰏤" : "󰐊"
              textFormat: Text.PlainText
              color: ShellStyle.Palette.foreground
              font.family: ShellStyle.Metrics.fontFamily
              font.pixelSize: ShellStyle.Metrics.bodySize
            }

            Column {
              anchors.left: sourceGlyph.right
              anchors.leftMargin: ShellStyle.Metrics.rowGap
              anchors.right: parent.right
              anchors.rightMargin: 8
              anchors.verticalCenter: parent.verticalCenter
              spacing: 1

              Text {
                width: parent.width
                text: root.mediaService ? root.mediaService.playerLabel(sourceRow.modelData) : "Media"
                textFormat: Text.PlainText
                color: ShellStyle.Palette.foreground
                font.family: ShellStyle.Metrics.fontFamily
                font.pixelSize: ShellStyle.Metrics.bodySmallSize
                font.bold: sourceRow.current
                elide: Text.ElideRight
                maximumLineCount: 1
              }

              Text {
                width: parent.width
                text: root.mediaService ? root.mediaService.playerDetail(sourceRow.modelData) : ""
                textFormat: Text.PlainText
                color: ShellStyle.Palette.muted
                font.family: ShellStyle.Metrics.fontFamily
                font.pixelSize: ShellStyle.Metrics.captionSize
                elide: Text.ElideRight
                maximumLineCount: 1
              }
            }

            HoverHandler { id: sourceHover }
            TapHandler {
              acceptedButtons: Qt.LeftButton
              onTapped: root.activateIndex(sourceRow.index + 3)
            }
          }
        }
      }

      Text {
        width: parent.width
        visible: text !== ""
        text: root.mediaService ? root.mediaService.lastError : ""
        textFormat: Text.PlainText
        color: ShellStyle.Palette.urgent
        font.family: ShellStyle.Metrics.fontFamily
        font.pixelSize: ShellStyle.Metrics.captionSize
        wrapMode: Text.Wrap
      }
    }
  }

  IpcHandler {
    target: "media"

    function status(): string {
      return JSON.stringify({
        ready: root.mediaService ? root.mediaService.backendReady : false,
        available: root.visible,
        playerCount: root.sourceCount,
        activePlayerKey: root.mediaService ? root.mediaService.activePlayerKey : "",
        title: root.mediaService ? root.mediaService.title : "",
        artist: root.mediaService ? root.mediaService.artist : "",
        playing: root.mediaService ? root.mediaService.playing : false,
        popupOpen: root.popupOpen,
        labelWidth: root.labelWidth
      })
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
