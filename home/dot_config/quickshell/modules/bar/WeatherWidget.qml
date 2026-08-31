import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../ui" as Ui
import "../../style" as ShellStyle

Item {
  id: root

  property var screen: null
  property var weatherService: null
  property var popoutHost: null
  required property QtObject barPopoutController
  property bool editingLocation: false
  property string locationQuery: ""
  property int suggestionIndex: 0

  readonly property string surfaceName: "weather"
  readonly property bool popupOpen: weatherPopup.open
  readonly property alias panel: weatherPopup
  readonly property string barText: {
    if (!weatherService || !weatherService.configured) return "Set loc"
    if (!weatherService.hasCurrent) return "…"
    return weatherService.icon + " " + weatherService.temperature + "°"
  }
  readonly property int popupHeight: Math.min(
    ShellStyle.Metrics.weatherPopupMaxHeight,
    popupContent.implicitHeight + weatherPopup.padding * 2)

  implicitWidth: Math.max(44, weatherLabel.implicitWidth + 12)
  implicitHeight: ShellStyle.Metrics.barHeight
  visible: weatherService !== null
  Accessible.role: Accessible.Button
  Accessible.name: tooltipPopupText

  readonly property string tooltipPopupText: {
    if (!weatherService || !weatherService.configured)
      return "Weather · set an explicit location"
    if (!weatherService.hasCurrent)
      return weatherService.locationName + " · unavailable"
    return weatherService.locationName + " · "
      + weatherService.condition + " · "
      + weatherService.temperature + weatherService.temperatureUnit
  }

  function openPopup() {
    if (!visible || screen === null) return false
    barPopoutController.activate(surfaceName)
    weatherPopup.open = true
    if (weatherService) weatherService.setPanelOpen(true)
    editingLocation = weatherService && !weatherService.configured
    if (editingLocation) {
      locationQuery = ""
      suggestionIndex = 0
      Qt.callLater(function() { locationField.focusEditor() })
    }
    return true
  }

  function closePopup() {
    weatherPopup.open = false
    editingLocation = false
    if (weatherService) weatherService.setPanelOpen(false)
    barPopoutController.release(surfaceName)
    return true
  }

  function togglePopup() {
    return weatherPopup.open ? closePopup() : openPopup()
  }

  function focusKeyboardItem() {
    if (weatherPopup.open && !editingLocation)
      keyboardNavigator.forceActiveFocus(Qt.ShortcutFocusReason)
  }

  function requestKeyboardFocus() {
    if (!weatherPopup.open) return
    var windowObject = popoutHost && popoutHost.contentItem
      ? popoutHost.contentItem.Window.window
      : null
    if (!windowObject) return
    if (windowObject.active) {
      if (editingLocation) locationField.focusEditor()
      else focusKeyboardItem()
    } else windowObject.requestActivate()
  }

  function beginLocationEdit() {
    if (!weatherService) return false
    editingLocation = true
    locationQuery = weatherService.locationName
    suggestionIndex = 0
    Qt.callLater(function() { locationField.focusEditor() })
    return true
  }

  function cancelLocationEdit() {
    if (!weatherService || !weatherService.configured) {
      locationQuery = ""
      return false
    }
    editingLocation = false
    locationQuery = ""
    suggestionIndex = 0
    Qt.callLater(focusKeyboardItem)
    return true
  }

  function submitLocation() {
    if (!weatherService) return false
    if (weatherService.suggestions.length > 0
        && weatherService.geocodeQuery.toLowerCase() === locationQuery.trim().toLowerCase()) {
      if (weatherService.chooseSuggestion(suggestionIndex)) {
        editingLocation = false
        locationQuery = ""
        Qt.callLater(focusKeyboardItem)
        return true
      }
    }
    return weatherService.requestGeocode(locationQuery)
  }

  function moveSuggestion(delta) {
    var count = weatherService ? weatherService.suggestions.length : 0
    if (count <= 0) return false
    suggestionIndex = (suggestionIndex + (delta < 0 ? -1 : 1) + count) % count
    suggestionList.positionViewAtIndex(suggestionIndex, ListView.Contain)
    return true
  }

  onScreenChanged: if (popupOpen) closePopup()

  Rectangle {
    anchors.fill: parent
    radius: ShellStyle.Metrics.cornerRadius
    color: indicatorHover.hovered || weatherPopup.open
      ? ShellStyle.Palette.hoverWash : ShellStyle.Palette.transparent
  }

  Text {
    id: weatherLabel
    anchors.centerIn: parent
    text: root.barText
    textFormat: Text.PlainText
    color: root.weatherService && root.weatherService.stale
      ? ShellStyle.Palette.urgent : ShellStyle.Palette.foreground
    font.family: ShellStyle.Metrics.fontFamily
    font.pixelSize: ShellStyle.Metrics.bodySmallSize
    font.bold: true
  }

  HoverHandler { id: indicatorHover }
  TapHandler {
    acceptedButtons: Qt.LeftButton
    onTapped: root.togglePopup()
  }

  Ui.PopupToolTip {
    anchorItem: root
    text: root.tooltipPopupText
    shown: indicatorHover.hovered && !weatherPopup.open
    barPopoutController: root.barPopoutController
    delay: 500
  }

  Connections {
    target: root.popoutHost
    enabled: root.popoutHost !== null
    function onFocusRequested() {
      if (weatherPopup.open) root.requestKeyboardFocus()
    }
  }

  Connections {
    target: root.barPopoutController
    function onCloseRequested(popout) {
      if (popout !== root.surfaceName) return
      weatherPopup.open = false
      root.editingLocation = false
      if (root.weatherService) root.weatherService.setPanelOpen(false)
    }
  }

  Connections {
    target: root.weatherService
    function onSuggestionsChanged() { root.suggestionIndex = 0 }
    function onConfiguredChanged() {
      if (!root.weatherService) return
      if (root.weatherService.configured) root.editingLocation = false
      else if (weatherPopup.open) root.editingLocation = true
    }
  }

  Ui.PopupCard {
    id: weatherPopup
    host: root.popoutHost
    anchorItem: root
    placement: "center"
    animateTransitions: !root.barPopoutController.dismissImmediately
      && !root.barPopoutController.switching
    cardWidth: ShellStyle.Metrics.weatherPopupWidth
    cardHeight: root.popupHeight
    cardRadius: ShellStyle.Metrics.cornerRadius
    cardColor: ShellStyle.Palette.panel
    borderColor: ShellStyle.Palette.panelBorder

    onOpenChanged: {
      if (open) {
        root.barPopoutController.activate(root.surfaceName)
        if (root.weatherService) root.weatherService.setPanelOpen(true)
        if (root.weatherService && !root.weatherService.configured)
          root.editingLocation = true
      } else {
        root.editingLocation = false
        if (root.weatherService) root.weatherService.setPanelOpen(false)
        root.barPopoutController.release(root.surfaceName)
      }
    }

    Ui.KeyboardNavigator {
      id: keyboardNavigator
      anchors.fill: parent
      onCloseRequested: {
        if (root.editingLocation && root.weatherService && root.weatherService.configured)
          root.cancelLocationEdit()
        else root.closePopup()
      }
      onMoveRequested: function(dx, dy) {
        if (root.editingLocation && dy !== 0) root.moveSuggestion(dy)
      }
      onActivateRequested: {
        if (root.editingLocation) root.submitLocation()
        else if (root.weatherService) root.weatherService.refresh()
      }
      onTabRequested: function(direction) {
        if (root.editingLocation) root.moveSuggestion(direction)
      }
    }

    Shortcut {
      sequence: "Ctrl+R"
      enabled: weatherPopup.open && !root.editingLocation
      onActivated: if (root.weatherService) root.weatherService.refresh()
    }
    Shortcut {
      sequence: "Ctrl+E"
      enabled: weatherPopup.open && root.weatherService && root.weatherService.configured
      onActivated: root.beginLocationEdit()
    }
    Shortcut {
      sequence: "Ctrl+N"
      enabled: weatherPopup.open && root.editingLocation
      onActivated: root.moveSuggestion(1)
    }
    Shortcut {
      sequence: "Ctrl+P"
      enabled: weatherPopup.open && root.editingLocation
      onActivated: root.moveSuggestion(-1)
    }

    Column {
      id: popupContent
      width: parent.width
      spacing: ShellStyle.Metrics.panelGap

      Ui.PanelHero {
        width: parent.width
        iconText: {
          if (!root.weatherService || !root.weatherService.configured) return "○"
          return root.weatherService.hasCurrent ? root.weatherService.icon : "·"
        }
        title: root.weatherService && root.weatherService.configured
          ? root.weatherService.locationName : "Weather"
        subtitle: {
          if (!root.weatherService || !root.weatherService.configured)
            return "SET AN EXPLICIT LOCATION"
          if (root.weatherService.refreshing && !root.weatherService.hasCurrent)
            return "LOADING CURRENT CONDITIONS"
          var label = root.weatherService.condition
          if (root.weatherService.stale) label += " · STALE"
          return label
        }
        valueText: root.weatherService && root.weatherService.hasCurrent
          ? root.weatherService.temperature + "°" : ""
        dimIcon: root.weatherService
          && (!root.weatherService.configured || root.weatherService.stale)
      }

      Ui.PanelSeparator { width: parent.width }

      Column {
        id: locationEditor
        width: parent.width
        visible: root.editingLocation
          || !root.weatherService || !root.weatherService.configured
        spacing: ShellStyle.Metrics.panelGap

        Text {
          width: parent.width
          text: "Search Open-Meteo by city or postal code. No IP geolocation is used."
          textFormat: Text.PlainText
          color: ShellStyle.Palette.muted
          wrapMode: Text.WordWrap
          font.family: ShellStyle.Metrics.fontFamily
          font.pixelSize: ShellStyle.Metrics.bodySmallSize
        }

        RowLayout {
          width: parent.width
          spacing: ShellStyle.Metrics.panelGap

          Ui.PanelTextField {
            id: locationField
            Layout.fillWidth: true
            placeholderText: "City, region, or postal code"
            enabled: root.weatherService && !root.weatherService.geocoding
            text: root.locationQuery
            onTextChanged: if (text !== root.locationQuery) {
              root.locationQuery = text
              root.suggestionIndex = 0
            }
            onAccepted: root.submitLocation()
            onCancelled: root.cancelLocationEdit()
          }

          Ui.PanelButton {
            text: root.weatherService && root.weatherService.geocoding ? "…" : "SEARCH"
            enabled: root.weatherService && !root.weatherService.geocoding
              && root.locationQuery.trim().length >= 2
            onClicked: root.submitLocation()
          }
        }

        Text {
          visible: root.weatherService && (root.weatherService.geocodeError !== ""
            || root.weatherService.geocoding)
          width: parent.width
          text: root.weatherService
            ? (root.weatherService.geocoding
              ? "Searching locations…" : root.weatherService.geocodeError)
            : ""
          textFormat: Text.PlainText
          color: root.weatherService && root.weatherService.geocodeError !== ""
            ? ShellStyle.Palette.urgent : ShellStyle.Palette.muted
          font.family: ShellStyle.Metrics.fontFamily
          font.pixelSize: ShellStyle.Metrics.bodySmallSize
        }

        ListView {
          id: suggestionList
          visible: root.weatherService && root.weatherService.suggestions.length > 0
          width: parent.width
          height: visible
            ? Math.min(5, count) * ShellStyle.Metrics.weatherSuggestionHeight : 0
          model: root.weatherService ? root.weatherService.suggestions : []
          clip: true
          interactive: contentHeight > height

          delegate: Rectangle {
            required property var modelData
            required property int index
            width: suggestionList.width
            height: ShellStyle.Metrics.weatherSuggestionHeight
            radius: ShellStyle.Metrics.cornerRadius
            color: index === root.suggestionIndex
              ? ShellStyle.Palette.selectedWash
              : (suggestionPointer.hovered
                ? ShellStyle.Palette.hoverWash : ShellStyle.Palette.transparent)

            Column {
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.leftMargin: 10
              anchors.rightMargin: 10
              anchors.verticalCenter: parent.verticalCenter
              spacing: 1

              Text {
                width: parent.width
                text: modelData.name
                textFormat: Text.PlainText
                color: ShellStyle.Palette.foreground
                elide: Text.ElideRight
                font.family: ShellStyle.Metrics.fontFamily
                font.pixelSize: ShellStyle.Metrics.bodySize
                font.bold: true
              }
              Text {
                width: parent.width
                text: modelData.detail
                textFormat: Text.PlainText
                color: ShellStyle.Palette.muted
                elide: Text.ElideRight
                font.family: ShellStyle.Metrics.fontFamily
                font.pixelSize: ShellStyle.Metrics.captionSize
              }
            }

            HoverHandler { id: suggestionPointer }
            TapHandler {
              acceptedButtons: Qt.LeftButton
              onTapped: {
                root.suggestionIndex = index
                root.submitLocation()
              }
            }
          }
        }

        Ui.PanelButton {
          visible: root.weatherService && root.weatherService.configured
          text: "CANCEL"
          onClicked: root.cancelLocationEdit()
        }
      }

      Column {
        id: configuredWeather
        width: parent.width
        visible: root.weatherService
          && root.weatherService.configured && !root.editingLocation
        spacing: ShellStyle.Metrics.panelGap

        Row {
          width: parent.width
          height: ShellStyle.Metrics.weatherMetricHeight
          spacing: ShellStyle.Metrics.panelGap

          Repeater {
            model: [
              { label: "FEELS", value: root.weatherService && root.weatherService.hasCurrent ? root.weatherService.apparentTemperature + "°" : "—" },
              { label: "HUMIDITY", value: root.weatherService && root.weatherService.hasCurrent ? root.weatherService.humidity + "%" : "—" },
              { label: "WIND", value: root.weatherService && root.weatherService.hasCurrent ? root.weatherService.windSpeed + " km/h" : "—" }
            ]

            delegate: Rectangle {
              required property var modelData
              width: (configuredWeather.width - ShellStyle.Metrics.panelGap * 2) / 3
              height: ShellStyle.Metrics.weatherMetricHeight
              radius: ShellStyle.Metrics.cornerRadius
              color: ShellStyle.Palette.normalWash
              border.width: 1
              border.color: ShellStyle.Palette.controlBorder

              Column {
                anchors.centerIn: parent
                spacing: 2
                Text {
                  anchors.horizontalCenter: parent.horizontalCenter
                  text: modelData.value
                  textFormat: Text.PlainText
                  color: ShellStyle.Palette.foreground
                  font.family: ShellStyle.Metrics.fontFamily
                  font.pixelSize: ShellStyle.Metrics.titleSize
                  font.bold: true
                }
                Text {
                  anchors.horizontalCenter: parent.horizontalCenter
                  text: modelData.label
                  textFormat: Text.PlainText
                  color: ShellStyle.Palette.muted
                  font.family: ShellStyle.Metrics.fontFamily
                  font.pixelSize: ShellStyle.Metrics.captionSize
                  font.bold: true
                  font.letterSpacing: 1
                }
              }
            }
          }
        }

        Ui.PanelSectionHeader {
          width: parent.width
          text: root.weatherService && root.weatherService.forecastRefreshing
            ? "FORECAST · REFRESHING" : "FORECAST"
        }

        ListView {
          id: forecastList
          width: parent.width
          height: root.weatherService
            ? Math.min(5, root.weatherService.forecastDays.length)
              * ShellStyle.Metrics.weatherForecastRowHeight
            : 0
          model: root.weatherService ? root.weatherService.forecastDays : []
          interactive: false
          clip: true

          delegate: Item {
            required property var modelData
            required property int index
            width: forecastList.width
            height: ShellStyle.Metrics.weatherForecastRowHeight

            Rectangle {
              anchors.fill: parent
              radius: ShellStyle.Metrics.cornerRadius
              color: index === 0
                ? ShellStyle.Palette.normalWash : ShellStyle.Palette.transparent
            }

            Text {
              anchors.left: parent.left
              anchors.leftMargin: 10
              anchors.verticalCenter: parent.verticalCenter
              width: 72
              text: index === 0 ? "Today"
                : Qt.formatDate(new Date(modelData.date + "T12:00:00"), "ddd")
              textFormat: Text.PlainText
              color: ShellStyle.Palette.foreground
              font.family: ShellStyle.Metrics.fontFamily
              font.pixelSize: ShellStyle.Metrics.bodySize
              font.bold: true
            }
            Text {
              anchors.horizontalCenter: parent.horizontalCenter
              anchors.verticalCenter: parent.verticalCenter
              text: modelData.icon + "  " + modelData.condition
              textFormat: Text.PlainText
              color: ShellStyle.Palette.muted
              font.family: ShellStyle.Metrics.fontFamily
              font.pixelSize: ShellStyle.Metrics.bodySmallSize
            }
            Text {
              anchors.right: parent.right
              anchors.rightMargin: 10
              anchors.verticalCenter: parent.verticalCenter
              text: Math.round(modelData.high) + "°  "
                + Math.round(modelData.low) + "°"
              textFormat: Text.PlainText
              color: ShellStyle.Palette.foreground
              font.family: ShellStyle.Metrics.fontFamily
              font.pixelSize: ShellStyle.Metrics.bodySize
            }
          }
        }

        Text {
          visible: root.weatherService && !root.weatherService.hasForecast
          width: parent.width
          text: root.weatherService && root.weatherService.forecastRefreshing
            ? "Loading forecast…" : "Forecast unavailable"
          textFormat: Text.PlainText
          color: ShellStyle.Palette.muted
          horizontalAlignment: Text.AlignHCenter
          font.family: ShellStyle.Metrics.fontFamily
          font.pixelSize: ShellStyle.Metrics.bodySmallSize
        }

        RowLayout {
          width: parent.width
          spacing: ShellStyle.Metrics.panelGap

          Ui.PanelButton {
            Layout.fillWidth: true
            text: root.weatherService
              && (root.weatherService.refreshing
                || root.weatherService.forecastRefreshing)
              ? "REFRESHING" : "REFRESH"
            enabled: root.weatherService && !root.weatherService.refreshing
              && !root.weatherService.forecastRefreshing
            onClicked: root.weatherService.refresh()
          }
          Ui.PanelButton {
            Layout.fillWidth: true
            text: "CHANGE LOCATION"
            onClicked: root.beginLocationEdit()
          }
        }
      }

      Text {
        width: parent.width
        text: {
          if (!root.weatherService) return "WEATHER SERVICE UNAVAILABLE"
          if (root.weatherService.error !== "")
            return root.weatherService.error.toUpperCase()
          if (root.weatherService.configured
              && root.weatherService.locationDetail !== "")
            return root.weatherService.locationDetail.toUpperCase() + " · OPEN-METEO"
          return "OPEN-METEO · LOCATION DATA GEONAMES"
        }
        textFormat: Text.PlainText
        color: root.weatherService && root.weatherService.error !== ""
          ? ShellStyle.Palette.urgent : ShellStyle.Palette.muted
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
        font.family: ShellStyle.Metrics.fontFamily
        font.pixelSize: ShellStyle.Metrics.captionSize
        font.bold: true
        font.letterSpacing: 0.8
      }
    }
  }

  IpcHandler {
    target: "weather"

    function status(): string {
      return JSON.stringify({
        configured: root.weatherService ? root.weatherService.configured : false,
        location: root.weatherService ? root.weatherService.locationName : "",
        hasCurrent: root.weatherService ? root.weatherService.hasCurrent : false,
        hasForecast: root.weatherService ? root.weatherService.hasForecast : false,
        stale: root.weatherService ? root.weatherService.stale : false,
        refreshing: root.weatherService ? root.weatherService.refreshing : false,
        forecastRefreshing: root.weatherService
          ? root.weatherService.forecastRefreshing : false,
        condition: root.weatherService
          ? root.weatherService.condition : "Unavailable",
        temperature: root.weatherService && root.weatherService.hasCurrent
          ? root.weatherService.temperature : null,
        popupOpen: root.popupOpen
      })
    }

    function openPanel(): string {
      return root.openPopup() ? status() : "unavailable"
    }
    function closePanel(): string {
      root.closePopup()
      return status()
    }
    function refresh(): string {
      return root.weatherService && root.weatherService.refresh()
        ? "refreshing" : "unavailable"
    }
    function searchLocation(query: string): bool {
      if (!root.weatherService) return false
      root.locationQuery = query
      root.editingLocation = true
      return root.weatherService.requestGeocode(query)
    }
    function chooseLocation(index: int): bool {
      return root.weatherService
        ? root.weatherService.chooseSuggestion(index) : false
    }
    function clearLocation(): bool {
      return root.weatherService ? root.weatherService.clearLocation() : false
    }
  }
}
