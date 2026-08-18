import QtQuick
import Quickshell

ShellRoot {
  id: root

  readonly property string resultPath: Quickshell.env("QUATTRO_QS_TEST_RESULT")
  property var failures: []
  readonly property var telemetry: serviceLoader.item
  readonly property var collector: collectorLoader.item
  readonly property var interpolation: interpolationLoader.item
  property bool checksStarted: false

  Loader {
    id: serviceLoader
    source: "file://" + Quickshell.env("QUATTRO_TELEMETRY_SERVICE")
    onLoaded: root.maybeRunChecks()
  }

  Loader {
    id: collectorLoader
    source: "file://" + Quickshell.env("QUATTRO_TELEMETRY_COLLECTOR")
    onLoaded: root.maybeRunChecks()
  }

  Loader {
    id: interpolationLoader
    source: "file://" + Quickshell.env("QUATTRO_TELEMETRY_INTERPOLATION")
    onLoaded: root.maybeRunChecks()
  }

  function expect(condition, message) {
    if (!condition) failures.push(String(message))
  }

  function shellQuote(value) {
    return "'" + String(value).replace(/'/g, "'\\''") + "'"
  }

  function completeSample() {
    return {
      cpu: { utilization: 80, frequencyMhz: 4000, packageTempC: 60, pressureSome: 0.2, pressureFull: 0 },
      gpu: {
        utilization: 40, temperatureC: 50, powerW: 35, powerLimitW: 115,
        vramUsedMiB: 2000, vramTotalMiB: 8188, graphicsClockMhz: 1800, memoryClockMhz: 810
      },
      memory: {
        ramUsedBytes: 12000000000, ramTotalBytes: 32000000000,
        swapUsedBytes: 0, swapTotalBytes: 8000000000, pressureSome: 0, pressureFull: 0
      },
      io: {
        networkRxBps: 1000, networkTxBps: 500, diskReadBps: 2000, diskWriteBps: 800,
        pressureSome: 0.1, pressureFull: 0
      },
      thermal: { cpuFanRpm: 3400, gpuFanRpm: 3300, nvmeMaxC: 36, dimmMaxC: 44 },
      power: { batteryPresent: true, batteryPercent: 78, batteryState: "pending-charge", onBattery: false },
      time: { uptimeSeconds: 1000, visibleSeconds: 3 }
    }
  }

  function maybeRunChecks() {
    if (checksStarted || !telemetry || !collector || !interpolation) return
    checksStarted = true
    collector.telemetryService = telemetry
    Qt.callLater(runChecks)
  }

  function runChecks() {
    var firstCpu = collector.parseProcStat("cpu 100 0 100 700 100 0 0 0 0 0")
    var secondCpu = collector.parseProcStat("cpu 200 0 200 1200 200 0 0 0 0 0")
    expect(firstCpu === null, "first CPU counter is a baseline")
    expect(Math.abs(secondCpu - 25) < 0.001, "CPU utilization uses counter deltas")

    var memory = collector.parseMeminfo(
      "MemTotal: 1000 kB\nMemAvailable: 400 kB\nSwapTotal: 200 kB\nSwapFree: 150 kB\n")
    expect(memory.ramUsedBytes === 600 * 1024, "RAM uses MemAvailable")
    expect(memory.swapUsedBytes === 50 * 1024, "swap uses total minus free")

    var pressure = collector.parsePressure(
      "some avg10=1.25 avg60=0.40 avg300=0.10 total=10\nfull avg10=0.20 avg60=0.10 avg300=0.05 total=2\n")
    expect(pressure.some === 1.25 && pressure.full === 0.2, "PSI parses avg10 some/full")

    var route = collector.parseDefaultRoute(
      "Iface Destination Gateway Flags RefCnt Use Metric Mask MTU Window IRTT\nenp1s0 00000000 01010101 0003 0 0 0 00000000 0 0 0\n")
    expect(route === "enp1s0", "default-route interface is selected internally")

    var network = collector.parseNetworkCounters(
      "Inter-| Receive | Transmit\n face |bytes packets errs drop fifo frame compressed multicast|bytes packets errs drop fifo colls carrier compressed\n" +
      " lo: 100 0 0 0 0 0 0 0 100 0 0 0 0 0 0 0\n" +
      " enp1s0: 5000 0 0 0 0 0 0 0 7000 0 0 0 0 0 0 0\n", route)
    expect(network.rx === 5000 && network.tx === 7000, "network counters use the default route")

    var disk = collector.parseDiskCounters(
      "259 0 nvme0n1 1 0 100 0 1 0 200 0 0 0 0 0 0 0 0 0\n" +
      "259 1 nvme0n1p1 1 0 999 0 1 0 999 0 0 0 0 0 0 0 0 0\n")
    expect(disk.readBytes === 100 * 512 && disk.writeBytes === 200 * 512,
      "disk counters include whole devices and exclude partitions")

    expect(collector.parseGpuLine("30, 48, 34.5, 115, 1777, 8188, 210, 405"),
      "NVIDIA stream line is accepted")
    expect(collector.gpuSamples === 1 && collector._lastGpuSample.vramTotalMiB === 8188,
      "NVIDIA fields are mapped")

    telemetry.acceptSample(completeSample(), 1000)
    interpolation.sourceSnapshot = telemetry.snapshot
    interpolation.sourceRevision = telemetry.revision
    interpolation.active = true
    finishDelay.start()
  }

  function finish() {
    expect(interpolation.frameCount >= 8, "interpolator advances near 30 FPS")
    expect(interpolation.snapshot.cpu.utilization > 0 && interpolation.snapshot.cpu.utilization <= 80,
      "interpolated CPU value remains bounded")
    expect(interpolation.cpuRotorPhase > 0 && interpolation.gpuRotorPhase > 0,
      "fan carrier phases advance from RPM")

    var payload = JSON.stringify({
      ok: failures.length === 0,
      failures: failures,
      cpuDelta: collector.parseProcStat("cpu 300 0 300 1700 300 0 0 0 0 0"),
      gpuSamples: collector.gpuSamples,
      interpolationFrames: interpolation.frameCount,
      cpuRotorPhase: interpolation.cpuRotorPhase,
      gpuRotorPhase: interpolation.gpuRotorPhase
    })
    Quickshell.execDetached([
      "bash", "-lc",
      "printf '%s' " + shellQuote(payload) + " > " + shellQuote(resultPath)
    ])
    quitDelay.start()
  }


  Timer {
    id: finishDelay
    interval: 500
    repeat: false
    onTriggered: root.finish()
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
      root.finish()
    }
  }
}
