import QtQuick
import Quickshell
import services as Services
import modules.bar as Bar

ShellRoot {
  id: root

  readonly property string resultPath: Quickshell.env("QUICKSHELL_QS_TEST_RESULT")
  readonly property bool holdOpen: Quickshell.env("QUICKSHELL_WEATHER_TEST_HOLD") === "1"
  readonly property string statePath: Quickshell.env("XDG_RUNTIME_DIR")
    + "/weather-fixture/weather-v1.json"
  property var failures: []
  property int stage: 0
  property real preservedTemperature: 0

  function geocodeJson() {
    return JSON.stringify({ results: [
      {
        id: 1,
        name: "Fixture City",
        latitude: 12.34,
        longitude: 56.78,
        elevation: 42,
        timezone: "Etc/Fixture",
        country: "Exampleland",
        admin1: "Test Region"
      },
      {
        id: 2,
        name: "Fixture Bay",
        latitude: -22.5,
        longitude: 130.25,
        elevation: 4,
        timezone: "Etc/Fixture2",
        country: "Exampleland",
        admin1: "Second Region"
      }
    ]})
  }

  function currentJson(temperature, code, isDay) {
    return JSON.stringify({
      latitude: 12.34,
      longitude: 56.78,
      current_units: {
        time: "iso8601",
        temperature_2m: "°C",
        apparent_temperature: "°C",
        relative_humidity_2m: "%",
        precipitation: "mm",
        weather_code: "wmo code",
        wind_speed_10m: "km/h",
        is_day: ""
      },
      current: {
        time: "2026-07-28T22:00",
        temperature_2m: temperature,
        apparent_temperature: temperature - 1.8,
        relative_humidity_2m: 64,
        precipitation: 0.2,
        weather_code: code,
        wind_speed_10m: 13.4,
        is_day: isDay
      }
    })
  }

  function forecastJson(offset) {
    return JSON.stringify({
      daily_units: {
        time: "iso8601",
        weather_code: "wmo code",
        temperature_2m_max: "°C",
        temperature_2m_min: "°C",
        precipitation_probability_max: "%",
        sunrise: "iso8601",
        sunset: "iso8601"
      },
      daily: {
        time: ["2026-07-28", "2026-07-29", "2026-07-30", "2026-07-31", "2026-08-01"],
        weather_code: [1, 2, 61, 3, 0],
        temperature_2m_max: [27 + offset, 26 + offset, 23 + offset, 24 + offset, 29 + offset],
        temperature_2m_min: [18 + offset, 17 + offset, 16 + offset, 15 + offset, 19 + offset],
        precipitation_probability_max: [5, 10, 72, 20, 0],
        sunrise: [
          "2026-07-28T05:50", "2026-07-29T05:51", "2026-07-30T05:52",
          "2026-07-31T05:53", "2026-08-01T05:54"
        ],
        sunset: [
          "2026-07-28T20:10", "2026-07-29T20:09", "2026-07-30T20:08",
          "2026-07-31T20:07", "2026-08-01T20:06"
        ]
      }
    })
  }

  Services.CommandTransport {
    id: transport
    fixtureMode: true
    allowMutations: false
  }
  Services.ShellState { id: shellState }
  Services.AwesomeBridge { id: bridge }
  Services.ModalController { id: modalController }
  Services.BarPopoutController {
    id: popoutController
    modalController: modalController
  }
  Services.WeatherService {
    id: weather
    transport: transport
    refreshOnStart: false
    summaryInterval: 0
    staleAfterMs: 60000
    statePath: root.statePath
  }
  Bar.PrimaryBar {
    id: bar
    shellState: shellState
    bridge: bridge
    weatherService: weather
    modalController: modalController
    barPopoutController: popoutController
  }
  readonly property var widget: bar.weatherWidget

  function expect(condition, message) {
    if (!condition) failures.push(String(message))
  }

  function installFixtures() {
    var responses = ({})
    responses["weather.geocode.1"] = geocodeJson()
    responses["weather.summary.1"] = currentJson(24.6, 2, 1)
    responses["weather.forecast.1"] = forecastJson(0)
    responses["weather.summary.2"] = currentJson(8.2, 61, 0)
    responses["weather.forecast.2"] = forecastJson(-8)
    transport.fixtureResponses = responses
  }

  function writeResult() {
    var payload = JSON.stringify({
      ok: failures.length === 0,
      failures: failures,
      configured: weather.configured,
      location: weather.locationName,
      condition: weather.condition,
      temperature: weather.temperature,
      forecastCount: weather.forecastDays.length,
      stale: weather.stale,
      persistedCount: weather.persistedCount,
      statePath: root.statePath,
      popupOpen: widget.popupOpen,
      popupWidth: widget.panel.width,
      popupHeight: widget.panel.height,
      activePopout: popoutController.activePopout,
      requestCount: transport.nextRequestId - 1
    })
    Quickshell.execDetached([
      "/usr/bin/bash", "-c",
      "printf '%s' \"$1\" > \"$2\"",
      "weather-fixture", payload, resultPath
    ])
  }

  function finish() {
    expect(weather.locationName === "Fixture Bay", "location change replaces the selected location")
    expect(weather.hasCurrent && weather.temperature === 8,
      "changed location receives its own current conditions")
    expect(weather.forecastDays.length === 5,
      "changed location receives a bounded five-day forecast")
    expect(weather.persistedCount > 0, "versioned weather state is persisted")
    expect(widget.panel.width === 400, "weather panel width is bounded")
    expect(widget.panel.height <= 520, "weather panel height is bounded")
    expect(popoutController.activePopout === "weather", "weather owns the active popout")

    if (holdOpen) {
      writeResult()
      return
    }
    widget.closePopup()
    expect(popoutController.activePopout === "", "closing weather releases popout ownership")
    writeResult()
    quitDelay.restart()
  }

  Component.onCompleted: {
    installFixtures()
    var screenName = Quickshell.screens.length > 0 ? Quickshell.screens[0].name : ""
    bridge.applyRaw(JSON.stringify({
      primaryOutput: "fixture-primary",
      focusedOutput: "fixture-primary",
      outputs: [{ id: "fixture-primary", name: screenName }],
      tags: [{ name: "1", selected: true, occupied: true, urgent: false }],
      focusedClient: {
        title: "Weather fixture", class: "fixture", screen: "fixture-primary"
      }
    }))
    sequence.restart()
  }

  Timer {
    id: sequence
    interval: 140
    repeat: true
    onTriggered: {
      if (root.stage === 0) {
        if (!weather.initialized) return
        root.expect(!weather.configured && !weather.hasCurrent,
          "missing state starts explicitly unconfigured")
        root.expect(transport.nextRequestId === 1,
          "unconfigured weather performs no network request")
        root.expect(weather.requestGeocode("Fixture City"),
          "explicit geocoding request is accepted")
        root.stage = 1
        return
      }

      if (root.stage === 1) {
        if (weather.geocoding) return
        root.expect(weather.suggestions.length === 2,
          "geocoding returns bounded explicit suggestions")
        root.expect(weather.chooseSuggestion(0),
          "choosing a suggestion establishes the first location")
        root.stage = 2
        return
      }

      if (root.stage === 2) {
        if (weather.refreshing) return
        root.expect(weather.configured && weather.locationName === "Fixture City",
          "chosen location is configured")
        root.expect(weather.hasCurrent && weather.temperature === 25,
          "current conditions are parsed and rounded")
        root.expect(widget.openPopup(), "weather panel opens on the fixture screen")
        root.stage = 3
        return
      }

      if (root.stage === 3) {
        if (weather.refreshing || weather.forecastRefreshing) return
        root.expect(weather.forecastDays.length === 5,
          "panel open requests a bounded five-day forecast")
        root.preservedTemperature = weather.current.temperature
        transport.fixtureResponses["weather.summary.1"] = "{broken"
        root.expect(weather.refreshSummary(), "malformed-summary request is accepted")
        root.stage = 4
        return
      }

      if (root.stage === 4) {
        if (weather.refreshing) return
        root.expect(weather.stale && weather.hasCurrent,
          "malformed summary marks but preserves last-good conditions")
        root.expect(weather.current.temperature === root.preservedTemperature,
          "malformed summary preserves the last-good temperature")
        root.expect(weather.setLocation("Fixture Bay", "Second Region, Exampleland", -22.5, 130.25),
          "explicit location change is accepted")
        root.stage = 5
        return
      }

      if (root.stage === 5) {
        if (weather.refreshing || weather.forecastRefreshing) return
        sequence.stop()
        root.finish()
      }
    }
  }

  Timer {
    id: quitDelay
    interval: 300
    repeat: false
    onTriggered: Qt.quit()
  }

  Timer {
    interval: 15000
    running: true
    repeat: false
    onTriggered: {
      failures.push("fixture timed out at stage " + stage)
      writeResult()
      Qt.quit()
    }
  }
}
