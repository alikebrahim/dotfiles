import QtQuick
import Quickshell
import Quickshell.Io
import "services" as Services
import "modules/bar" as Bar
import "modules/osd" as Osd
import "modules/switcher" as Switcher
import "modules/launcher" as Launcher
import "modules/power" as PowerMenu
import "modules/calendar" as Calendar
import "modules/keybinds" as Keybinds
import "modules/display" as Display
import "modules/notifications" as Notifications
import "modules/lockscreen" as Lockscreen

ShellRoot {
  id: shell

  readonly property string runtimeDir: Quickshell.env("XDG_RUNTIME_DIR")
  readonly property string bridgeStatePath: Quickshell.env("QUICKSHELL_AWESOME_STATE")
    || (runtimeDir ? runtimeDir + "/quickshell-awesome/state.json" : "")

  property Services.ShellState shellState: Services.ShellState { }
  property Services.AwesomeBridge awesomeBridge: Services.AwesomeBridge {
    statePath: shell.bridgeStatePath
  }
  property Services.CommandTransport commandTransport: Services.CommandTransport {
    allowMutations: Quickshell.env("QUICKSHELL_ENABLE_MUTATIONS") === "1"
  }
  // Display profiles are a separately approved capability: only the fixed,
  // confirmed DisplayService profile runner receives this transport. Keeping it
  // separate leaves every other native device/system mutation behind the
  // existing per-login gate.
  property Services.CommandTransport displayCommandTransport: Services.CommandTransport {
    allowMutations: true
  }
  // Workspace focus and published-window activation are a separate WM-only
  // capability; they do not open the broader native system-control gate.
  property Services.CommandTransport workspaceCommandTransport: Services.CommandTransport {
    allowMutations: true
  }
  property Services.ModalController modalController: Services.ModalController { }
  property Services.BarPopoutController barPopoutController: Services.BarPopoutController {
    modalController: shell.modalController
  }
  property Services.AwesomeActionService awesomeActions: Services.AwesomeActionService {
    bridge: shell.awesomeBridge
    transport: shell.workspaceCommandTransport
  }
  property Services.CommandTransport sessionCommandTransport: Services.CommandTransport {
    allowMutations: true
  }
  property Services.SessionActionService sessionActions: Services.SessionActionService {
    transport: shell.sessionCommandTransport
  }
  property Services.AudioService audioService: Services.AudioService {
    transport: shell.commandTransport
  }
  property Services.NetworkService networkService: Services.NetworkService {
    transport: shell.commandTransport
  }
  property Services.BluetoothService bluetoothService: Services.BluetoothService {
    transport: shell.commandTransport
  }
  property Services.MediaService mediaService: Services.MediaService { }
  property Services.NotificationService notificationService: Services.NotificationService { }
  property Services.DbusOwnershipService dbusOwnershipService: Services.DbusOwnershipService { }
  property Services.TailscaleService tailscaleService: Services.TailscaleService {
    transport: shell.commandTransport
  }
  property Services.X11ClipboardService clipboardService: Services.X11ClipboardService { }
  property Services.WeatherService weatherService: Services.WeatherService {
    transport: shell.commandTransport
  }
  property Services.PowerService powerService: Services.PowerService {
    transport: shell.commandTransport
  }
  property Services.BrightnessService brightnessService: Services.BrightnessService {
    transport: shell.commandTransport
  }
  property Services.DisplayService displayService: Services.DisplayService {
    transport: shell.displayCommandTransport
  }
  property Services.TelemetryService telemetryService: Services.TelemetryService { }
  property Services.TelemetryCollector telemetryCollector: Services.TelemetryCollector {
    telemetryService: shell.telemetryService
    powerService: shell.powerService
    discoveryScriptPath: Quickshell.shellDir + "/scripts/discover-telemetry-paths.py"
  }
  property Services.TelemetryInterpolation telemetryInterpolation: Services.TelemetryInterpolation {
    sourceSnapshot: shell.telemetryService.snapshot
    sourceRevision: shell.telemetryService.revision
  }
  property Lockscreen.MachineSynoptic machineSynoptic: Lockscreen.MachineSynoptic {
    bridge: shell.awesomeBridge
    telemetryService: shell.telemetryService
    collector: shell.telemetryCollector
    interpolation: shell.telemetryInterpolation
    modalController: shell.modalController
  }
  property Bar.PrimaryBar primaryBar: Bar.PrimaryBar {
    shellState: shell.shellState
    bridge: shell.awesomeBridge
    mediaService: shell.mediaService
    notificationService: shell.notificationService
    dbusOwnershipService: shell.dbusOwnershipService
    tailscaleService: shell.tailscaleService
    clipboardService: shell.clipboardService
    weatherService: shell.weatherService
    audioService: shell.audioService
    networkService: shell.networkService
    bluetoothService: shell.bluetoothService
    powerService: shell.powerService
    brightnessService: shell.brightnessService
    modalController: shell.modalController
    barPopoutController: shell.barPopoutController
    onCalendarRequested: shell.calendarPanel.toggleCalendar()
  }
  property Calendar.CalendarPanel calendarPanel: Calendar.CalendarPanel {
    screen: shell.primaryBar.resolvedScreen
    barPopoutController: shell.barPopoutController
    barVisible: shell.shellState.barVisible
  }
  property Notifications.NotificationToasts notificationToasts: Notifications.NotificationToasts {
    notificationService: shell.notificationService
    targetScreen: shell.primaryBar.resolvedScreen
    suppressed: shell.machineSynoptic.lockMode
  }
  property Switcher.WindowSwitcher windowSwitcher: Switcher.WindowSwitcher {
    bridge: shell.awesomeBridge
    actions: shell.awesomeActions
    modalController: shell.modalController
  }
  property Launcher.ApplicationLauncher applicationLauncher: Launcher.ApplicationLauncher {
    bridge: shell.awesomeBridge
    modalController: shell.modalController
  }
  property PowerMenu.SessionMenu sessionMenu: PowerMenu.SessionMenu {
    bridge: shell.awesomeBridge
    sessionActions: shell.sessionActions
    modalController: shell.modalController
  }
  property Keybinds.KeybindHelp keybindHelp: Keybinds.KeybindHelp {
    bridge: shell.awesomeBridge
    modalController: shell.modalController
  }
  property Display.DisplayManager displayManager: Display.DisplayManager {
    bridge: shell.awesomeBridge
    displayService: shell.displayService
    modalController: shell.modalController
  }
  property Osd.Osd osd: Osd.Osd {
    bridge: shell.awesomeBridge
  }

  Connections {
    target: shell.shellState

    function onBarVisibleChanged() {
      if (!shell.shellState.barVisible) shell.barPopoutController.closeActive()
    }
  }

  IpcHandler {
    target: "shell"

    function ping(): string {
      return shell.shellState.ready ? "ok" : "starting"
    }

    function status(): string {
      return JSON.stringify({
        ready: shell.shellState.ready,
        bridgeReady: shell.awesomeBridge.ready,
        bridgeStale: shell.awesomeBridge.stale,
        bridgeAgeMs: shell.awesomeBridge.bridgeAgeMs,
        bridgeGeneration: shell.awesomeBridge.producerGeneration,
        bridgeError: shell.awesomeBridge.lastError,
        launcherEntries: shell.applicationLauncher.entryCount,
        sessionMenuReady: shell.sessionMenu !== null,
        calendarReady: shell.calendarPanel !== null,
        keybindHelpReady: shell.keybindHelp !== null,
        keybindCount: shell.keybindHelp.entryCount,
        displayManagerReady: shell.displayManager !== null,
        machineSynopticReady: shell.machineSynoptic !== null,
        machineSynopticOpen: shell.machineSynoptic.open,
        machineSynopticLockMode: shell.machineSynoptic.lockMode,
        machineSynopticHealth: shell.machineSynoptic.telemetryHealth,
        trayReady: shell.primaryBar.systemTray !== null,
        trayActiveItems: shell.primaryBar.systemTray.activeCount,
        trayDirectItems: shell.primaryBar.systemTray.directCount,
        trayOverflowItems: shell.primaryBar.systemTray.overflowCount,
        trayMenuOpen: shell.primaryBar.systemTray.menuOpen,
        mediaReady: shell.mediaService.backendReady,
        mediaAvailable: shell.mediaService.available,
        mediaPlayerCount: shell.mediaService.playerCount,
        mediaTitle: shell.mediaService.title,
        mediaPlaying: shell.mediaService.playing,
        mediaPopupOpen: shell.primaryBar.mediaWidget.popupOpen,
        notificationsLoaded: shell.notificationService.serverReady,
        notificationsOwnership: shell.dbusOwnershipService.notificationsState,
        notificationsOwnerPid: shell.dbusOwnershipService.notificationsOwnerPid,
        notificationsOwnedByShell: shell.dbusOwnershipService.notificationsOwnedByShell,
        statusNotifierOwnership: shell.dbusOwnershipService.statusNotifierState,
        statusNotifierOwnerPid: shell.dbusOwnershipService.statusNotifierOwnerPid,
        statusNotifierOwnedByShell: shell.dbusOwnershipService.statusNotifierOwnedByShell,
        dbusOwnershipHealthy: shell.dbusOwnershipService.healthy,
        notificationDnd: shell.notificationService.doNotDisturb,
        notificationPopupCount: shell.notificationService.popupCount,
        notificationHistoryCount: shell.notificationService.historyCount,
        notificationUnseenCount: shell.notificationService.unseenCount,
        tailscaleInstalled: shell.tailscaleService.installed,
        tailscaleConnected: shell.tailscaleService.connected,
        tailscalePeerCount: shell.tailscaleService.peerCount,
        tailscaleOnlinePeerCount: shell.tailscaleService.onlinePeerCount,
        tailscalePopupOpen: shell.primaryBar.tailscaleWidget.popupOpen,
        weatherConfigured: shell.weatherService.configured,
        weatherHasCurrent: shell.weatherService.hasCurrent,
        weatherStale: shell.weatherService.stale,
        weatherPopupOpen: shell.primaryBar.weatherWidget.popupOpen,
        audioReady: shell.audioService.backendReady,
        audioOutput: shell.audioService.currentOutputLabel,
        audioInput: shell.audioService.currentInputLabel,
        audioDetailOpen: shell.audioService.detailOpen,
        audioOutputCount: shell.audioService.outputs.length,
        audioInputCount: shell.audioService.inputs.length,
        audioStreamCount: shell.audioService.streams.length,
        microphoneInUse: shell.audioService.microphoneInUse,
        networkReady: shell.networkService.backendReady,
        networkConnection: shell.networkService.connectionName,
        networkDetailOpen: shell.networkService.detailOpen,
        networkScanning: shell.networkService.scanningDevice
          ? Boolean(shell.networkService.scanningDevice.scannerEnabled)
          : false,
        networkCount: shell.networkService.networks.length,
        networkPending: shell.networkService.pending,
        bluetoothReady: shell.bluetoothService.backendReady,
        bluetoothPowered: shell.bluetoothService.powered,
        bluetoothConnectedCount: shell.bluetoothService.connectedCount,
        bluetoothDetailOpen: shell.bluetoothService.detailOpen,
        bluetoothDiscovering: shell.bluetoothService.discovering,
        bluetoothCount: shell.bluetoothService.devices.length,
        bluetoothPending: shell.bluetoothService.pending,
        nativeMutationsEnabled: shell.commandTransport.allowMutations,
        displayMutationsEnabled: shell.displayService.actionsEnabled,
        // WM actions require both their narrow mutation transport and a fresh
        // bridge producer; stale display data remains visible but non-actionable.
        workspaceMutationsEnabled: shell.awesomeActions.actionsEnabled,
        workspaceIndex: shell.awesomeBridge.workspaceIndex,
        workspaceSynchronized: shell.awesomeBridge.ready
          && shell.awesomeBridge.workspaceSynchronized
      })
    }

    function refreshDbusOwnership(): string {
      shell.dbusOwnershipService.refresh()
      return "refresh-requested"
    }
  }

  IpcHandler {
    target: "bar"

    function status(): string {
      return JSON.stringify({
        visible: shell.shellState.barVisible,
        resident: shell.shellState.resident,
        ready: shell.shellState.ready,
        trayActiveItems: shell.primaryBar.systemTray.activeCount,
        trayDirectItems: shell.primaryBar.systemTray.directCount,
        trayOverflowItems: shell.primaryBar.systemTray.overflowCount,
        trayMenuOpen: shell.primaryBar.systemTray.menuOpen,
        mediaAvailable: shell.mediaService.available,
        mediaPlayerCount: shell.mediaService.playerCount,
        mediaPopupOpen: shell.primaryBar.mediaWidget.popupOpen,
        notificationsEnabled: shell.notificationService.serverReady,
        notificationDnd: shell.notificationService.doNotDisturb,
        notificationUnseenCount: shell.notificationService.unseenCount,
        notificationHistoryOpen: shell.primaryBar.notificationWidget.popupOpen,
        tailscaleConnected: shell.tailscaleService.connected,
        tailscalePeerCount: shell.tailscaleService.peerCount,
        tailscalePopupOpen: shell.primaryBar.tailscaleWidget.popupOpen,
        weatherConfigured: shell.weatherService.configured,
        weatherHasCurrent: shell.weatherService.hasCurrent,
        weatherPopupOpen: shell.primaryBar.weatherWidget.popupOpen
      })
    }

    function toggleVisibility(): string {
      return shell.shellState.toggleBar() ? "visible" : "hidden"
    }

    function show(): string {
      shell.shellState.setBarVisible(true)
      return "visible"
    }

    function showBar(): string {
      shell.shellState.setBarVisible(true)
      return "visible"
    }

    function hide(): string {
      shell.shellState.setBarVisible(false)
      return "hidden"
    }

    function hideBar(): string {
      shell.shellState.setBarVisible(false)
      return "hidden"
    }
  }
}
