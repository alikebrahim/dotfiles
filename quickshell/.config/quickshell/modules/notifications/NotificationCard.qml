import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../style" as ShellStyle

Item {
  id: root

  required property string key
  property string appName: ""
  property string appIcon: ""
  property string summary: ""
  property string body: ""
  property string image: ""
  property int urgency: 1
  property double timestamp: 0
  property bool selected: false
  property bool actionable: false
  property bool compact: false
  property bool showClose: true

  readonly property bool hovered: cardHover.hovered
  readonly property string visualSource: {
    if (image) return image
    if (!appIcon) return ""
    if (appIcon === "dialog-information" || appIcon === "application-x-executable")
      return ""
    if (appIcon.indexOf("/") >= 0 || appIcon.indexOf("data:") === 0
        || appIcon.indexOf("file:") === 0) return appIcon
    return Quickshell.iconPath(appIcon, "dialog-information")
  }

  signal activated()
  signal dismissed()

  implicitHeight: compact ? ShellStyle.Metrics.notificationHistoryRowHeight
    : ShellStyle.Metrics.notificationToastHeight

  Rectangle {
    anchors.fill: parent
    radius: ShellStyle.Metrics.cornerRadius
    color: root.selected || cardHover.hovered
      ? ShellStyle.Palette.hoverWash
      : ShellStyle.Palette.panel
    border.width: 1
    border.color: root.urgency >= 2
      ? ShellStyle.Palette.urgent
      : (root.selected ? ShellStyle.Palette.panelBorder : ShellStyle.Palette.controlBorder)
  }

  Rectangle {
    anchors.left: parent.left
    anchors.top: parent.top
    anchors.bottom: parent.bottom
    width: root.urgency >= 2 ? 3 : 0
    radius: ShellStyle.Metrics.cornerRadius
    color: ShellStyle.Palette.urgent
    visible: width > 0
  }

  RowLayout {
    anchors.fill: parent
    anchors.margins: ShellStyle.Metrics.notificationCardPadding
    spacing: ShellStyle.Metrics.rowGap

    Rectangle {
      Layout.preferredWidth: ShellStyle.Metrics.notificationIconSize
      Layout.preferredHeight: ShellStyle.Metrics.notificationIconSize
      Layout.alignment: Qt.AlignTop
      radius: ShellStyle.Metrics.cornerRadius
      color: ShellStyle.Palette.normalWash
      border.width: 1
      border.color: ShellStyle.Palette.controlBorder
      clip: true

      Image {
        id: notificationImage
        anchors.fill: parent
        anchors.margins: 3
        source: root.visualSource
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        smooth: true
        visible: root.visualSource !== "" && status === Image.Ready
      }

      Text {
        anchors.centerIn: parent
        visible: root.visualSource === "" || notificationImage.status !== Image.Ready
        text: root.appName !== "" ? root.appName.charAt(0).toUpperCase() : "!"
        textFormat: Text.PlainText
        color: ShellStyle.Palette.foreground
        font.family: ShellStyle.Metrics.fontFamily
        font.pixelSize: ShellStyle.Metrics.displaySize
      }
    }

    ColumnLayout {
      Layout.fillWidth: true
      Layout.alignment: Qt.AlignTop
      spacing: 2

      RowLayout {
        Layout.fillWidth: true
        spacing: ShellStyle.Metrics.labelGap

        Text {
          Layout.fillWidth: true
          text: root.appName || "Notification"
          textFormat: Text.PlainText
          color: ShellStyle.Palette.muted
          font.family: ShellStyle.Metrics.fontFamily
          font.pixelSize: ShellStyle.Metrics.captionSize
          font.bold: true
          elide: Text.ElideRight
          maximumLineCount: 1
        }

        Text {
          visible: root.timestamp > 0
          text: root.timestamp > 0 ? Qt.formatTime(new Date(root.timestamp), "HH:mm") : ""
          textFormat: Text.PlainText
          color: ShellStyle.Palette.muted
          font.family: ShellStyle.Metrics.fontFamily
          font.pixelSize: ShellStyle.Metrics.captionSize
        }
      }

      Text {
        Layout.fillWidth: true
        text: root.summary || root.appName || "Notification"
        textFormat: Text.PlainText
        color: ShellStyle.Palette.foreground
        font.family: ShellStyle.Metrics.fontFamily
        font.pixelSize: ShellStyle.Metrics.bodySize
        font.bold: true
        wrapMode: Text.Wrap
        elide: Text.ElideRight
        maximumLineCount: root.compact ? 1 : 2
      }

      Text {
        Layout.fillWidth: true
        visible: text !== ""
        text: root.body
        textFormat: Text.PlainText
        color: ShellStyle.Palette.muted
        font.family: ShellStyle.Metrics.fontFamily
        font.pixelSize: ShellStyle.Metrics.bodySmallSize
        wrapMode: Text.Wrap
        elide: Text.ElideRight
        maximumLineCount: root.compact ? 2 : 3
      }

      Text {
        Layout.fillWidth: true
        visible: root.actionable && !root.compact
        text: "Click to open"
        textFormat: Text.PlainText
        color: ShellStyle.Palette.accent
        font.family: ShellStyle.Metrics.fontFamily
        font.pixelSize: ShellStyle.Metrics.captionSize
      }
    }

    Item {
      visible: root.showClose
      Layout.preferredWidth: 24
      Layout.preferredHeight: 24
      Layout.alignment: Qt.AlignTop

      Rectangle {
        anchors.fill: parent
        radius: ShellStyle.Metrics.cornerRadius
        color: closeHover.hovered ? ShellStyle.Palette.hoverWash : ShellStyle.Palette.transparent
      }

      Text {
        anchors.centerIn: parent
        text: "×"
        textFormat: Text.PlainText
        color: ShellStyle.Palette.foreground
        font.family: ShellStyle.Metrics.fontFamily
        font.pixelSize: ShellStyle.Metrics.headingSize
      }

      HoverHandler { id: closeHover }
      TapHandler {
        acceptedButtons: Qt.LeftButton
        onTapped: root.dismissed()
      }
    }
  }

  HoverHandler { id: cardHover }
  TapHandler {
    acceptedButtons: Qt.LeftButton
    onTapped: root.activated()
  }
}
