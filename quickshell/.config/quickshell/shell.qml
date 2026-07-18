//@ pragma Env QT_QPA_PLATFORM=xcb
//@ pragma Env QT_QUICK_CONTROLS_STYLE=Basic

import QtQuick
import Quickshell
import "services"
import "modules/OSD"
import "modules/Bar"
import "modules/QuickPanel"
import "modules/Launcher"
import "modules/FullPanel"
import "modules/QuickApps"

// shell.qml — modular entry point.
//
// Loads the shared services (Theme, BridgeState — both singletons
// registered via services/qmldir) and mounts each top-level surface as
// its own component. Surfaces are added incrementally as they're built;
// see revamp/plan.md for the full component inventory and build order.
//
// Notifications (services/Notifications.qml, modules/Notifications/*)
// is deliberately NOT imported/instantiated here — starting its
// NotificationServer would fight Dunst for the D-Bus name. It stays
// built-but-inert until the authorized integration phase removes
// Dunst's autostart line in the same step.
//
// This file replaces the earlier monolithic prototype (theme tokens +
// volume OSD all inline in one file). The OSD's behavior and IPC
// interface (`osd` target, `showVolume`/`volumeUp`/`volumeDown`/
// `toggleMute`/`showCurrentVolume` methods) are preserved unchanged in
// modules/OSD/OSD.qml — this is a hard compatibility requirement, since
// awesome_wm_scripts/.config/scripts/quickshell-osd-volume.sh calls
// `quickshell ipc -p <this file> call osd showVolume <percent> <muted>`
// today and must keep working.
ShellRoot {
    id: shellRoot

    OSD {
        id: osd
    }

    Bar {
        id: bar
    }

    QuickPanel {
        id: quickPanel
    }

    Launcher {
        id: launcher
    }

    WindowSwitcher {
        id: windowSwitcher
    }

    FullPanel {
        id: fullPanel
    }

    QuickApps {
        id: quickApps
    }

}
