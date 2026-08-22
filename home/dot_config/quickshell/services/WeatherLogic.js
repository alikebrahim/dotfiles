.pragma library

function bounded(value, limit) {
  var text = String(value === undefined || value === null ? "" : value)
    .replace(/[\r\n\t]+/g, " ")
    .replace(/\s+/g, " ")
    .trim()
  var maximum = Math.max(0, Number(limit) || 0)
  return maximum > 0 && text.length > maximum ? text.substring(0, maximum) : text
}

function finiteNumber(value) {
  var number = Number(value)
  return isFinite(number) ? number : NaN
}

function weatherMeta(code, isDay) {
  var value = Math.round(finiteNumber(code))
  var day = Number(isDay) !== 0
  if (value === 0) return { icon: day ? "☀" : "☾", condition: "Clear sky" }
  if (value === 1) return { icon: day ? "☀" : "☾", condition: "Mainly clear" }
  if (value === 2) return { icon: "◐", condition: "Partly cloudy" }
  if (value === 3) return { icon: "☁", condition: "Overcast" }
  if (value === 45 || value === 48) return { icon: "≋", condition: "Fog" }
  if (value >= 51 && value <= 57) return { icon: "☂", condition: "Drizzle" }
  if (value >= 61 && value <= 67) return { icon: "☂", condition: "Rain" }
  if ((value >= 71 && value <= 77) || value === 85 || value === 86)
    return { icon: "*", condition: "Snow" }
  if (value >= 80 && value <= 82) return { icon: "☂", condition: "Rain showers" }
  if (value === 95 || value === 96 || value === 99)
    return { icon: "⚡", condition: "Thunderstorm" }
  return { icon: "·", condition: "Unknown" }
}

function normalizeCurrent(value) {
  if (!value || typeof value !== "object") return null
  var temperature = finiteNumber(value.temperature)
  var apparent = finiteNumber(value.apparentTemperature)
  var humidity = finiteNumber(value.humidity)
  var wind = finiteNumber(value.windSpeed)
  var precipitation = finiteNumber(value.precipitation)
  var code = finiteNumber(value.weatherCode)
  var isDay = finiteNumber(value.isDay)
  if (!isFinite(temperature) || !isFinite(apparent) || !isFinite(humidity)
      || !isFinite(wind) || !isFinite(precipitation) || !isFinite(code) || !isFinite(isDay)) return null
  var meta = weatherMeta(code, isDay)
  return {
    time: bounded(value.time, 40),
    temperature: temperature,
    apparentTemperature: apparent,
    humidity: Math.max(0, Math.min(100, humidity)),
    windSpeed: Math.max(0, wind),
    precipitation: Math.max(0, precipitation),
    weatherCode: Math.round(code),
    isDay: isDay !== 0 ? 1 : 0,
    temperatureUnit: bounded(value.temperatureUnit || "°C", 8),
    windUnit: bounded(value.windUnit || "km/h", 12),
    precipitationUnit: bounded(value.precipitationUnit || "mm", 8),
    icon: meta.icon,
    condition: meta.condition
  }
}

function parseCurrent(raw) {
  var data
  try {
    data = JSON.parse(String(raw || ""))
  } catch (error) {
    return { ok: false, error: "Malformed weather response" }
  }
  if (!data || typeof data !== "object" || data.error === true
      || !data.current || typeof data.current !== "object")
    return { ok: false, error: bounded(data && data.reason || "Weather response has no current conditions", 180) }

  var current = data.current
  var units = data.current_units || {}
  var normalized = normalizeCurrent({
    time: current.time,
    temperature: current.temperature_2m,
    apparentTemperature: current.apparent_temperature,
    humidity: current.relative_humidity_2m,
    windSpeed: current.wind_speed_10m,
    precipitation: current.precipitation,
    weatherCode: current.weather_code,
    isDay: current.is_day,
    temperatureUnit: units.temperature_2m,
    windUnit: units.wind_speed_10m,
    precipitationUnit: units.precipitation
  })
  if (!normalized) return { ok: false, error: "Weather response is incomplete" }
  return { ok: true, current: normalized }
}

function normalizeForecastDay(value) {
  if (!value || typeof value !== "object") return null
  var high = finiteNumber(value.high)
  var low = finiteNumber(value.low)
  var precipitation = finiteNumber(value.precipitationProbability)
  var code = finiteNumber(value.weatherCode)
  if (bounded(value.date, 20) === "" || !isFinite(high) || !isFinite(low)
      || !isFinite(precipitation) || !isFinite(code)) return null
  var meta = weatherMeta(code, 1)
  return {
    date: bounded(value.date, 20),
    high: high,
    low: low,
    precipitationProbability: Math.max(0, Math.min(100, precipitation)),
    weatherCode: Math.round(code),
    sunrise: bounded(value.sunrise, 40),
    sunset: bounded(value.sunset, 40),
    icon: meta.icon,
    condition: meta.condition
  }
}

