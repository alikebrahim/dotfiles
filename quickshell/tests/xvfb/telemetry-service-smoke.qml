import QtQuick
import Quickshell

ShellRoot {
  id: root

  readonly property string resultPath: Quickshell.env("QUATTRO_QS_TEST_RESULT")
  property var failures: []

  Loader {
    id: serviceLoader
    source: "file://" + Quickshell.env("QUATTRO_TELEMETRY_SERVICE")
    onLoaded: Qt.callLater(root.runChecks)
  }

  function expect(condition, message) {
    if (!condition) failures.push(String(message))
  }

  function completeSample(seed) {
    return {
      cpu: {
        utilization: 42 + seed,
        frequencyMhz: 4100,
        packageTempC: 58,
        pressureSome: 0.2,
        pressureFull: 0
      },
      gpu: {
        utilization: 30,
        temperatureC: 47,
        powerW: 34.5,
        powerLimitW: 115,
        vramUsedMiB: 2310,
        vramTotalMiB: 8188,
        graphicsClockMhz: 2100,
        memoryClockMhz: 810
      },
      memory: {
        ramUsedBytes: 12500000000,
        ramTotalBytes: 32684452000,
        swapUsedBytes: 0,
        swapTotalBytes: 8589934592,
        pressureSome: 0,
        pressureFull: 0
      },
      io: {
        networkRxBps: 840000,
        networkTxBps: 210000,
        diskReadBps: 14000000,
        diskWriteBps: 3200000,
        pressureSome: 0.02,
        pressureFull: 0
      },
      thermal: {
        cpuFanRpm: 3428,
        gpuFanRpm: 3411,
        nvmeMaxC: 35,
        dimmMaxC: 48
      },
      power: {
        batteryPresent: true,
        batteryPercent: 76,
        batteryState: "charging",
        onBattery: false
      },
      time: {
        uptimeSeconds: 357184,
        visibleSeconds: seed
      }
    }
  }

  function shellQuote(value) {
    return "'" + String(value).replace(/'/g, "'\\''") + "'"
  }

  function finish(service) {
    var payload = JSON.stringify({
      ok: failures.length === 0,
      failures: failures,
      revision: service.revision,
      health: service.health,
      history60: service.history60.length,
      history300: service.history300.length,
      preservedGpu: service.snapshot.gpu.utilization,
      sensorSchema: service.sensorPaths.schemaVersion || 0
    })
    Quickshell.execDetached([
      "bash", "-lc",
      "printf '%s' " + shellQuote(payload) + " > " + shellQuote(resultPath)
    ])
    quitDelay.start()
  }

  function runChecks() {
    var service = serviceLoader.item
    expect(service !== null, "telemetry service loads")
    if (!service) {
      finish({ revision: 0, health: "missing", history60: [], history300: [], snapshot: { gpu: {} }, sensorPaths: {} })
      return
    }

    service.staleAfterMs = 3200
    expect(service.acceptSample(completeSample(0), 1000), "complete sample is accepted")
    expect(service.revision === 1, "first sample increments revision")
    expect(service.health === "nominal", "complete sample is nominal")
    expect(service.snapshot.cpu.utilization === 42, "CPU utilization is normalized")
    expect(service.history60.length === 1 && service.history300.length === 1,
      "first sample enters both histories")

    expect(service.acceptSample({
      cpu: { utilization: 88 },
      gpu: { utilization: null, temperatureC: "invalid" }
    }, 2000), "partial valid sample is accepted")
    expect(service.snapshot.cpu.utilization === 88, "valid partial value updates")
    expect(service.snapshot.gpu.utilization === 30, "invalid GPU value preserves last-good state")
    expect(service.health === "nominal", "recent omitted sources remain nominal")

    var beforeInvalid = service.revision
    expect(!service.acceptSample({ gpu: { utilization: 400 } }, 2500),
      "out-of-range-only sample is rejected")
    expect(service.revision === beforeInvalid, "rejected sample preserves revision")
    expect(service.snapshot.gpu.utilization === 30, "rejected sample preserves snapshot")

    var discovery = JSON.stringify({
      schemaVersion: 1,
      sensors: { cpuPackage: { chip: "coretemp", label: "Package id 0", input: "/fixture/temp1_input" } },
      cpufreq: ["/fixture/policy0/scaling_cur_freq"]
    })
    expect(service.applyDiscoveryJson(discovery), "valid discovery payload is accepted")
    expect(!service.applyDiscoveryJson("{broken"), "malformed discovery payload is rejected")
    expect(service.sensorPaths.schemaVersion === 1, "malformed discovery preserves last-good paths")

    for (var index = 0; index < 305; index++)
      service.acceptSample(completeSample(index % 5), 3000 + index * 1000)
    expect(service.history60.length === 60, "short history is bounded to 60 samples")
    expect(service.history300.length === 300, "long history is bounded to 300 samples")

    var lastSample = service.sampledAtMs
    service.refreshHealth(lastSample + 4000)
    expect(service.health === "stale", "old aggregate sample becomes stale")
    expect(service.snapshot.freshness.cpu.state === "stale", "per-source freshness becomes stale")

    finish(service)
  }

  Timer {
    id: quitDelay
    interval: 150
    repeat: false
    onTriggered: Qt.quit()
  }

  Timer {
    interval: 5000
    running: true
    repeat: false
    onTriggered: {
      failures.push("fixture watchdog expired")
      if (serviceLoader.item) finish(serviceLoader.item)
      else Qt.quit()
    }
  }
}
