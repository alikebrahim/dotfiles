-- services.notifications — retired compatibility model.
--
-- API:
--   notifications.history         -> list (newest first)
--   notifications.unread          -> int
--   notifications:clear_all()
--   notifications:clear(id)
--   notifications:mark_read()
-- Emits: awesome.emit_signal("service::notifications", notifications)
--
-- Native notification ownership, history, DND, and presentation moved to
-- Quickshell. This module intentionally does not require "naughty": doing so
-- would load naughty.dbus and reclaim org.freedesktop.Notifications.

local notifications = {}

notifications.history = {}
notifications.unread = 0

local function emit()
    awesome.emit_signal("service::notifications", notifications)
end

function notifications.clear_all()
    notifications.history = {}
    notifications.unread = 0
    emit()
end

function notifications.clear(id)
    for i, e in ipairs(notifications.history) do
        if e.id == id then table.remove(notifications.history, i); break end
    end
    emit()
end

function notifications.mark_read()
    notifications.unread = 0
    emit()
end

return notifications