function parseForecast(raw, limit) {
  var data
  try {
    data = JSON.parse(String(raw || ""))
  } catch (error) {
    return { ok: false, error: "Malformed forecast response" }
  }
  if (!data || typeof data !== "object" || data.error === true
      || !data.daily || typeof data.daily !== "object")
    return { ok: false, error: bounded(data && data.reason || "Forecast response has no daily data", 180) }

  var daily = data.daily
  var count = Math.min(
    Math.max(1, Number(limit) || 5),
    Array.isArray(daily.time) ? daily.time.length : 0,
    Array.isArray(daily.weather_code) ? daily.weather_code.length : 0,
    Array.isArray(daily.temperature_2m_max) ? daily.temperature_2m_max.length : 0,
    Array.isArray(daily.temperature_2m_min) ? daily.temperature_2m_min.length : 0,
    Array.isArray(daily.precipitation_probability_max) ? daily.precipitation_probability_max.length : 0
  )
  if (count <= 0) return { ok: false, error: "Forecast response is incomplete" }

  var days = []
  for (var i = 0; i < count; i++) {
    var day = normalizeForecastDay({
      date: daily.time[i],
      weatherCode: daily.weather_code[i],
      high: daily.temperature_2m_max[i],
      low: daily.temperature_2m_min[i],
      precipitationProbability: daily.precipitation_probability_max[i],
      sunrise: Array.isArray(daily.sunrise) ? daily.sunrise[i] : "",
      sunset: Array.isArray(daily.sunset) ? daily.sunset[i] : ""
    })
    if (day) days.push(day)
  }
  return days.length > 0 ? { ok: true, days: days }
    : { ok: false, error: "Forecast response is incomplete" }
}

function parseGeocoding(raw, limit) {
  var data
  try {
    data = JSON.parse(String(raw || ""))
  } catch (error) {
    return { ok: false, error: "Malformed location response" }
  }
  if (!data || typeof data !== "object" || data.error === true)
    return { ok: false, error: bounded(data && data.reason || "Location response is invalid", 180) }

  var source = Array.isArray(data.results) ? data.results : []
  var maximum = Math.max(1, Math.min(10, Number(limit) || 5))
  var output = []
  var seen = ({})
  for (var i = 0; i < source.length && output.length < maximum; i++) {
    var item = source[i] || {}
    var name = bounded(item.name, 96)
    var lat = finiteNumber(item.latitude)
    var lon = finiteNumber(item.longitude)
    if (name === "" || !isFinite(lat) || lat < -90 || lat > 90 || !isFinite(lon) || lon < -180 || lon > 180) continue
    var parts = []
    var admin = bounded(item.admin1, 64)
    var country = bounded(item.country, 64)
    if (admin !== "" && admin !== name) parts.push(admin)
    if (country !== "") parts.push(country)
    var detail = parts.join(", ")
    var key = name + "|" + detail + "|" + lat + "|" + lon
    if (seen[key]) continue
    seen[key] = true
    output.push({
      key: bounded(item.id || key, 128),
      name: name,
      detail: detail,
      latitude: lat,
      longitude: lon,
      timezone: bounded(item.timezone, 64),
      countryCode: bounded(item.country_code, 8)
    })
  }
  return { ok: true, results: output }
}

function parseState(raw) {
  var data
  try {
    data = JSON.parse(String(raw || ""))
  } catch (error) {
    return { ok: false, error: "Malformed weather state" }
  }
  if (!data || Number(data.version) !== 1)
    return { ok: false, error: "Unsupported weather state" }
  if (!data.location) return {
    ok: true, configured: false, location: null, current: ({}), forecastDays: [],
    currentUpdatedAt: 0, forecastUpdatedAt: 0
  }

  var location = data.location || {}
  var name = bounded(location.name, 96)
  var latitude = finiteNumber(location.latitude)
  var longitude = finiteNumber(location.longitude)
  if (name === "" || !isFinite(latitude) || latitude < -90 || latitude > 90
      || !isFinite(longitude) || longitude < -180 || longitude > 180)
    return { ok: false, error: "Weather state location is invalid" }

  var cache = data.cache || {}
  var current = normalizeCurrent(cache.current) || ({})
  var forecastSource = Array.isArray(cache.forecastDays) ? cache.forecastDays : []
  var forecastDays = []
  for (var i = 0; i < forecastSource.length && forecastDays.length < 7; i++) {
    var day = normalizeForecastDay(forecastSource[i])
    if (day) forecastDays.push(day)
  }
  var currentUpdatedAt = finiteNumber(cache.currentUpdatedAt)
  var forecastUpdatedAt = finiteNumber(cache.forecastUpdatedAt)
  return {
    ok: true,
    configured: true,
    location: {
      name: name,
      detail: bounded(location.detail, 140),
      latitude: latitude,
      longitude: longitude
    },
    current: current,
    forecastDays: forecastDays,
    currentUpdatedAt: isFinite(currentUpdatedAt) ? currentUpdatedAt : 0,
    forecastUpdatedAt: isFinite(forecastUpdatedAt) ? forecastUpdatedAt : 0
  }
}
