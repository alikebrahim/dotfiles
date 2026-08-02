import QtQuick
import Quickshell
import Quickshell.Io
import "WeatherLogic.js" as Logic

Item {
  id: root

  required property QtObject transport
  property bool refreshOnStart: true
  property int summaryInterval: 900000
  property int staleAfterMs: 2700000
  property int forecastDaysLimit: 5
  property string curlBinary: "/usr/bin/curl"
  property string statePath: {
    var home = Quickshell.env("HOME")
    var base = Quickshell.env("XDG_STATE_HOME")
      || (home ? home + "/.local/state" : "")
    return base ? base + "/quickshell/weather/weather-v1.json" : ""
  }

  property bool initialized: false
  property string locationName: ""
  property string locationDetail: ""
  property real latitude: NaN
  property real longitude: NaN
  property int locationRevision: 0

  property var current: ({})
  property var forecastDays: []
  property double currentUpdatedAt: 0
  property double forecastUpdatedAt: 0
  property bool stale: false
  property bool refreshing: false
  property bool forecastRefreshing: false
  property bool geocoding: false
  property var suggestions: []
  property string geocodeQuery: ""
  property string error: ""
  property string geocodeError: ""
  property string summaryRequestKey: ""
  property string forecastRequestKey: ""
  property string geocodeRequestKey: ""
  property int geocodeRevision: 0
  property bool panelOpen: false
  property string pendingStatePayload: ""
  property int persistedCount: 0

  readonly property bool configured: locationName !== ""
    && isFinite(latitude) && latitude >= -90 && latitude <= 90
    && isFinite(longitude) && longitude >= -180 && longitude <= 180
  readonly property bool hasCurrent: current && current.temperature !== undefined
  readonly property bool hasForecast: forecastDays.length > 0
  readonly property string icon: hasCurrent ? String(current.icon || "·") : "·"
  readonly property string condition: hasCurrent ? String(current.condition || "Unavailable") : "Unavailable"
  readonly property int temperature: hasCurrent ? Math.round(Number(current.temperature)) : 0
  readonly property int apparentTemperature: hasCurrent ? Math.round(Number(current.apparentTemperature)) : 0
  readonly property int humidity: hasCurrent ? Math.round(Number(current.humidity)) : 0
  readonly property int windSpeed: hasCurrent ? Math.round(Number(current.windSpeed)) : 0
  readonly property real precipitation: hasCurrent ? Number(current.precipitation || 0) : 0
  readonly property string temperatureUnit: hasCurrent ? String(current.temperatureUnit || "°C") : "°C"

  function stateDirectory() {
    var slash = statePath.lastIndexOf("/")
    return slash > 0 ? statePath.substring(0, slash) : "."
  }

  function boundedError(value) {
    return Logic.bounded(value, 180)
  }

  function summaryUrl() {
    return "https://api.open-meteo.com/v1/forecast"
      + "?latitude=" + encodeURIComponent(String(latitude))
      + "&longitude=" + encodeURIComponent(String(longitude))
      + "&current=temperature_2m,apparent_temperature,relative_humidity_2m,precipitation,weather_code,wind_speed_10m,is_day"
      + "&timezone=auto"
  }

  function forecastUrl() {
    return "https://api.open-meteo.com/v1/forecast"
      + "?latitude=" + encodeURIComponent(String(latitude))
      + "&longitude=" + encodeURIComponent(String(longitude))
      + "&daily=weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max,sunrise,sunset"
      + "&forecast_days=" + Math.max(1, Math.min(7, forecastDaysLimit))
      + "&timezone=auto"
  }

  function curlCommand(url) {
    return [curlBinary, "-fsS", "--connect-timeout", "3", "--max-time", "4", url]
  }

  function refreshSummary() {
    if (!configured || refreshing) return false
    var key = "weather.summary." + locationRevision
    summaryRequestKey = key
    refreshing = true
    error = ""
    transport.request(key, curlCommand(summaryUrl()), false, false)
    return true
  }

  function refreshForecast() {
    if (!configured || forecastRefreshing) return false
    var key = "weather.forecast." + locationRevision
    forecastRequestKey = key
    forecastRefreshing = true
    transport.request(key, curlCommand(forecastUrl()), false, false)
    return true
  }

  function refresh() {
    var requested = refreshSummary()
    if (panelOpen) requested = refreshForecast() || requested
    return requested
  }

  function setPanelOpen(open) {
    panelOpen = open === true
    if (panelOpen && configured) refresh()
  }

  function requestGeocode(query) {
    var clean = Logic.bounded(query, 120)
    if (clean.length < 2) {
      suggestions = []
      geocodeError = "Enter at least two characters"
      return false
    }
    if (geocoding) return false
    geocodeRevision++
    geocodeQuery = clean
    geocodeRequestKey = "weather.geocode." + geocodeRevision
    geocoding = true
    geocodeError = ""
    suggestions = []
    var url = "https://geocoding-api.open-meteo.com/v1/search?name="
      + encodeURIComponent(clean) + "&count=5&language=en&format=json"
    transport.request(geocodeRequestKey, curlCommand(url), false, false)
    return true
  }

  function chooseSuggestion(index) {
    var chosen = suggestions[index]
    if (!chosen) return false
    return setLocation(chosen.name, chosen.detail, chosen.latitude, chosen.longitude)
  }

  function setLocation(name, detail, lat, lon) {
    var cleanName = Logic.bounded(name, 96)
    var cleanDetail = Logic.bounded(detail, 140)
    var latitudeNumber = Number(lat)
    var longitudeNumber = Number(lon)
    if (cleanName === "" || !isFinite(latitudeNumber) || latitudeNumber < -90 || latitudeNumber > 90
        || !isFinite(longitudeNumber) || longitudeNumber < -180 || longitudeNumber > 180) {
      geocodeError = "Invalid location"
      return false
    }

    locationRevision++
    locationName = cleanName
    locationDetail = cleanDetail
    latitude = latitudeNumber
    longitude = longitudeNumber
    current = ({})
    forecastDays = []
    currentUpdatedAt = 0
    forecastUpdatedAt = 0
    stale = false
    error = ""
    geocodeError = ""
    suggestions = []
    queuePersist()
    refreshSummary()
    if (panelOpen) refreshForecast()
    return true
  }

  function clearLocation() {
    locationRevision++
    locationName = ""
    locationDetail = ""
    latitude = NaN
    longitude = NaN
    current = ({})
    forecastDays = []
    currentUpdatedAt = 0
    forecastUpdatedAt = 0
    stale = false
    error = ""
    suggestions = []
    queuePersist()
    return true
  }

  function applySummaryRaw(raw, expectedRevision) {
    if (expectedRevision !== undefined && Number(expectedRevision) !== locationRevision) return false
    var parsed = Logic.parseCurrent(raw)
    if (!parsed.ok) {
      if (hasCurrent) stale = true
      error = parsed.error
      return false
    }
    current = parsed.current
    currentUpdatedAt = Date.now()
    stale = false
    error = ""
    queuePersist()
    return true
  }

  function applyForecastRaw(raw, expectedRevision) {
    if (expectedRevision !== undefined && Number(expectedRevision) !== locationRevision) return false
    var parsed = Logic.parseForecast(raw, forecastDaysLimit)
    if (!parsed.ok) {
      error = parsed.error
      return false
    }
    forecastDays = parsed.days
    forecastUpdatedAt = Date.now()
    error = ""
    queuePersist()
    return true
  }

  function applyGeocodeRaw(raw) {
    var parsed = Logic.parseGeocoding(raw, 5)
    if (!parsed.ok) {
      suggestions = []
      geocodeError = parsed.error
      return false
    }
    suggestions = parsed.results
    geocodeError = suggestions.length === 0 ? "No matching locations" : ""
    return suggestions.length > 0
  }

  function markReadFailure(kind, message) {
    var clean = boundedError(message)
    if (kind === "summary") {
      if (hasCurrent) stale = true
      error = clean || "Weather unavailable"
    } else if (kind === "forecast") {
      error = clean || "Forecast unavailable"
    } else {
      suggestions = []
      geocodeError = clean || "Location search unavailable"
    }
  }

  function snapshotPayload() {
    return JSON.stringify({
      version: 1,
      location: configured ? {
        name: locationName,
        detail: locationDetail,
        latitude: latitude,
        longitude: longitude
      } : null,
      cache: {
        current: hasCurrent ? current : null,
        forecastDays: forecastDays,
        currentUpdatedAt: currentUpdatedAt,
        forecastUpdatedAt: forecastUpdatedAt
      }
    })
  }

  function queuePersist() {
    if (!initialized && !configured && !hasCurrent) return
    pendingStatePayload = snapshotPayload()
    if (!stateDirProcess.running) {
      stateDirProcess.command = ["/usr/bin/mkdir", "-p", stateDirectory()]
      stateDirProcess.running = true
    }
  }

  function applyState(raw) {
    var parsed = Logic.parseState(raw)
    initialized = true
    if (!parsed.ok) return false
    if (!parsed.configured) return true

    locationRevision++
    locationName = parsed.location.name
    locationDetail = parsed.location.detail
    latitude = parsed.location.latitude
    longitude = parsed.location.longitude
    current = parsed.current
    forecastDays = parsed.forecastDays
    currentUpdatedAt = parsed.currentUpdatedAt
    forecastUpdatedAt = parsed.forecastUpdatedAt
    stale = hasCurrent && Date.now() - currentUpdatedAt > staleAfterMs
    if (refreshOnStart) Qt.callLater(refreshSummary)
    return true
  }

  FileView {
    id: stateFile
    path: root.statePath
    atomicWrites: true
    printErrors: false
    onLoaded: root.applyState(text())
    onLoadFailed: root.initialized = true
  }

  Process {
    id: stateDirProcess
    onExited: function(exitCode) {
      if (exitCode !== 0 || root.pendingStatePayload === "") {
        if (exitCode !== 0) root.error = "Weather state directory unavailable"
        return
      }
      stateFile.setText(root.pendingStatePayload)
      root.persistedCount++
    }
  }

  Connections {
    target: root.transport

    function onFinished(requestId, key, ok, stdoutText, stderrText) {
      if (key === root.summaryRequestKey) {
        root.refreshing = false
        var revision = Number(key.substring(key.lastIndexOf(".") + 1))
        if (revision !== root.locationRevision) return
        if (!ok) {
          root.markReadFailure("summary", stderrText)
          return
        }
        root.applySummaryRaw(stdoutText, revision)
        return
      }
      if (key === root.forecastRequestKey) {
        root.forecastRefreshing = false
        var forecastRevision = Number(key.substring(key.lastIndexOf(".") + 1))
        if (forecastRevision !== root.locationRevision) return
        if (!ok) {
          root.markReadFailure("forecast", stderrText)
          return
        }
        root.applyForecastRaw(stdoutText, forecastRevision)
        return
      }
      if (key === root.geocodeRequestKey) {
        root.geocoding = false
        if (!ok) {
          root.markReadFailure("geocode", stderrText)
          return
        }
        root.applyGeocodeRaw(stdoutText)
      }
    }
  }

  Timer {
    interval: Math.max(60000, root.summaryInterval)
    running: root.configured && root.summaryInterval > 0
    repeat: true
    onTriggered: root.refreshSummary()
  }

  Timer {
    interval: 60000
    running: root.hasCurrent
    repeat: true
    onTriggered: if (Date.now() - root.currentUpdatedAt > root.staleAfterMs) root.stale = true
  }

  Timer {
    interval: 250
    running: !root.initialized
    repeat: false
    onTriggered: root.initialized = true
  }
}
