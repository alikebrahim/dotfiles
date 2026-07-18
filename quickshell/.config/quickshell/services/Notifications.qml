pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Services.Notifications

// Notifications.qml — wraps Quickshell's native NotificationServer,
// exposing a history buffer for both transient toasts and the
// browsable notification center (Mod+N).
//
// decisions.md §9: Dunst is dropped entirely (no DND toggle needed per
// that section's explicit "No need for DND" answer). This singleton is
// the single source of truth both Toast.qml and NotificationCenter.qml
// read from — a toast is just "the newest entry, shown transiently",
// the center is "the whole buffer, browsable" (plan.md §4).
//
// IMPORTANT (not yet done): actually starting this server will claim
// the notifications D-Bus name, which conflicts with Dunst if both run
// at once. Per plan.md §5 step 4, this must be an atomic cutover during
// integration (Dunst's autostart line removed the same moment this
// starts owning notifications) — NOT done in this pass. This file exists
// for the integration phase but is deliberately NOT registered in
// services/qmldir right now (see that file's comment) — re-add the
// `singleton Notifications 1.0 Notifications.qml` line there, and wire
// Toast.qml/NotificationCenter.qml into shell.qml, only when Dunst's
// autostart line is removed in the same step.
Singleton {
    id: root

    // Flat chronological list per decisions.md §9 ("Grouping option: A.
    // flat chronological list" was chosen). Newest first. Deliberately
    // `property var` (plain JS array), NOT `property list<var>` — QML's
    // list<T> type does not support JS array methods (.concat/.filter/
    // .slice, all used below); a plain var holding a JS array does.
    property var history: []

    readonly property int maxHistory: 100

    NotificationServer {
        id: server

        // Quickshell's notification popup keepOnReload / actions
        // support varies by version; kept minimal here (image, actions,
        // body, summary, urgency) since that's the DankMaterialShell
        // NotificationService.qml precedent for what's safe to rely on
        // across notification-sending apps.
        keepOnReload: true

        onNotification: function (notification) {
            notification.tracked = true;

            const entry = {
                id: notification.id,
                summary: notification.summary || "",
                body: notification.body || "",
                appName: notification.appName || "",
                appIcon: notification.appIcon || "",
                image: notification.image || "",
                urgency: notification.urgency,
                timestamp: Date.now(),
                actions: (notification.actions || []).map(a => ({
                            identifier: a.identifier,
                            text: a.text
                        }))
            };

            root.history = [entry].concat(root.history).slice(0, root.maxHistory);
            root.toastRequested(entry);

            notification.closed.connect(function () {
                root.removeFromHistory(entry.id);
            });
        }
    }

    // Emitted for every new notification so Toast.qml can show a
    // transient popup without needing its own NotificationServer
    // connection.
    signal toastRequested(var entry)

    function removeFromHistory(id) {
        root.history = root.history.filter(e => e.id !== id);
    }

    function clearAll() {
        root.history = [];
    }

    function dismiss(id) {
        // Removing from our own history is independent of telling the
        // sending app's notification to close — Quickshell's Notification
        // objects expose their own dismiss(), but we don't retain a
        // reference to the live object past onNotification (only the
        // plain-data `entry` above), so history removal is the extent of
        // what this can do without restructuring to keep live Notification
        // handles around. Acceptable for a history/center view; toasts
        // that are still actually on-screen dismiss via their own timer.
        root.removeFromHistory(id);
    }
}
