-------------------------------------------------------------------------------
-- services.init — lifecycle controller for display-only status services.
--
-- The notification service remains active independently so history is captured
-- even while the pill bar is hidden. Polling services are started only while
-- the bar is visible and refresh immediately when enabled.
-------------------------------------------------------------------------------
local services = {
    audio = require("services.audio"),
    network = require("services.network"),
    bluetooth = require("services.bluetooth"),
    battery = require("services.battery"),
    cpu = require("services.cpu"),
    memory = require("services.memory"),
}

local _active = false

function services.set_active(active)
    active = active and true or false
    if active == _active then return end
    _active = active

    for _, service in pairs(services) do
        if type(service) == "table" and service.set_polling then
            service.set_polling(active)
        end
    end
end

function services.is_active()
    return _active
end

return services
