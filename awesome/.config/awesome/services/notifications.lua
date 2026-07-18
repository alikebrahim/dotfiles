-------------------------------------------------------------------------------
-- services.notifications — in-memory bounded history via naughty v4.3 hook.
--
-- In classic naughty (awesome v4.3 stable), there is no naughty.connect_signal.
-- The interception point is `naughty.config.notify_callback`: it receives the
-- args table about to be displayed and can inspect/mutate it. We capture the
-- metadata there. v4.3 fields: title, text, appname, icon, timeout, urgency.
--
-- API:
--   notifications.history         -> list (newest first)
--   notifications.unread          -> int
--   notifications:clear_all()
--   notifications:clear(id)
--   notifications:mark_read()
--   notifications:append(entry)   -> id   (entry = {title,text,appname,icon,urgency})
-- Emits: awesome.emit_signal("service::notifications", notifications)
-------------------------------------------------------------------------------
local naughty = require("naughty")
local gears = require("gears")

local notifications = {}
local MAX = 75

notifications.history = {}
notifications.unread = 0
notifications._seq = 0

local function emit()
    awesome.emit_signal("service::notifications", notifications)
end

--- Append a captured notification entry to history.
function notifications.append(entry)
    if not entry then return end
    if entry._pill_internal then return end
    notifications._seq = notifications._seq + 1
    local record = {
        id = notifications._seq,
        app_name = entry.appname or entry.app_name or "unknown",
        title = entry.title or "",
        message = entry.text or entry.message or "",
        icon = entry.icon,
        time = os.time(),
        urgency = entry.urgency or "normal",
    }
    table.insert(notifications.history, 1, record)
    if #notifications.history > MAX then
        table.remove(notifications.history)
    end
    notifications.unread = notifications.unread + 1
    emit()
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

--- Install the naughty interception hook (v4.3 API).
-- notify_callback receives the args table; return args to allow display, nil to
-- suppress. We always record to history.
naughty.config.notify_callback = function(args)
    if not args then return args end
    notifications.append(args)
    return args
end

return notifications
